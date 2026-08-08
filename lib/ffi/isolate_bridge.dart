import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kokoro_tts_flutter/kokoro_tts_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

typedef RtfCallback = void Function(double rtf, int latencyMs);

class CornigrumIsolateBridge {
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Kokoro? _kokoro;
  Tokenizer? _tokenizer;
  AudioPlayer? _audioPlayer;
  RtfCallback? onRtfUpdate;

  String _modelPath = '';
  String _voicePath = '';
  String _voiceName = '';
  String _voiceId = '';

  String _primaryDelimiters = '.!?\n';
  String _secondaryDelimiters = ',;:—';

  List<String> _sentences = [];
  int _currentSentenceIndex = 0;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  final Map<int, String> _audioCache = {}; // sentenceIndex -> wavFilePath
  StreamSubscription<PlayerState>? _playerSubscription;

  int _batchSize = 5;

  Future<void> initialize({
    required String modelPath,
    required String voicePath,
    required String voiceName,
    required String configPath,
    // required String vocabPath,
    bool isInt8 = false,
  }) async {
    debugPrint('[Bridge] Initializing Kokoro TTS Engine...');
    _modelPath = modelPath;
    _voiceName = voiceName;

    _audioPlayer ??= AudioPlayer();

    _playerSubscription?.cancel();
    _playerSubscription = _audioPlayer!.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        debugPrint('[Bridge] Audio completed for sentence index $_currentSentenceIndex');
        _onSentenceAudioCompleted();
      }
    });

    try {
      final effectiveIsInt8 = isInt8 || modelPath.toLowerCase().contains('int8');
      final effectiveVoicePath = await _ensureVoicePath(voicePath);

      final voicesDir = p.dirname(effectiveVoicePath);
      _voiceId = p.basenameWithoutExtension(effectiveVoicePath);

      debugPrint('[Bridge] Model path: $modelPath');
      debugPrint('[Bridge] Voices dir: $voicesDir, Voice ID: $_voiceId');


      /// دالة تحويل النص إلى صوت (TTS) باستخدام مكتبة Kokoro
      /// 
      /// الاستخدام الأساسي:
      /// 1. إعداد مسارات النماذج (ملف نموذج ONNX وملف أصوات JSON) المضافة في مجلد assets.
      /// 2. تهيئة محرك Kokoro ومحرك التحليل الصوتي (Tokenizer).
      /// 3. تحويل النص إلى أصوات كلامية (Phonemes).
      /// 4. توليد العينات الصوتية (Audio Samples) بناءً على الصوت المختار.

      final config = KokoroConfig(
        modelPath: modelPath,
        voicesPath: effectiveVoicePath,
        isInt8: effectiveIsInt8,
      );

      _kokoro = Kokoro(config);
      await _kokoro!.initialize();

      _tokenizer = Tokenizer();
      await _tokenizer!.ensureInitialized();

      _initialized = true;
      debugPrint('[Bridge] Kokoro TTS Engine successfully initialized.');
    } catch (e) {
      debugPrint('[Bridge] Initialization failed with error: $e');
      rethrow;
    }
  }

  Future<String> _ensureVoicePath(String originalPath) async {
    if (originalPath.isEmpty) return originalPath;
    final file = File(originalPath);
    if (!file.existsSync()) return originalPath;

    if (originalPath.endsWith('.bin')) {
      final jsonPath = p.setExtension(originalPath, '.json');
      if (File(jsonPath).existsSync()) {
        return jsonPath; 
      }

    }
    return originalPath;
  }

  Future<List<String>> parseText(String text) async {
    debugPrint('[Bridge] Parsing text into sentences...');
    if (text.trim().isEmpty) {
      _sentences = [];
      _audioCache.clear();
      _currentSentenceIndex = 0;
      return [];
    }

    // بناء أنماط المقسمات الأساسية والثانوية
    String primaryPattern = '';
    for (var ch in _primaryDelimiters.runes) {
      final char = String.fromCharCode(ch);
      primaryPattern += (char == '\n') ? r'\n' : RegExp.escape(char);
    }

    String secondaryPattern = '';
    for (var ch in _secondaryDelimiters.runes) {
      final char = String.fromCharCode(ch);
      secondaryPattern += (char == '\n') ? r'\n' : RegExp.escape(char);
    }

    // دالة مساعدة للتقسيم التكراري بالترتيب (الأساسي ثم الثانوي ثم التقسيم اليدوي عند الحاجة)
    List<String> splitRecursively(String content, int level) {
      final trimmedContent = content.trim();
      if (trimmedContent.isEmpty) return [];
      if (trimmedContent.length <= 400) return [trimmedContent];

      String currentPattern = '';
      if (level == 0 && primaryPattern.isNotEmpty) {
        currentPattern = primaryPattern;
      } else if (secondaryPattern.isNotEmpty) {
        currentPattern = secondaryPattern;
      }

      // إذا لم تعد هناك مقسمات متاحة وطول النص أكبر من 400، نقسمه بالقوة لت,قيق الشرط
      if (currentPattern.isEmpty) {
        List<String> forcedChunks = [];
        for (int i = 0; i < content.length; i += 400) {
          int end = (i + 400 < content.length) ? i + 400 : content.length;
          final chunk = content.substring(i, end).trim();
          if (chunk.isNotEmpty) forcedChunks.add(chunk);
        }
        return forcedChunks;
      }

      final tempattern = currentPattern;
      final regex = RegExp('([^$tempattern]+[$tempattern]+|[^$tempattern]+\$)');


      final matches = regex.allMatches(content);
      
      List<String> result = [];
      for (final match in matches) {
        final chunk = match.group(0) ?? '';
        if (chunk.trim().isNotEmpty) {
          if (chunk.length <= 400) {
            result.add(chunk.trim());
          } else {
            // إذا كان الناتج أكبر من 400، نعيد تمريره للمستوى التالي من التقسيم
            result.addAll(splitRecursively(chunk, level + 1));
          }
        }
      }
      
      // احتياط: إذا فشلت التعابير النمطية في التقسيم وبقي النص كقطعة واحدة أكبر من 400
      if (result.length == 1 && result[0].length > 400) {
        return splitRecursively(content, level + 1);
      }

      return result;
    }

    // البدء بتطبيق التقسيم من المستوى الأول (المقسم الأساسي)
    final List<String> list = splitRecursively(text, 0);

    // تحديث المتغيرات الخاصة بالحال (كما في الكود الأصلي)
    _sentences = list;
    _audioCache.clear();
    _currentSentenceIndex = 0;

    return list;
  }

  Future<void> setDelimiters(String primary, String secondary) async {
    _primaryDelimiters = primary.isEmpty ? '.!?\n' : primary;
    _secondaryDelimiters = secondary.isEmpty ? ',;:—' : secondary;
    debugPrint('[Bridge] Delimiters updated: primary=" $primary ", secondary=" $secondary "');
  }

  Future<void> setBatchMode(int mode, int batchSize) async {
    _batchSize = batchSize.clamp(1, 10);
    debugPrint('[Bridge] Batch size set to: $_batchSize');
  }

  Future<void> synthesizeAndEnqueue(int sentenceIndex, double speed) async {
    if (sentenceIndex < 0 || sentenceIndex >= _sentences.length) return;
    _playbackSpeed = speed;

    if (_audioCache.containsKey(sentenceIndex)) {
      debugPrint('[Bridge] Cache hit for sentence index $sentenceIndex');
      return;
    }

    final text = _sentences[sentenceIndex];
    if (_kokoro != null && _tokenizer != null) {
      try {
        debugPrint('[Bridge] Synthesizing sentence index $sentenceIndex: "$text"');
        final stopwatch = Stopwatch()..start();
        final phonemes = await _tokenizer!.phonemize(text, lang: 'en-us');
        
        final voiceToUse = _voiceId.isEmpty ? (_voiceName.isEmpty ? 'af_heart' : _voiceName) : _voiceId;
        final ttsResult = await _kokoro!.createTTS(
          text: phonemes,
          voice: voiceToUse,
          isPhonemes: true,
        );

        stopwatch.stop();
        final inferenceMs = stopwatch.elapsedMilliseconds;

        if (ttsResult != null && ttsResult.audio != null) {
          final audioList = ttsResult.audio;
          final audioDurationSec = audioList.length / 24000.0;
          final rtf = (inferenceMs / 1000) / (audioDurationSec > 0 ? audioDurationSec : 1.0);

          debugPrint('[Bridge] Synthesized sentence $sentenceIndex in ${inferenceMs}ms (RTF: ${rtf.toStringAsFixed(2)})');

          if (onRtfUpdate != null) {
            onRtfUpdate!(rtf, inferenceMs);
          }

          final tempDir = await getTemporaryDirectory();
          final wavPath = p.join(tempDir.path, 'sentence_$sentenceIndex.wav');
          
          final wavBytes = _convertToWavBytes(audioList);
          final file = File(wavPath);
          await file.writeAsBytes(wavBytes);
          _audioCache[sentenceIndex] = wavPath;
          debugPrint('[Bridge] Sentence $sentenceIndex audio saved to $wavPath');
        } else {
          debugPrint('[Bridge] Synthesis returned null audio for sentence index $sentenceIndex');
        }

      } catch (e) {
        debugPrint('[Bridge] Synthesis error on index $sentenceIndex: $e');
      }
    } else {
      debugPrint('[Bridge] Cannot synthesize index $sentenceIndex: Kokoro or Tokenizer is null');
    }
  }

  Future<void> prefetch(int startIndex, int count, double speed) async {
    debugPrint('[Bridge] Prefetching $count sentences starting from index $startIndex...');
    for (int i = 0; i < count; i++) {
      final idx = startIndex + i;
      if (idx < _sentences.length) {
        await synthesizeAndEnqueue(idx, speed);
      }
    }
  }

  Future<void> play() async {
    debugPrint('[Bridge] Requested play()');
    if (_sentences.isEmpty) return;
    _isPlaying = true;
    await _playCurrentSentence();
  }


  Future<void> _playCurrentSentence() async {
    if (_currentSentenceIndex < 0 || _currentSentenceIndex >= _sentences.length) {
      debugPrint('[Bridge] Reached end of sentences range.');
      _isPlaying = false;
      return;
    }

    debugPrint('[Bridge] Playing sentence index $_currentSentenceIndex');
    prefetch(_currentSentenceIndex, _batchSize, _playbackSpeed);

    final cachedWav = _audioCache[_currentSentenceIndex];
    if (cachedWav != null && File(cachedWav).existsSync()) {
      try {
        await _audioPlayer!.setFilePath(cachedWav);
        await _audioPlayer!.setSpeed(_playbackSpeed);
        await _audioPlayer!.play();
        return;
      } catch (e) {
        debugPrint('[Bridge] Failed playing audio file: $e');
      }
    }

    // محاولة توليف الجملة مباشرة بدلاً من المؤقت الاحتياطي
    debugPrint('[Bridge] Audio not available for index $_currentSentenceIndex, attempting synthesis...');
    try {
      await synthesizeAndEnqueue(_currentSentenceIndex, _playbackSpeed);
      final newCached = _audioCache[_currentSentenceIndex];
      if (newCached != null && File(newCached).existsSync()) {
        await _audioPlayer!.setFilePath(newCached);
        await _audioPlayer!.setSpeed(_playbackSpeed);
        await _audioPlayer!.play();
        return;
      } else {
        // إذا فشل التوليف حتى بعد المحاولة، نمر إلى الجملة التالية
        debugPrint('[Bridge] Synthesis failed for index $_currentSentenceIndex, skipping.');
        _onSentenceAudioCompleted();
      }
    } catch (e) {
      debugPrint('[Bridge] Synthesis error on current sentence: $e');
      _onSentenceAudioCompleted();
    }
  }

  void _onSentenceAudioCompleted() {
    if (!_isPlaying) return;
    if (_currentSentenceIndex < _sentences.length - 1) {
      _currentSentenceIndex++;
      _playCurrentSentence();
    } else {
      debugPrint('[Bridge] Playback reached end of document.');
      _isPlaying = false;
    }
  }

  Future<void> pause() async {
    debugPrint('[Bridge] Requested pause()');
    _isPlaying = false;
    await _audioPlayer?.pause();
  }

  Future<void> stop() async {
    debugPrint('[Bridge] Requested stop()');
    _isPlaying = false;
    await _audioPlayer?.stop();
    _currentSentenceIndex = 0;
  }

  Future<({bool isPlaying, int currentSentence, int queueSize, int queueCapacity, double speed, String modelPath, String voicePath})> getStatus() async {
    return (
      isPlaying: _isPlaying,
      currentSentence: _currentSentenceIndex,
      queueSize: _audioCache.length,
      queueCapacity: 10,
      speed: _playbackSpeed,
      modelPath: _modelPath,
      voicePath: _voicePath,
    );
  }

  Future<void> setSpeed(double speed) async {
    debugPrint('[Bridge] Setting playback speed to $speed');
    _playbackSpeed = speed;
    await _audioPlayer?.setSpeed(speed);
  }

  Future<String> exportSentenceToWav(int sentenceIndex, double speed, String outputPath) async {
    if (sentenceIndex < 0 || sentenceIndex >= _sentences.length) {
      throw Exception('Invalid sentence index');
    }

    final text = _sentences[sentenceIndex];
    if (_kokoro != null && _tokenizer != null) {
      final phonemes = await _tokenizer!.phonemize(text, lang: 'en-us');
      final voiceToUse = _voiceId.isEmpty ? (_voiceName.isEmpty ? 'af_heart' : _voiceName) : _voiceId;
      final ttsResult = await _kokoro!.createTTS(
        text: phonemes,
        voice: voiceToUse,
        isPhonemes: true,
      );

      if (ttsResult != null && ttsResult.audio != null) {
        final wavBytes = _convertToWavBytes(ttsResult.audio);
        final file = File(outputPath);
        await file.writeAsBytes(wavBytes);
        return outputPath;
      }
    }

    throw Exception('Synthesis unavailable for WAV export.');
  }

  Uint8List _convertToWavBytes(dynamic audioData, {int sampleRate = 24000}) {
    List<double> floatSamples = [];
    if (audioData is List<double>) {
      floatSamples = audioData;
    } else if (audioData is List<dynamic>) {
      floatSamples = audioData.map((e) => (e as num).toDouble()).toList();
    } else if (audioData is Float32List) {
      floatSamples = audioData.toList();
    }

    final pcm16 = Int16List(floatSamples.length);
    for (int i = 0; i < floatSamples.length; i++) {
      final sample = floatSamples[i].clamp(-1.0, 1.0);
      pcm16[i] = (sample < 0 ? sample * 32768 : sample * 32767).toInt();
    }

    final bytesPerSample = 2;
    final numChannels = 1;
    final byteRate = sampleRate * numChannels * bytesPerSample;
    final blockAlign = numChannels * bytesPerSample;
    final dataSize = pcm16.length * bytesPerSample;
    final chunkSize = 36 + dataSize;

    final builder = BytesBuilder();
    builder.add([0x52, 0x49, 0x46, 0x46]); // "RIFF"
    builder.add(_int32ToBytes(chunkSize));
    builder.add([0x57, 0x41, 0x56, 0x45]); // "WAVE"

    builder.add([0x66, 0x6D, 0x74, 0x20]); // "fmt "
    builder.add(_int32ToBytes(16));
    builder.add(_int16ToBytes(1));
    builder.add(_int16ToBytes(numChannels));
    builder.add(_int32ToBytes(sampleRate));
    builder.add(_int32ToBytes(byteRate));
    builder.add(_int16ToBytes(blockAlign));
    builder.add(_int16ToBytes(16));

    builder.add([0x64, 0x61, 0x74, 0x61]); // "data"
    builder.add(_int32ToBytes(dataSize));
    // تحويل Int16List إلى Uint8List بشكل آمن
    final byteData = pcm16.buffer.asByteData();
    builder.add(byteData.buffer.asUint8List());

    return builder.toBytes();
  }

  List<int> _int32ToBytes(int value) {
    final b = ByteData(4)..setInt32(0, value, Endian.little);
    return b.buffer.asUint8List();
  }

  List<int> _int16ToBytes(int value) {
    final b = ByteData(2)..setInt16(0, value, Endian.little);
    return b.buffer.asUint8List();
  }

  Future<void> dispose() async {
    debugPrint('[Bridge] Disposing bridge resources...');
    if (_playerSubscription != null) {
      await _playerSubscription!.cancel();
    }
    if (_audioPlayer != null) {
      await _audioPlayer!.dispose();
    }
    _initialized = false;
  }
}