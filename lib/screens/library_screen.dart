import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/library_provider.dart';
import '../providers/reader_provider.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _pickAndImportBook(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      try {
        await ref.read(libraryProvider.notifier).addBookFromFile(file);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Book imported successfully!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to import book: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final readerNotifier = ref.read(readerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _pickAndImportBook(context, ref),
          ),
        ],
      ),
      body: books.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Your library is empty'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.file_open_rounded),
                    label: const Text('Import EPUB or TXT'),
                    onPressed: () => _pickAndImportBook(context, ref),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.book_rounded),
                    ),
                    title: Text(
                      book.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${book.author} • ${(book.progressPercent * 100).toStringAsFixed(0)}% read',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            book.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: book.isFavorite ? Colors.red : null,
                          ),
                          onPressed: () {
                            libraryNotifier.toggleFavorite(book.id);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () {
                            libraryNotifier.removeBook(book.id);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      readerNotifier.loadBook(
                        book,
                        chapterIndex: book.currentChapterIndex,
                        sentenceIndex: book.currentSentenceIndex,
                      );
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
    );
  }
}
