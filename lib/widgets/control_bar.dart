import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings_model.dart';
import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';

class ControlBar extends ConsumerWidget {
  const ControlBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readerState = ref.watch(readerProvider);
    final readerNotifier = ref.read(readerProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final isPlaying = readerState.isPlaying;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(settings.theme),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Speed Button
            PopupMenuButton<double>(
              initialValue: readerState.playbackSpeed,
              tooltip: 'Playback Speed',
              onSelected: (speed) {
                readerNotifier.setSpeed(speed);
                settingsNotifier.updatePlaybackSpeed(speed);
              },
              itemBuilder: (context) => [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                  .map((s) => PopupMenuItem(
                        value: s,
                        child: Text('${s}x'),
                      ))
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Text(
                  '${readerState.playbackSpeed}x',
                  style: TextStyle(
                    color: _getTextColor(settings.theme),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Previous Sentence
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: 32,
              color: _getTextColor(settings.theme),
              onPressed: () {
                readerNotifier.seekToSentence(
                  readerState.currentSentenceIndex - 1,
                );
              },
            ),

            // Play / Pause Button
            FloatingActionButton(
              heroTag: 'play_pause_fab',
              backgroundColor: settings.highlightColor,
              onPressed: readerState.isEngineReady
                  ? () {
                      if (isPlaying) {
                        readerNotifier.pause();
                      } else {
                        readerNotifier.play();
                      }
                    }
                  : null,
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),

            // Next Sentence
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 32,
              color: _getTextColor(settings.theme),
              onPressed: () {
                readerNotifier.seekToSentence(
                  readerState.currentSentenceIndex + 1,
                );
              },
            ),

            // Queue Indicator
            Tooltip(
              message: 'Engine Queue (${readerState.queueSize}/${readerState.queueCapacity})',
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Icon(
                      Icons.memory,
                      size: 16,
                      color: readerState.queueSize > 0
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${readerState.queueSize}',
                      style: TextStyle(
                        color: _getTextColor(settings.theme).withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(AppTheme theme) {
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
