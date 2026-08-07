import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';

class Seekbar extends ConsumerWidget {
  const Seekbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readerState = ref.watch(readerProvider);
    final readerNotifier = ref.read(readerProvider.notifier);
    final settings = ref.watch(settingsProvider);

    final total = readerState.sentences.length;
    final current = readerState.currentSentenceIndex;

    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        Slider(
          value: current.toDouble().clamp(0.0, (total - 1).toDouble()),
          min: 0.0,
          max: (total - 1).toDouble(),
          activeColor: settings.highlightColor,
          inactiveColor: settings.highlightColor.withValues(alpha: 0.3),
          onChanged: (val) {
            readerNotifier.seekToSentence(val.toInt());
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sentence ${current + 1} of $total',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                '${((current + 1) / total * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
