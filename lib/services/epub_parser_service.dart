import 'dart:convert';
import 'dart:io';
import '../models/book.dart';
import '../models/chapter.dart';

class EpubParserService {
  /// Parses imported TXT or EPUB files into a structured Book instance
  static Future<Book> parseFile(String path, String fileName) async {
    final file = File(path);
    final String content = await file.readAsString();

    final cleanTitle = fileName.replaceAll(RegExp(r'\.(txt|epub)$', caseSensitive: false), '');

    // Split text into chapters based on standard chapter headings or double line breaks
    final chapterRegex = RegExp(r'(Chapter\s+\d+|الفصل\s+\d+|--- PAGE \d+ ---)', caseSensitive: false);
    final matches = chapterRegex.allMatches(content);

    final List<Chapter> chapters = [];

    if (matches.isEmpty) {
      chapters.add(Chapter(
        id: 'ch_1',
        title: 'Chapter 1',
        content: content,
      ));
    } else {
      int chIdx = 1;
      int lastIndex = 0;
      String currentTitle = 'Chapter 1';

      for (final match in matches) {
        if (match.start > lastIndex) {
          final chapterText = content.substring(lastIndex, match.start).trim();
          if (chapterText.isNotEmpty) {
            chapters.add(Chapter(
              id: 'ch_$chIdx',
              title: currentTitle,
              content: chapterText,
            ));
            chIdx++;
          }
        }
        currentTitle = match.group(0) ?? 'Chapter $chIdx';
        lastIndex = match.start;
      }

      if (lastIndex < content.length) {
        final remainingText = content.substring(lastIndex).trim();
        if (remainingText.isNotEmpty) {
          chapters.add(Chapter(
            id: 'ch_$chIdx',
            title: currentTitle,
            content: remainingText,
          ));
        }
      }
    }

    return Book(
      id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
      title: cleanTitle,
      author: 'Imported Document',
      addedAt: DateTime.now().toIso8601String(),
      chapters: chapters,
    );
  }
}
