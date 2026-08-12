import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'audio_utils.dart';
import 'tokenizer.dart';
import 'models/voice.dart';
import 'models/tts_result.dart';
import 'onnx_model_runner.dart';

/// Core Kokoro TTS engine for Flutter
class Kokoro {
  final KokoroConfig config;
  late final Tokenizer _tokenizer;
  late final Map<String, Voice> _voices;
  late final OnnxModelRunner _modelRunner;
  bool _isInitialized = false;

  Kokoro(this.config) {
    _tokenizer = Tokenizer(config: config.tokenizerConfig);
  }

  /// Initialize the Kokoro TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;
    config.validate();

    // تحميل tokenizer و voices و model بالتوازي لتحسين السرعة
    await Future.wait([
      _tokenizer.ensureInitialized(),
      _loadVoices(),
      _initModelRunner(),
    ]);

    _isInitialized = true;
    debugPrint('✅ Kokoro TTS initialized successfully');
  }

  Future<void> _initModelRunner() async {
    _modelRunner = OnnxModelRunner(modelPath: config.modelPath);
    await _modelRunner.initialize();
  }

  Future<void> ensureInitialized() async {
    if (!_isInitialized) await initialize();
  }

  Map<String, Voice> get availableVoices {
    if (!_isInitialized) {
      throw StateError('Kokoro is not initialized. Call initialize() first.');
    }
    return Map.unmodifiable(_voices);
  }

  /// Loads the voices from the voices.json file
  Future<void> _loadVoices() async {
    try {
      final String jsonString = await rootBundle.loadString(config.voicesPath);
      final Map<String, dynamic> voicesData = jsonDecode(jsonString);
      final Map<String, Voice> voiceMap = {};

      for (final voiceName in voicesData.keys) {
        try {
          final List<dynamic> styleVectors = voicesData[voiceName];
          final List<Float32List> processedVectors = [];

          for (final vector in styleVectors) {
            final processed = _processStyleVector(vector, voiceName);
            if (processed != null) {
              processedVectors.add(processed);
            }
          }

          if (processedVectors.isEmpty) {
            debugPrint('⚠️ No valid style vectors for voice $voiceName, using dummy vector');
            processedVectors.add(Float32List(256));
          }

          voiceMap[voiceName] = Voice(
            id: voiceName,
            name: _formatVoiceName(voiceName),
            styleVectors: processedVectors,
            languageCode: _getLanguageCodeFromVoiceName(voiceName),
            gender: _getGenderFromVoiceName(voiceName),
          );
        } catch (e) {
          debugPrint('❌ Error processing voice $voiceName: $e');
        }
      }

      if (voiceMap.isEmpty) {
        throw Exception('No valid voices could be loaded from voices.json');
      }

      _voices = voiceMap;
      debugPrint('✅ Loaded ${_voices.length} voices from voices.json');
    } catch (e) {
      throw Exception('Failed to load voices from ${config.voicesPath}: $e');
    }
  }

  Float32List? _processStyleVector(dynamic vector, String voiceName) {
    try {
      if (vector is! List) {
        debugPrint('⚠️ Expected List for style vector in $voiceName, got ${vector.runtimeType}');
        return null;
      }

      List<dynamic> listToProcess = vector;

      // التعامل مع الحالة المغلفة [[0.1, 0.2, ...]]
      if (vector.isNotEmpty && vector.first is List) {
        if (vector.length == 1) {
          listToProcess = vector.first as List<dynamic>;
        } else {
          debugPrint('⚠️ Unexpected multi-list structure in $voiceName');
          return null;
        }
      }

      final List<double> doubleList = [];
      for (final value in listToProcess) {
        if (value is num) {
          doubleList.add(value.toDouble());
        } else if (value is String) {
          doubleList.add(double.tryParse(value) ?? 0.0);
        } else if (value is bool) {
          doubleList.add(value ? 1.0 : 0.0);
        } else {
          doubleList.add(0.0);
        }
      }

      return Float32List.fromList(doubleList);
    } catch (e) {
      debugPrint('❌ Error processing vector in $voiceName: $e');
      return null;
    }
  }

  String _formatVoiceName(String voiceId) {
    final parts = voiceId.split('_');
    if (parts.length < 2) return voiceId;
    return parts.map((p) => p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '').join(' ');
  }

  String _getLanguageCodeFromVoiceName(String voiceId) {
    if (voiceId.startsWith('fr_')) return 'fr-fr';
    if (voiceId.startsWith('es_')) return 'es-es';
    if (voiceId.startsWith('de_')) return 'de-de';
    if (voiceId.startsWith('it_')) return 'it-it';
    if (voiceId.startsWith('zh_')) return 'zh-cn';
    if (voiceId.startsWith('ja_')) return 'ja-jp';
    return 'en-us';
  }

  String _getGenderFromVoiceName(String voiceId) {
    if (voiceId.contains('female')) return 'female';
    if (voiceId.contains('male')) return 'male';
    return 'neutral';
  }

  /// Splits phonemes into batches (optimized: returns single batch for simplicity)
  List<String> _splitPhonemes(String phonemes) {
    // حاليًا نرجع الدفعة كاملة لأن tokenizer أصبح أسرع بكثير
    return [phonemes];
  }

  /// Creates audio from text using specified voice
  Future<TtsResult> createTTS({
    required String text,
    required dynamic voice,
    double speed = 1.0,
    String lang = 'en-us',
    bool isPhonemes = false,
    bool trim = true,
  }) async {
    await ensureInitialized();
    debugPrint('🎤 Creating TTS: text="$text", voice=$voice, speed=$speed');

    assert(speed >= 0.5 && speed <= 2.0, 'Speed should be between 0.5 and 2.0');

    // Resolve voice
    final voiceObj = _resolveVoice(voice);

    // Get phonemes
    final String phonemes = isPhonemes 
        ? text 
        : await _tokenizer.phonemize(text, lang: lang);
    debugPrint('📝 Phonemes: "$phonemes"');

    // Process batches
    final batches = _splitPhonemes(phonemes);
    final audioBuffers = <List<num>>[];

    for (final batch in batches) {
      final tokens = _tokenizer.tokenize(batch);
      debugPrint('🔢 Tokens: ${tokens.length}');

      final styleVector = voiceObj.getStyleVectorForTokens(tokens.length);
      
      final audio = await _modelRunner.runInference(
        tokens: tokens,
        voice: styleVector,
        speed: speed,
      );

      List<num> processedAudio = audio;
      if (trim) {
        final (trimmed, _) = AudioUtils.trimSilence(audio);
        processedAudio = trimmed;
      }

      audioBuffers.add(processedAudio);
    }

    // Combine audio
    final combinedAudio = AudioUtils.concatenateAudio(audioBuffers);
    final duration = combinedAudio.length / sampleRate;

    debugPrint('✅ TTS complete: ${duration.toStringAsFixed(2)}s, ${combinedAudio.length} samples');

    return TtsResult(
      audio: combinedAudio,
      sampleRate: sampleRate,
      duration: duration,
      phonemes: phonemes,
    );
  }

  Voice _resolveVoice(dynamic voice) {
    if (voice is String) {
      if (!_voices.containsKey(voice)) {
        throw ArgumentError('Voice "$voice" not found. Available: ${_voices.keys.join(', ')}');
      }
      return _voices[voice]!;
    } else if (voice is Voice) {
      return voice;
    } else {
      throw ArgumentError('Voice must be String ID or Voice object');
    }
  }

  /// Stream audio generation for longer texts
  Stream<TtsResult> createTTSStream({
    required String text,
    required dynamic voice,
    double speed = 1.0,
    String lang = 'en-us',
    bool isPhonemes = false,
    bool trim = true,
  }) async* {
    await ensureInitialized();
    assert(speed >= 0.5 && speed <= 2.0);

    final voiceObj = _resolveVoice(voice);
    final String phonemes = isPhonemes ? text : await _tokenizer.phonemize(text, lang: lang);
    final batches = _splitPhonemes(phonemes);

    for (final batch in batches) {
      final tokens = _tokenizer.tokenize(batch);
      final audio = await _modelRunner.runInference(
        tokens: tokens,
        voice: voiceObj.getStyleVectorForTokens(tokens.length),
        speed: speed,
      );

      List<num> processedAudio = audio;
      if (trim) {
        final (trimmed, _) = AudioUtils.trimSilence(audio);
        processedAudio = trimmed;
      }

      yield TtsResult(
        audio: processedAudio,
        sampleRate: sampleRate,
        duration: processedAudio.length / sampleRate,
        phonemes: batch,
      );
    }
  }

  List<String> getVoices() => _voices.keys.toList()..sort();
  Voice? getVoice(String id) => _voices[id];

  Future<void> dispose() async {
    if (_isInitialized) {
      await _modelRunner.dispose();
      _isInitialized = false;
    }
  }
}