import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Handles ONNX model inference for external ONNX model files provided by the user.
class OnnxModelRunner {
  final String modelPath;
  bool _isInitialized = false;
  OrtSession? _session;
  final OnnxRuntime _ort = OnnxRuntime();

  List<String> _cachedInputNames = [];
  List<String> _cachedOutputNames = [];
  bool _useInputIds = false;

  OnnxModelRunner({required this.modelPath});

  /// Initializes and loads the user's external ONNX file, then validates it.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Verify file existence to prevent native C++ runtime crashes
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        throw Exception('Model file does not exist at path: $modelPath');
      }

      final options = OrtSessionOptions(
        intraOpNumThreads: 2,
        useArena: true,
      );

      // 2. Load model from asset or local file system based on path format
      if (modelPath.startsWith('assets/')) {
        _session = await _ort.createSessionFromAsset(
          modelPath,
          options: options,
        );
      } else {
        _session = await _ort.createSession(
          modelPath,
          options: options,
        );
      }

      // 3. Cache session metadata
      _cachedInputNames = List<String>.from(_session!.inputNames);
      _cachedOutputNames = List<String>.from(_session!.outputNames);

      // 4. Validate model structure
      await _validateModel();

      _isInitialized = true;
      debugPrint('User model successfully loaded and validated from: $modelPath');
    } catch (e) {
      await dispose();
      throw Exception('Failed to initialize user model: $e');
    }
  }

  /// Validates the model's inputs, outputs, and performs a dummy inference.
  Future<void> _validateModel() async {
    if (_session == null) {
      throw Exception('Session not loaded');
    }

    // Check number of inputs
    if (_cachedInputNames.length < 3) {
      throw Exception(
        'Incompatible model format: requires at least 3 inputs (tokens/input_ids, style, speed). '
        'Found ${_cachedInputNames.length} inputs: ${_cachedInputNames.join(', ')}',
      );
    }

    // Check for known input names or fallback to positional mapping
    const expectedInputs = ['input_ids', 'style', 'speed'];
    bool hasNamedInputs = expectedInputs.every((name) => _cachedInputNames.contains(name));
    if (!hasNamedInputs) {
      // If not named, we assume they are in order: tokens, style, speed
      // This is a common pattern, but we warn.
      debugPrint('Model inputs do not include standard names. Assuming order: tokens, style, speed.');
      _useInputIds = false; // use positional mapping
    } else {
      _useInputIds = true;
    }

    // Check for outputs
    if (_cachedOutputNames.isEmpty) {
      throw Exception('Model has no output tensors.');
    }

    // Perform a dummy inference to validate shapes and execution
    try {
      final dummyTokens = Int64List(10); // 1 token + padding
      final dummyVoice = Float32List(256);
      final result = await runInference(
        tokens: [1, 2, 3, 4, 5], // dummy tokens
        voice: dummyVoice,
        speed: 1.0,
      );
      if (result.isEmpty) {
        throw Exception('Model inference returned empty result.');
      }
      debugPrint('Dummy inference succeeded, output length: ${result.length}');
    } catch (e) {
      throw Exception('Model validation inference failed: $e');
    }
  }

  /// Runs inference on the warm session using pre-allocated inputs.
  Future<List<num>> runInference({
    required List<int> tokens,
    required Float32List voice,
    required double speed,
  }) async {
    if (!_isInitialized || _session == null) {
      throw Exception('Model not initialized. Call initialize() first.');
    }

    final Map<String, OrtValue> inputs = {};
    Map<String, OrtValue>? outputs;

    try {
      // Pad tokens with start/end markers (0)
      final paddedLength = tokens.length + 2;
      final paddedTokens = Int64List(paddedLength);
      paddedTokens[0] = 0;
      for (int i = 0; i < tokens.length; i++) {
        paddedTokens[i + 1] = tokens[i];
      }
      paddedTokens[paddedLength - 1] = 0;

      // Construct native input tensors
      final tokenTensor = await OrtValue.fromList(
        paddedTokens,
        [1, paddedLength],
      );
      final voiceTensor = await OrtValue.fromList(
        voice,
        [1, voice.length],
      );
      final speedTensor = await OrtValue.fromList(
        [speed],
        [1],
      );

      if (_useInputIds) {
        inputs['input_ids'] = tokenTensor;
        inputs['style'] = voiceTensor;
        inputs['speed'] = speedTensor;
      } else {
        // Positional mapping: assume order tokens, style, speed
        inputs[_cachedInputNames[0]] = tokenTensor;
        inputs[_cachedInputNames[1]] = voiceTensor;
        inputs[_cachedInputNames[2]] = speedTensor;
      }

      // Execute model execution
      outputs = await _session!.run(inputs);

      if (_cachedOutputNames.isEmpty || outputs.isEmpty) {
        throw Exception('Model returned no output tensors.');
      }

      final outputValue = outputs[_cachedOutputNames[0]];
      if (outputValue == null) {
        throw Exception('Output tensor is null.');
      }

      final rawFlatList = await outputValue.asFlattenedList();

      if (rawFlatList.isEmpty) {
        debugPrint('Warning: Output audio tensor is empty.');
        return Float32List(0);
      }

      return Float32List.fromList(
        rawFlatList.map((e) => (e as num).toDouble()).toList(),
      );
    } catch (e) {
      throw Exception('Failed to run inference: $e');
    } finally {
      // Explicitly release C++ native memory allocations for tensors
      for (final tensor in inputs.values) {
        await tensor.dispose();
      }
      if (outputs != null) {
        for (final tensor in outputs!.values) {
          await tensor.dispose();
        }
      }
    }
  }

  bool get isInitialized => _isInitialized;

  /// Closes session and releases native resources.
  Future<void> dispose() async {
    if (_session != null) {
      await _session!.close();
      _session = null;
    }
    _isInitialized = false;
    _cachedInputNames.clear();
    _cachedOutputNames.clear();
  }
}