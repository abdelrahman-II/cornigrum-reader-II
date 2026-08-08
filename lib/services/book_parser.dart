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

    final title = epubBook.title ?? p.basenameWithoutExtension(file.path);
    final author = epubBook.author ?? 'Unknown Author';

    final chapters = <Chapter>[];
    int chapterIdx = 0;

    if (epubBook.chapters != null) {
      for (final ch in epubBook.chapters!) {
        final text = _extractTextFromChapter(ch);
        if (text.trim().isNotEmpty) {
          chapters.add(Chapter(
            id: 'ch_$chapterIdx',
            title: ch.title ?? 'Chapter ${chapterIdx + 1}',
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
      final allHtml = epubBook.content?.html;
      if (allHtml != null && allHtml.isNotEmpty) {
        final buffer = StringBuffer();
        for (final htmlFile in allHtml.values) {
          final text = _cleanHtml(htmlFile.content ?? '');
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
    if (chapter.htmlContent != null) {
      buffer.writeln(_cleanHtml(chapter.htmlContent!));
    }
    if (chapter.subChapters != null) {
      for (final sub in chapter.subChapters!) {
        buffer.writeln(_extractTextFromChapter(sub));
      }
    }
    return buffer.toString();
  }

  static String _cleanHtml(String html) {
    // إزالة style و script
    var cleaned = html.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    // إزالة جميع الوسوم بشكل متكرر للتخلص من الوسوم المتداخلة
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>'), ' ');
    // فك تشفير الكيانات
    cleaned = _htmlUnescape.convert(cleaned);
    // توحيد المسافات
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');
    // توحيد الأسطر الفارغة
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    return cleaned.trim();
  }
}
