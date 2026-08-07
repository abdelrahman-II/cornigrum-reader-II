import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sentence.dart';
import '../models/settings_model.dart';
import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';

class ReaderCanvas extends ConsumerStatefulWidget {
  const ReaderCanvas({super.key});

  @override
  ConsumerState<ReaderCanvas> createState() => _ReaderCanvasState();
}

class _ReaderCanvasState extends ConsumerState<ReaderCanvas> {
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _scrollToSentence(int index, List<Sentence> sentences) {
    if (!_scrollController.hasClients || sentences.isEmpty) return;
    final targetOffset = (index / sentences.length) *
        _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(readerProvider);
    final settings = ref.watch(settingsProvider);
    final readerNotifier = ref.read(readerProvider.notifier);

    ref.listen(readerProvider.select((s) => s.currentSentenceIndex), (prev, next) {
      if (settings.autoScroll && !settings.isHorizontalFlip) {
        _scrollToSentence(next, readerState.sentences);
      } else if (settings.isHorizontalFlip && _pageController.hasClients) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    });

    if (readerState.sentences.isEmpty) {
      return Center(
        child: Text(
          'No book loaded or chapter empty.',
          style: TextStyle(color: _getTextColor(settings.theme).withValues(alpha: 0.5)),
        ),
      );
    }

    final TextStyle textStyle = _getTextStyle(settings);

    if (settings.isHorizontalFlip) {
      return PageView.builder(
        controller: _pageController,
        itemCount: readerState.sentences.length,
        onPageChanged: (index) {
          readerNotifier.seekToSentence(index);
        },
        itemBuilder: (context, index) {
          final sentence = readerState.sentences[index];
          final isCurrent = index == readerState.currentSentenceIndex;

          return Container(
            color: _getBackgroundColor(settings.theme),
            padding: EdgeInsets.all(settings.sideMargin),
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: isCurrent
                      ? BoxDecoration(
                          color: settings.highlightColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: settings.highlightColor),
                        )
                      : null,
                  child: Text(
                    sentence.text,
                    style: textStyle.copyWith(
                      color: isCurrent
                          ? settings.highlightColor
                          : _getTextColor(settings.theme),
                      fontSize: settings.fontSize * 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(
      color: _getBackgroundColor(settings.theme),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: settings.sideMargin,
          vertical: 24,
        ),
        itemCount: readerState.sentences.length,
        itemBuilder: (context, index) {
          final sentence = readerState.sentences[index];
          final isCurrent = index == readerState.currentSentenceIndex;

          return GestureDetector(
            onTap: () {
              readerNotifier.seekToSentence(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrent
                    ? settings.highlightColor.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isCurrent
                    ? Border.all(
                        color: settings.highlightColor.withValues(alpha: 0.2),
                      )
                    : null,
              ),
              child: Text(
                sentence.text,
                style: textStyle.copyWith(
                  color: isCurrent
                      ? settings.highlightColor
                      : _getTextColor(settings.theme),
                  height: settings.lineSpacing,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  TextStyle _getTextStyle(SettingsModel settings) {
    switch (settings.fontFamily) {
      case FontFamily.merriweather:
        return GoogleFonts.merriweather(fontSize: settings.fontSize);
      case FontFamily.inter:
        return GoogleFonts.inter(fontSize: settings.fontSize);
    }
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

  Color _getTextColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.obsidian:
      case AppTheme.pitchBlack:
        return const Color(0xFFE4E4E7);
      case AppTheme.sepia:
        return const Color(0xFF2C221E);
      case AppTheme.light:
        return const Color(0xFF18181B);
    }
  }
}
