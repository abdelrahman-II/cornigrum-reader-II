import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../services/book_parser.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';

class LibraryNotifier extends StateNotifier<List<Book>> {
  final StorageService _storage;

  LibraryNotifier(this._storage) : super([]) {
    _load();
  }

  void _load() {
    state = _storage.loadBooks();
  }

  Future<void> addBookFromFile(File file) async {
    final book = await BookParser.parseFile(file);
    state = [...state, book];
    await _storage.saveBooks(state);
  }

  Future<void> removeBook(String bookId) async {
    state = state.where((b) => b.id != bookId).toList();
    await _storage.saveBooks(state);
  }

  Future<void> toggleFavorite(String bookId) async {
    state = state.map((b) {
      if (b.id == bookId) {
        return b.copyWith(isFavorite: !b.isFavorite);
      }
      return b;
    }).toList();
    await _storage.saveBooks(state);
  }

  Future<void> updateBookProgress({
    required String bookId,
    required int chapterIndex,
    required int sentenceIndex,
    required double progressPercent,
  }) async {
    state = state.map((b) {
      if (b.id == bookId) {
        return b.copyWith(
          currentChapterIndex: chapterIndex,
          currentSentenceIndex: sentenceIndex,
          progressPercent: progressPercent,
          lastReadAt: DateTime.now(),
        );
      }
      return b;
    }).toList();
    await _storage.saveBooks(state);
  }

  Future<void> addListeningTime(String bookId, int seconds) async {
    state = state.map((b) {
      if (b.id == bookId) {
        return b.copyWith(
          totalListeningSeconds: b.totalListeningSeconds + seconds,
        );
      }
      return b;
    }).toList();
    await _storage.saveBooks(state);
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, List<Book>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return LibraryNotifier(storage);
});
