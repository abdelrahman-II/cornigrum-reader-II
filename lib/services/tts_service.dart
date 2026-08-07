import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/sentence.dart';

typedef RtfCallback = void Function(
    double rtf, int latencyMs, int prefetchedCount, int prefetchLimit);

class TtsService extends ChangeNotifier {
  List<Sentence> _sentences = [];
  int _currentSentenceIndex = 0;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _prefetchLimit = 5;

  double _currentRtf = 0.16;
  int _currentInferenceMs = 120;
  RtfCallback? onRtfUpdate;

  String _primaryDelimiters = '.!?\n';
  String _secondaryDelimiters = ',;:—';

  List<Sentence> get sentences => _sentences;
  int get currentSentenceIndex => _currentSentenceIndex;
  bool get isPlaying => _isPlaying;
  double get currentRtf => _currentRtf;
  int get currentInferenceMs => _currentInferenceMs;

  void setDelimiters(String primary, String secondary) {
    _primaryDelimiters = primary.isEmpty ? '.!?\n' : primary;
    _secondaryDelimiters = secondary.isEmpty ? ',;:—' : secondary;
  }

  void setSpeed(double speed) {
    _playbackSpeed = speed;
    notifyListeners();
  }

  void setPrefetchLimit(int limit) {
    _prefetchLimit = limit;
    notifyListeners();
  }

  /// Parses text into sentences while safely escaping custom delimiters (including quotes " ' )
  List<Sentence> parseText(String text) {
    if (text.trim().isEmpty) return [];

    String escapeCharSet(String input) {
      return input.split('').map((c) {
        if (RegExp(r'[a-zA-Z0-9]').hasMatch(c)) return c;
        return '\\$c';
      }).join('');
    }

    final primaryEsc = escapeCharSet(_primaryDelimiters);
    final secondaryEsc = escapeCharSet(_secondaryDelimiters); // استخدام الثانوي
    RegExp regex;
    try {
      regex = RegExp('([^$primaryEsc$secondaryEsc]+[$primaryEsc$secondaryEsc]+|[^$primaryEsc$secondaryEsc]+\$)');
    } catch (_) {
      regex = RegExp(r'([^.!?\n,;:—]+[.!?\n,;:—]+|[^.!?\n,;:—]+$)');
    }

    final matches = regex.allMatches(text);
    final List<Sentence> parsed = [];
    int globalOffset = 0;
    int index = 0;

    for (final match in matches) {
      final chunk = match.group(0) ?? '';
      if (chunk.trim().isNotEmpty) {
        final start = globalOffset;
        final end = globalOffset + chunk.length;
        parsed.add(Sentence(
          index: index++,
          text: chunk,
          charStart: start,
          charEnd: end,
        ));
      }
      globalOffset += chunk.length;
    }

    _sentences = parsed;
    notifyListeners();
    return parsed;
  }

  void playSentence(int index) {
    if (index < 0 || index >= _sentences.length) return;

    _currentSentenceIndex = index;
    _isPlaying = true;

    final sentenceText = _sentences[index].text;

    // Simulate Kokoro-82M ONNX inference RTF (Real-time factor) & latency
    final estAudioDuration = max(1.0, (sentenceText.length * 0.06) / _playbackSpeed);
    final wordCount = sentenceText.trim().split(RegExp(r'\s+')).length;
    final estInferenceMs = (35 + wordCount * 12 + Random().nextInt(15)).round();
    final calculatedRtf = double.parse(((estInferenceMs / 1000) / estAudioDuration).toStringAsFixed(3));

    _currentInferenceMs = estInferenceMs;
    _currentRtf = calculatedRtf;

    final prefetchedCount = min(
      _prefetchLimit,
      max(0, _sentences.length - index - 1),
    );

    if (onRtfUpdate != null) {
      onRtfUpdate!(calculatedRtf, estInferenceMs, prefetchedCount, _prefetchLimit);
    }

    notifyListeners();
  }

  void play() {
    _isPlaying = true;
    playSentence(_currentSentenceIndex);
  }

  void pause() {
    _isPlaying = false;
    notifyListeners();
  }

  void stop() {
    _isPlaying = false;
    _currentSentenceIndex = 0;
    notifyListeners();
  }

  void nextSentence() {
    if (_currentSentenceIndex < _sentences.length - 1) {
      playSentence(_currentSentenceIndex + 1);
    } else {
      stop();
    }
  }

  void previousSentence() {
    if (_currentSentenceIndex > 0) {
      playSentence(_currentSentenceIndex - 1);
    }
  }
}
