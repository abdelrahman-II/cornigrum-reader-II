import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ffi/isolate_bridge.dart';
import '../models/book.dart';
import '../models/sentence.dart';
import 'isolate_bridge_provider.dart';
import 'library_provider.dart';
import 'settings_provider.dart';

class ReaderState {
  final Book? currentBook;
  final int currentChapterIndex;
  final int currentSentenceIndex;
  final List<Sentence> sentences;
  final bool isPlaying;
  final bool isEngineReady;
  final int queueSize;
  final int queueCapacity;
  final double playbackSpeed;
  final String? errorMessage;

  const ReaderState({
    this.currentBook,
    this.currentChapterIndex = 0,
    this.currentSentenceIndex = 0,
    this.sentences = const [],
    this.isPlaying = false,
    this.isEngineReady = false,
    this.queueSize = 0,
    this.queueCapacity = 5,
    this.playbackSpeed = 1.0,
    this.errorMessage,
  });

  ReaderState copyWith({
    Book? currentBook,
    int? currentChapterIndex,
    int? currentSentenceIndex,
    List<Sentence>? sentences,
    bool? isPlaying,
    bool? isEngineReady,
    int? queueSize,
    int? queueCapacity,
    double? playbackSpeed,
    String? errorMessage,
  }) {
    return ReaderState(
      currentBook: currentBook ?? this.currentBook,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      sentences: sentences ?? this.sentences,
      isPlaying: isPlaying ?? this.isPlaying,
      isEngineReady: isEngineReady ?? this.isEngineReady,
      queueSize: queueSize ?? this.queueSize,
      queueCapacity: queueCapacity ?? this.queueCapacity,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      errorMessage: errorMessage,
    );
  }
}

class ReaderNotifier extends StateNotifier<ReaderState> {
  final CornigrumIsolateBridge _bridge;
  final Ref _ref;
  Timer? _statusPollTimer;

  ReaderNotifier(this._bridge, this._ref) : super(const ReaderState());

  Future<void> initEngine() async {
    final settings = _ref.read(settingsProvider);

    if (settings.modelPath.isEmpty) {
      state = state.copyWith(
        isEngineReady: false,
        errorMessage: 'No Kokoro ONNX model file (.onnx) loaded. Please import a model in Settings.',
      );
      return;
    }

    if (settings.voicePath.isEmpty) {
      state = state.copyWith(
        isEngineReady: false,
        errorMessage: 'No Voice embedding file (.bin) loaded. Please import a voice file in Settings.',
      );
      return;
    }

    if (!settings.modelPath.startsWith('assets/') && !File(settings.modelPath).existsSync()) {
      state = state.copyWith(
        isEngineReady: false,
        errorMessage: 'Model file not found on device at:\n${settings.modelPath}\nPlease import your .onnx model.',
      );
      return;
    }

    if (!settings.voicePath.startsWith('assets/') && !File(settings.voicePath).existsSync()) {
      state = state.copyWith(
        isEngineReady: false,
        errorMessage: 'Voice file not found on device at:\n${settings.voicePath}\nPlease import your voice .bin file.',
      );
      return;
    }

    try {
      await _bridge.initialize(
        modelPath: settings.modelPath,
        voicePath: settings.voicePath,
        voiceName: settings.voiceName,
        configPath: 'assets/config/config.json',
        vocabPath: 'assets/config/vocab.json',
        isInt8: settings.isQuantizedInt8,
      );
      await _bridge.setDelimiters(
        settings.primaryDelimiters,
        settings.secondaryDelimiters,
      );
      state = state.copyWith(isEngineReady: true, errorMessage: null);
      _startStatusPolling();
    } catch (e) {
      state = state.copyWith(
        isEngineReady: false,
        errorMessage: 'Engine initialization failed: $e',
      );
    }
  }

  void loadBook(Book book, {int chapterIndex = 0, int sentenceIndex = 0}) async {
    if (book.chapters.isEmpty) return;

    final actualChapterIdx = chapterIndex.clamp(0, book.chapters.length - 1);
    final chapter = book.chapters[actualChapterIdx];

    try {
      final parsedSentences = await _bridge.parseText(chapter.content);
      final sentences = List.generate(
        parsedSentences.length,
        (i) => Sentence(index: i, text: parsedSentences[i]),
      );

      state = state.copyWith(
        currentBook: book,
        currentChapterIndex: actualChapterIdx,
        currentSentenceIndex: sentenceIndex.clamp(0, sentences.length - 1),
        sentences: sentences,
        errorMessage: null,
      );

      _ref.read(libraryProvider.notifier).updateBookProgress(
            bookId: book.id,
            chapterIndex: actualChapterIdx,
            sentenceIndex: sentenceIndex,
            progressPercent: sentences.isEmpty
                ? 0.0
                : sentenceIndex / sentences.length,
          );

      if (state.isEngineReady) {
        await _bridge.prefetch(
          sentenceIndex,
          3,
          state.playbackSpeed,
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to parse text: $e');
    }
  }

  Future<void> play() async {
    if (!state.isEngineReady) return;
    try {
      await _bridge.play();
      state = state.copyWith(isPlaying: true);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Play failed: $e');
    }
  }

  Future<void> pause() async {
    if (!state.isEngineReady) return;
    try {
      await _bridge.pause();
      state = state.copyWith(isPlaying: false);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Pause failed: $e');
    }
  }

  Future<void> stop() async {
    if (!state.isEngineReady) return;
    try {
      await _bridge.stop();
      state = state.copyWith(isPlaying: false);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Stop failed: $e');
    }
  }

  Future<void> seekToSentence(int index) async {
    if (index < 0 || index >= state.sentences.length) return;

    state = state.copyWith(currentSentenceIndex: index);

    if (state.currentBook != null) {
      _ref.read(libraryProvider.notifier).updateBookProgress(
            bookId: state.currentBook!.id,
            chapterIndex: state.currentChapterIndex,
            sentenceIndex: index,
            progressPercent: state.sentences.isEmpty
                ? 0.0
                : index / state.sentences.length,
          );
    }

    if (state.isEngineReady) {
      await _bridge.stop();
      await _bridge.prefetch(index, 3, state.playbackSpeed);
      if (state.isPlaying) {
        await _bridge.play();
      }
    }
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    if (state.isEngineReady) {
      await _bridge.setSpeed(speed);
    }
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!state.isEngineReady) return;
      try {
        final status = await _bridge.getStatus();

        if (status.currentSentence >= 0 &&
            status.currentSentence != state.currentSentenceIndex) {
          seekToSentence(status.currentSentence);
        }

        state = state.copyWith(
          isPlaying: status.isPlaying,
          queueSize: status.queueSize,
          queueCapacity: status.queueCapacity,
        );

        if (status.isPlaying && status.queueSize < status.queueCapacity - 1) {
          final nextIdx = state.currentSentenceIndex + status.queueSize + 1;
          if (nextIdx < state.sentences.length) {
            await _bridge.synthesizeAndEnqueue(nextIdx, state.playbackSpeed);
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    super.dispose();
  }
}

final readerProvider =
    StateNotifierProvider<ReaderNotifier, ReaderState>((ref) {
  final bridge = ref.watch(isolateBridgeProvider);
  return ReaderNotifier(bridge, ref);
});
