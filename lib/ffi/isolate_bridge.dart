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

  // خريطة لتخزين مسارات الملفات المؤقتة لكل جملة
  final Map<int, String> _audioCache = {};
  // تتبع عمليات التوليد الجارية لمنع التكرار
  final Map<int, Future<void>> _generationTasks = {};
  // مصدر إلغاء المهام
  CancelToken? _cancelToken;

  int _batchSize = 5;
  StreamSubscription<PlayerState>? _playerSubscription;

  void _cleanupCache(int currentIndex) {
    // تحديد العناصر التي يجب حذفها
    final toRemove = _audioCache.keys.where((key) {
      // الشرط الأول: هل الجملة في الماضي؟ (نحتفظ بجملة واحدة سابقة كاحتياط لو عاد المستخدم للخلف فجأة)
      bool isPast = key < currentIndex - 3; 
      
      // الشرط الثاني: هل الجملة في المستقبل أبعد من العدد الذي حدده المستخدم؟
      bool isTooFarInFuture = key > currentIndex + _batchSize;

      // نحذف الجملة إذا تحقق أي من الشرطين
      return isPast || isTooFarInFuture;
    }).toList();

    for (var key in toRemove) {
      final filePath = _audioCache.remove(key);
      if (filePath != null) {
        try {
          File(filePath).deleteSync();
          debugPrint('[Bridge] Deleted cached audio for sentence $key');
        } catch (_) {}
      }
    }
  }

  Future<void> initialize({
    required String modelPath,
    required String voicePath,
    required String voiceName,
    required String configPath,
    bool isInt8 = true,
  }) async {
    debugPrint('[Bridge] Initializing Kokoro TTS Engine...');
    _modelPath = modelPath;
    _voiceName = voiceName;
    _voicePath = voicePath;

    // إلغاء أي مهام سابقة
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

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

      final config = KokoroConfig(
        modelPath: modelPath,
        voicesPath: effectiveVoicePath,
        isInt8: false,
      );

      debugPrint('[Bridge] modelPath: $modelPath, voicesPath: $effectiveVoicePath, isInt8: $effectiveIsInt8');

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

  // تحسين دالة تقسيم النص
  Future<List<String>> parseText(String text) async {
    debugPrint('[Bridge] Parsing text into sentences...');
    if (text.trim().isEmpty) {
      _sentences = [];
      _audioCache.clear();
      _generationTasks.clear();
      _currentSentenceIndex = 0;
      return [];
    }

    // تنظيف النص من المسافات الزائدة والأسطر الفارغة
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // بناء نمط للفصل: الأساسي ثم الثانوي
    final primaryPattern = _primaryDelimiters
        .split('')
        .map((c) => c == '\n' ? r'\n' : RegExp.escape(c))
        .join('');
    final secondaryPattern = _secondaryDelimiters
        .split('')
        .map((c) => c == '\n' ? r'\n' : RegExp.escape(c))
        .join('');

    // دالة مساعدة للتقسيم التكراري مع حد أقصى للطول
    List<String> splitRecursively(String content, int depth) {
      final trimmed = content.trim();
      if (trimmed.isEmpty) return [];
      if (trimmed.length <= 400) return [trimmed];

      String pattern;
      if (depth == 0 && primaryPattern.isNotEmpty) {
        pattern = primaryPattern;
      } else if (secondaryPattern.isNotEmpty) {
        pattern = secondaryPattern;
      } else {
        // تقسيم قسري إلى أجزاء بطول 400
        final chunks = <String>[];
        for (int i = 0; i < trimmed.length; i += 400) {
          final end = min(i + 400, trimmed.length);
          chunks.add(trimmed.substring(i, end).trim());
        }
        return chunks.where((s) => s.isNotEmpty).toList();
      }

      // استخدام تعبير نمطي للفصل مع الاحتفاظ بالمحددات
      final regex = RegExp('([^$pattern]+[$pattern]+|[^$pattern]+\$)');
      final matches = regex.allMatches(trimmed);
      final result = <String>[];
      for (final match in matches) {
        final chunk = match.group(0) ?? '';
        final trimmedChunk = chunk.trim();
        if (trimmedChunk.isNotEmpty) {
          if (trimmedChunk.length <= 400) {
            result.add(trimmedChunk);
          } else {
            // إعادة التقسيم في المستوى التالي
            result.addAll(splitRecursively(trimmedChunk, depth + 1));
          }
        }
      }

      // في حالة فشل التقسيم (نتيجة واحدة طويلة)، نلجأ للتقسيم القسري
      if (result.length == 1 && result[0].length > 400) {
        return splitRecursively(trimmed, depth + 1);
      }
      return result;
    }

    final list = splitRecursively(cleaned, 0);
    _sentences = list;
    _audioCache.clear();
    _generationTasks.clear();
    _currentSentenceIndex = 0;
    return list;
  }

  Future<void> setDelimiters(String primary, String secondary) async {
    _primaryDelimiters = primary.isEmpty ? '.!?\n' : primary;
    _secondaryDelimiters = secondary.isEmpty ? ',;:—' : secondary;
    debugPrint('[Bridge] Delimiters updated: primary=" $_primaryDelimiters ", secondary=" $_secondaryDelimiters "');
  }

  Future<void> setBatchMode(int mode, int batchSize) async {
    _batchSize = batchSize.clamp(1, 10);
    debugPrint('[Bridge] Batch size set to: $_batchSize');
  }

  // توليد الصوت مع دعم الإلغاء والتحقق من الكاش
  Future<void> synthesizeAndEnqueue(int sentenceIndex, double speed) async {
    if (sentenceIndex < 0 || sentenceIndex >= _sentences.length) return;
    _playbackSpeed = speed;

    // إذا كان الملف موجوداً بالفعل، لا نعيد التوليد
    if (_audioCache.containsKey(sentenceIndex)) {
      debugPrint('[Bridge] Cache hit for sentence $sentenceIndex');
      return;
    }

    // منع التوليد المتكرر لنفس الجملة
    if (_generationTasks.containsKey(sentenceIndex)) {
      debugPrint('[Bridge] Generation already in progress for $sentenceIndex');
      return _generationTasks[sentenceIndex];
    }

    final cancelToken = _cancelToken;
    if (cancelToken == null || cancelToken.isCancelled) {
      debugPrint('[Bridge] Generation cancelled for $sentenceIndex');
      return;
    }

    final text = _sentences[sentenceIndex];
    if (_kokoro == null || _tokenizer == null) {
      debugPrint('[Bridge] Cannot synthesize: Kokoro or Tokenizer is null');
      return;
    }

    // إنشاء Completer لهذه المهمة
    final completer = Completer<void>();
    _generationTasks[sentenceIndex] = completer.future;

    try {
      debugPrint('[Bridge] Synthesizing sentence $sentenceIndex: "$text"');
      final stopwatch = Stopwatch()..start();

      // التحقق من الإلغاء قبل البدء
      cancelToken.throwIfCancelled();

      final phonemes = await _tokenizer!.phonemize(text, lang: 'en-us');
      final voiceToUse = _voiceId.isEmpty ? (_voiceName.isEmpty ? 'af_heart' : _voiceName) : _voiceId;

      // تنفيذ التوليد مع إمكانية الإلغاء
      final ttsResult = await _kokoro!.createTTS(
        text: phonemes,
        voice: voiceToUse,
        isPhonemes: true,
      );

      cancelToken.throwIfCancelled();

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

        // تنظيف الكاش بعد التوليد
        _cleanupCache(_currentSentenceIndex);
      } else {
        debugPrint('[Bridge] Synthesis returned null audio for $sentenceIndex');
      }
      completer.complete();
    } catch (e) {
      debugPrint('[Bridge] Synthesis error on index $sentenceIndex: $e');
      completer.completeError(e);
    } finally {
      _generationTasks.remove(sentenceIndex);
    }

    return completer.future;
  }

  // التحميل المسبق مع التحقق من الكاش والإلغاء
  Future<void> prefetch(int startIndex, int count, double speed) async {
    debugPrint('[Bridge] Prefetching $count sentences starting from index $startIndex...');
    final tasks = <Future>[];
    for (int i = 0; i < count; i++) {
      final idx = startIndex + i;
      if (idx < _sentences.length) {
        // التحقق من وجود الملف في الكاش قبل البدء
        if (_audioCache.containsKey(idx)) continue;
        final task = synthesizeAndEnqueue(idx, speed);
        tasks.add(task);
      }
    }
    await Future.wait(tasks);
  }

  Future<void> play() async {
    debugPrint('[Bridge] Requested play()');
    if (_sentences.isEmpty) return;
    _isPlaying = true;
    // إلغاء أي مهام سابقة
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    await _playCurrentSentence();
  }

  Future<void> _playCurrentSentence() async {
    if (!_isPlaying) return;
    if (_currentSentenceIndex < 0 || _currentSentenceIndex >= _sentences.length) {
      debugPrint('[Bridge] Reached end of sentences.');
      _isPlaying = false;
      return;
    }

    debugPrint('[Bridge] Playing sentence index $_currentSentenceIndex');
    // ابدأ التحميل المسبق للجمل القادمة (لا ننتظرها)
    prefetch(_currentSentenceIndex + 1, _batchSize, _playbackSpeed);

    final cancelToken = _cancelToken;
    if (cancelToken == null || cancelToken.isCancelled) {
      debugPrint('[Bridge] Play cancelled before playing $_currentSentenceIndex');
      return;
    }

    // التأكد من وجود الصوت في الكاش، وإلا نولده وننتظره
    if (!_audioCache.containsKey(_currentSentenceIndex)) {
      debugPrint('[Bridge] Audio not cached, generating now...');
      try {
        await synthesizeAndEnqueue(_currentSentenceIndex, _playbackSpeed);
        cancelToken.throwIfCancelled();
      } catch (e) {
        debugPrint('[Bridge] Generation failed for $_currentSentenceIndex: $e');
        // إذا فشل التوليد، ننتقل إلى التالية
        _onSentenceAudioCompleted();
        return;
      }
    }

    // تشغيل الصوت
    final cachedWav = _audioCache[_currentSentenceIndex];
    if (cachedWav != null && File(cachedWav).existsSync()) {
      try {
        await _audioPlayer!.setFilePath(cachedWav);
        await _audioPlayer!.setSpeed(_playbackSpeed);
        await _audioPlayer!.play();
        // لا ننتظر الانتهاء هنا، سيتم التعامل معه عبر Stream
      } catch (e) {
        debugPrint('[Bridge] Failed playing audio file: $e');
        _onSentenceAudioCompleted();
      }
    } else {
      debugPrint('[Bridge] Audio file missing for $_currentSentenceIndex, skipping.');
      _onSentenceAudioCompleted();
    }
  }

  void _onSentenceAudioCompleted() {
    if (!_isPlaying) return;
    if (_currentSentenceIndex < _sentences.length - 1) {
      _currentSentenceIndex++;
      // تنظيف الكاش بعد التقدم
      _cleanupCache(_currentSentenceIndex);
      _playCurrentSentence();
    } else {
      debugPrint('[Bridge] Playback reached end of document.');
      _isPlaying = false;
    }
  }

  Future<void> pause() async {
    debugPrint('[Bridge] Requested pause()');
    _isPlaying = false;
    // إلغاء المهام الجارية
    _cancelToken?.cancel();
    await _audioPlayer?.pause();
  }

  Future<void> stop() async {
    debugPrint('[Bridge] Requested stop()');
    _isPlaying = false;
    _cancelToken?.cancel();
    await _audioPlayer?.stop();
    _currentSentenceIndex = 0;
    // تنظيف الكاش بالكامل
    _audioCache.clear();
    _generationTasks.clear();
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
    _cancelToken?.cancel();
    if (_playerSubscription != null) {
      await _playerSubscription!.cancel();
    }
    if (_audioPlayer != null) {
      await _audioPlayer!.dispose();
    }
    _initialized = false;
  }
}

// فئة بسيطة لدعم الإلغاء
class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;

  void throwIfCancelled() {
    if (_isCancelled) throw Exception('Operation cancelled');
  }
}