import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chapter.dart';
import '../models/settings_model.dart';
import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/control_bar.dart';
import '../widgets/reader_canvas.dart';
import '../widgets/seekbar.dart';
import 'analytics_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readerState = ref.watch(readerProvider);
    final readerNotifier = ref.read(readerProvider.notifier);
    final settings = ref.watch(settingsProvider);

    final book = readerState.currentBook;

    return Scaffold(
      backgroundColor: _getBackgroundColor(settings.theme),
      appBar: AppBar(
        backgroundColor: _getAppBarColor(settings.theme),
        elevation: 0,
        title: Text(
          book?.title ?? 'CorNigrum Reader',
          style: TextStyle(
            color: _getTextColor(settings.theme),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (book != null && book.chapters.length > 1)
            PopupMenuButton<int>(
              icon: Icon(Icons.list_alt_rounded, color: _getTextColor(settings.theme)),
              initialValue: readerState.currentChapterIndex,
              onSelected: (idx) {
                readerNotifier.loadBook(book, chapterIndex: idx);
              },
              itemBuilder: (context) => book.chapters
                  .asMap()
                  .entries
                  .map((e) => PopupMenuItem(
                        value: e.key,
                        child: Text(e.value.title),
                      ))
                  .toList(),
            ),

          IconButton(
            icon: Icon(Icons.insights_rounded, color: _getTextColor(settings.theme)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              );
            },
          ),

          IconButton(
            icon: Icon(Icons.local_library_rounded, color: _getTextColor(settings.theme)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LibraryScreen()),
              );
            },
          ),

          IconButton(
            icon: Icon(Icons.settings_rounded, color: _getTextColor(settings.theme)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!readerState.isEngineReady)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade600),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Engine Needs Model & Voice Files',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            readerState.errorMessage ?? 'Import Kokoro .onnx model & voice file in Settings.',
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                      child: const Text('Setup', style: TextStyle(color: Colors.amberAccent)),
                    ),
                  ],
                ),
              )
            else if (readerState.errorMessage != null)
              Container(
                color: Colors.redAccent.shade700,
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        readerState.errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

            const Expanded(
              child: ReaderCanvas(),
            ),

            const Seekbar(),

            const ControlBar(),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.obsidian:
        return const Color(0xFF09090B);
      case AppTheme.sepia:
        return const Color(0xFFFBF0D9);
      case AppTheme.light:
        return Colors.white;
      case AppTheme.pitchBlack:
        return Colors.black;
    }
  }

  Color _getAppBarColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.obsidian:
        return const Color(0xFF18181B);
      case AppTheme.sepia:
        return const Color(0xFFE8DCB8);
      case AppTheme.light:
        return const Color(0xFFF4F4F5);
      case AppTheme.pitchBlack:
        return Colors.black;
    }
  }

  Color _getTextColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.obsidian:
      case AppTheme.pitchBlack:
        return Colors.white;
      case AppTheme.sepia:
        return const Color(0xFF433422);
      case AppTheme.light:
        return const Color(0xFF18181B);
    }
  }
}
