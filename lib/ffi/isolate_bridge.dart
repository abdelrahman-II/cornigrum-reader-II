import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kokoro_tts_flutter/kokoro_tts_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CornigrumIsolateBridge {
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Kokoro? _kokoro;
  Tokenizer? _tokenizer;
  AudioPlayer? _audioPlayer;

  String _modelPath = '';
  String _voicePath = '';
  String _voiceName = '';
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
    required String vocabPath,
    bool isInt8 = false,
  }) async {
    _modelPath = modelPath;
    _voicePath = voicePath;
    _voiceName = voiceName;

    _audioPlayer ??= AudioPlayer();

    // Listen to audio player state changes to advance sentences automatically
    _playerSubscription?.cancel();
    _playerSubscription = _audioPlayer!.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onSentenceAudioCompleted();
      }
    });

    try {
      final effectiveIsInt8 = isInt8 || modelPath.toLowerCase().contains('int8');
      final effectiveVoicePath = await _ensureVoicePath(voicePath);

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
    } catch (e) {
      debugPrint('Kokoro TTS initialization notice: $e');
      // Set initialized to true so mock/fallback playback mode works if model is omitted
      _initialized = true;
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
      try {
        final content = await file.readAsString();
        if (content.trim().startsWith('{') || content.trim().startsWith('[')) {
          final jsonFile = File(jsonPath);
          await jsonFile.writeAsString(content);
          return jsonFile.path;
        }
      } catch (_) {}
    }
    return originalPath;
  }

  Future<List<String>> parseText(String text) async {
    if (text.trim().isEmpty) {
      _sentences = [];
      return [];
    }

    String escapeCharSet(String input) {
      return input.split('').map((c) {
        if (RegExp(r'[a-zA-Z0-9]').hasMatch(c)) return c;
        return '\\$c';
      }).join('');
    }

    final primaryEsc = escapeCharSet(_primaryDelimiters);
    RegExp regex;
    try {
      regex = RegExp('([^$primaryEsc]+[$primaryEsc]+|[^$primaryEsc]+\$)');
    } catch (_) {
      regex = RegExp(r'([^.!?\n]+[.!?\n]+|[^.!?\n]+$)');
    }

    final matches = regex.allMatches(text);
    final List<String> list = [];
    for (final match in matches) {
      final chunk = match.group(0) ?? '';
      if (chunk.trim().isNotEmpty) {
        list.add(chunk.trim());
      }
    }

    _sentences = list;
    _audioCache.clear();
    _currentSentenceIndex = 0;
    return list;
  }

  Future<void> setDelimiters(String primary, String secondary) async {
    _primaryDelimiters = primary.isEmpty ? '.!?\n' : primary;
    _secondaryDelimiters = secondary.isEmpty ? ',;:—' : secondary;
  }

  Future<void> setBatchMode(int mode, int batchSize) async {
    _batchSize = batchSize.clamp(1, 10);
  }

  Future<void> synthesizeAndEnqueue(int sentenceIndex, double speed) async {
    if (sentenceIndex < 0 || sentenceIndex >= _sentences.length) return;
    _playbackSpeed = speed;

    if (_audioCache.containsKey(sentenceIndex)) return;

    final text = _sentences[sentenceIndex];
    if (_kokoro != null && _tokenizer != null) {
      try {
        final phonemes = await _tokenizer!.phonemize(text, lang: 'en-us');
        final ttsResult = await _kokoro!.createTTS(
          text: phonemes,
          voice: _voiceName.isEmpty ? 'af_heart' : _voiceName,
          isPhonemes: true,
        );

        if (ttsResult != null && ttsResult.audio != null) {
          final tempDir = await getTemporaryDirectory();
          final wavPath = p.join(tempDir.path, 'sentence_$sentenceIndex.wav');
          
          final wavBytes = _convertToWavBytes(ttsResult.audio);
          final file = File(wavPath);
          await file.writeAsBytes(wavBytes);
          _audioCache[sentenceIndex] = wavPath;
        }
      } catch (e) {
        debugPrint('Synthesis exception for index $sentenceIndex: $e');
      }
    }
  }

  Future<void> prefetch(int startIndex, int count, double speed) async {
    for (int i = 0; i < count; i++) {
      final idx = startIndex + i;
      if (idx < _sentences.length) {
        await synthesizeAndEnqueue(idx, speed);
      }
    }
  }

  Future<void> play() async {
    if (_sentences.isEmpty) return;
    _isPlaying = true;
    await _playCurrentSentence();
  }

  Future<void> _playCurrentSentence() async {
    if (_currentSentenceIndex < 0 || _currentSentenceIndex >= _sentences.length) {
      _isPlaying = false;
      return;
    }

    // Prefetch upcoming sentences in queue
    prefetch(_currentSentenceIndex, _batchSize, _playbackSpeed);

    final cachedWav = _audioCache[_currentSentenceIndex];
    if (cachedWav != null && File(cachedWav).existsSync()) {
      try {
        await _audioPlayer!.setFilePath(cachedWav);
        await _audioPlayer!.setSpeed(_playbackSpeed);
        await _audioPlayer!.play();
        return;
      } catch (e) {
        debugPrint('Audio play failed: $e');
      }
    }

    // Fallback timer simulation if audio file not generated or on web
    final sentence = _sentences[_currentSentenceIndex];
    final durationSec = max(1.5, (sentence.length * 0.05) / _playbackSpeed);
    
    Future.delayed(Duration(milliseconds: (durationSec * 1000).round()), () {
      if (_isPlaying) {
        _onSentenceAudioCompleted();
      }
    });
  }

  void _onSentenceAudioCompleted() {
    if (!_isPlaying) return;
    if (_currentSentenceIndex < _sentences.length - 1) {
      _currentSentenceIndex++;
      _playCurrentSentence();
    } else {
      _isPlaying = false;
    }
  }

  Future<void> pause() async {
    _isPlaying = false;
    await _audioPlayer?.pause();
  }

  Future<void> stop() async {
    _isPlaying = false;
    await _audioPlayer?.stop();
    _currentSentenceIndex = 0;
  }

  Future<({bool isPlaying, int currentSentence, int queueSize, int queueCapacity, double speed})> getStatus() async {
    return (
      isPlaying: _isPlaying,
      currentSentence: _currentSentenceIndex,
      queueSize: _audioCache.length,
      queueCapacity: 10,
      speed: _playbackSpeed,
    );
  }

  Future<void> setSpeed(double speed) async {
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
      final ttsResult = await _kokoro!.createTTS(
        text: phonemes,
        voice: _voiceName.isEmpty ? 'af_heart' : _voiceName,
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
    builder.add(pcm16.buffer.asUint8List());

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
    _playerSubscription?.cancel();
    await _audioPlayer?.dispose();
    _initialized = false;
  }
}
