import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

/// A class that handles TTS model inference for Kokoro TTS using ONNX Runtime
class OnnxModelRunner {
  final String modelPath;
  bool _isInitialized = false;
  OrtSession? _session;
  late final OnnxRuntime _ort;

  OnnxModelRunner({required this.modelPath}) {
    _ort = OnnxRuntime();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final providers = _getPreferredProviders();
      debugPrint('Using ONNX providers: $providers');

      if (modelPath.startsWith('assets/')) {
        final byteData = await rootBundle.load(modelPath);
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/temp_model.onnx';
        await File(tempPath).writeAsBytes(byteData.buffer.asUint8List());
        _session = await _ort.createSession(tempPath);
      } else {
        _session = await _ort.createSession(modelPath);
      }

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize ONNX model: $e');
    }
  }

  List<String> _getPreferredProviders() {
    // By default use CPU provider
    return ['CPUExecutionProvider'];
  }

  Future<List<num>> runInference({
    required List<int> tokens,
    required Float32List voice,
    required double speed,
  }) async {
    if (_session == null || !_isInitialized) {
      throw Exception('Model not initialized. Call initialize() first.');
    }

    try {
      // Padding tokens with start/end tokens (0) as in kokoro-onnx
      final paddedTokens = [0, ...tokens, 0];
      debugPrint('Padded tokens: $paddedTokens (length: ${paddedTokens.length})');

      final inputNames = _session!.inputNames;
      if (inputNames.length < 3) {
        throw Exception('Model requires at least 3 inputs: tokens/input_ids, style, and speed');
      }

      final Map<String, OrtValue> inputs = {};

      try {
        // Support both older and newer model formats
        final bool useInputIds = inputNames.contains('input_ids');

        if (useInputIds) {
          debugPrint('Using newer model format with input_ids');
          inputs['input_ids'] = await OrtValue.fromList(
            Int64List.fromList(paddedTokens),
            [1, paddedTokens.length],
          );
          inputs['style'] = await OrtValue.fromList(
            voice.toList(),
            [1, voice.length],
          );
          inputs['speed'] = await OrtValue.fromList(
            [speed],
            [1],
          );
        } else {
          debugPrint('Using older model format with tokens');
          inputs[inputNames[0]] = await OrtValue.fromList(
            Int64List.fromList(paddedTokens),
            [1, paddedTokens.length],
          );
          inputs[inputNames[1]] = await OrtValue.fromList(
            voice.toList(),
            [1, voice.length],
          );
          inputs[inputNames[2]] = await OrtValue.fromList(
            [speed],
            [1],
          );
        }
      } catch (e) {
        throw Exception('Failed to create input tensors: $e');
      }

      final outputs = await _session!.run(inputs);

      final outputNames = _session!.outputNames;
      if (outputNames.isEmpty || outputs.isEmpty) {
        throw Exception('Model has no outputs');
      }

      final outputValue = outputs[outputNames[0]];
      if (outputValue == null) {
        throw Exception('Output tensor is null');
      }

      // Get the raw data as a list (could be flat or nested)
      final List<dynamic> rawList = await outputValue.asList();

      // Flatten the list if necessary (handle batch dimension of 1)
      List<num> flatValues;
      if (rawList.isNotEmpty && rawList.first is List) {
        // Case: output shape is [1, audio_length] => rawList = [ [v1, v2, ...] ]
        flatValues = (rawList.first as List).cast<num>();
      } else {
        // Case: output shape is [audio_length] => rawList = [v1, v2, ...]
        flatValues = rawList.cast<num>();
      }

      if (flatValues.isEmpty) {
        debugPrint('Warning: Output audio is empty.');
        return Float32List(0);
      }

      // Always return as Float32List (audio is always floating-point)
      final Float32List outputData = Float32List.fromList(
        flatValues.map((e) => e.toDouble()).toList(),
      );

      debugPrint('Dart: Raw ONNX Output (first 10): ${outputData.sublist(0, outputData.length > 10 ? 10 : outputData.length)}');
      return outputData;
    } catch (e) {
      throw Exception('Failed to run inference: $e');
    }
  }

  bool get isInitialized => _isInitialized;
  List<String> get inputNames => _session?.inputNames ?? [];
  List<String> get outputNames => _session?.outputNames ?? [];

  Future<void> dispose() async {
    if (_session != null) {
      await _session!.close();
      _session = null;
      _isInitialized = false;
    }
  }
}