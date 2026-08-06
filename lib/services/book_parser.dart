import 'dart:io';
import 'package:epub_plus/epub_plus.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:path/path.dart' as p;

import '../models/book.dart';
import '../models/chapter.dart';

class BookParser {
  static final _htmlUnescape = HtmlUnescape();

  static Future<Book> parseFile(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    if (ext == '.epub') {
      return parseEpub(file);
    } else if (ext == '.txt') {
      return parseTxt(file);
    } else {
      throw FormatException('Unsupported file format: $ext');
    }
  }

  static Future<Book> parseTxt(File file) async {
    final content = await file.readAsString();
    final title = p.basenameWithoutExtension(file.path);

    final chapter = Chapter(
      id: 'ch_0',
      title: 'Full Text',
      content: content,
      sentenceCount: 0,
      currentSentenceIndex: 0,
      completionPercent: 0.0,
    );

    return Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      author: 'Unknown Author',
      filePath: file.path,
      chapters: [chapter],
      currentChapterIndex: 0,
      currentSentenceIndex: 0,
      progressPercent: 0.0,
      addedAt: DateTime.now(),
    );
  }

  static Future<Book> parseEpub(File file) async {
    final bytes = await file.readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    final title = epubBook.Title ?? p.basenameWithoutExtension(file.path);
    final author = epubBook.Author ?? 'Unknown Author';

    final chapters = <Chapter>[];
    int chapterIdx = 0;

    if (epubBook.Chapters != null) {
      for (final ch in epubBook.Chapters!) {
        final text = _extractTextFromChapter(ch);
        if (text.trim().isNotEmpty) {
          chapters.add(Chapter(
            id: 'ch_$chapterIdx',
            title: ch.Title ?? 'Chapter ${chapterIdx + 1}',
            content: text,
            sentenceCount: 0,
            currentSentenceIndex: 0,
            completionPercent: 0.0,
          ));
          chapterIdx++;
        }
      }
    }

    if (chapters.isEmpty) {
      final allHtml = epubBook.Content?.Html;
      if (allHtml != null && allHtml.isNotEmpty) {
        final buffer = StringBuffer();
        for (final htmlFile in allHtml.values) {
          final text = _cleanHtml(htmlFile.Content ?? '');
          buffer.writeln(text);
        }
        chapters.add(Chapter(
          id: 'ch_0',
          title: 'Full Book',
          content: buffer.toString(),
          sentenceCount: 0,
          currentSentenceIndex: 0,
          completionPercent: 0.0,
        ));
      }
    }

    return Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      author: author,
      filePath: file.path,
      chapters: chapters,
      currentChapterIndex: 0,
      currentSentenceIndex: 0,
      progressPercent: 0.0,
      addedAt: DateTime.now(),
    );
  }

  static String _extractTextFromChapter(EpubChapter chapter) {
    final buffer = StringBuffer();
    if (chapter.HtmlContent != null) {
      buffer.writeln(_cleanHtml(chapter.HtmlContent!));
    }
    if (chapter.SubChapters != null) {
      for (final sub in chapter.SubChapters!) {
        buffer.writeln(_extractTextFromChapter(sub));
      }
    }
    return buffer.toString();
  }

  static String _cleanHtml(String html) {
    var cleaned = html.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>'), ' ');
    cleaned = _htmlUnescape.convert(cleaned);
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    return cleaned.trim();
  }
}
