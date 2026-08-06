import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings_model.dart';
import '../providers/settings_provider.dart';

class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAlignment.start,
      children: [
        const Text(
          'App Theme Mode',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _themeCard(
              context,
              theme: AppTheme.obsidian,
              title: 'Obsidian',
              bg: const Color(0xFF18181B),
              text: Colors.white,
              current: settings.theme,
              onTap: () => settingsNotifier.updateTheme(AppTheme.obsidian),
            ),
            _themeCard(
              context,
              theme: AppTheme.sepia,
              title: 'Sepia',
              bg: const Color(0xFFFBF0D9),
              text: const Color(0xFF2C221E),
              current: settings.theme,
              onTap: () => settingsNotifier.updateTheme(AppTheme.sepia),
            ),
            _themeCard(
              context,
              theme: AppTheme.light,
              title: 'Light',
              bg: Colors.white,
              text: const Color(0xFF18181B),
              current: settings.theme,
              onTap: () => settingsNotifier.updateTheme(AppTheme.light),
            ),
            _themeCard(
              context,
              theme: AppTheme.pitchBlack,
              title: 'OLED',
              bg: Colors.black,
              text: Colors.white,
              current: settings.theme,
              onTap: () => settingsNotifier.updateTheme(AppTheme.pitchBlack),
            ),
          ],
        ),
      ],
    );
  }

  Widget _themeCard(
    BuildContext context, {
    required AppTheme theme,
    required String title,
    required Color bg,
    required Color text,
    required AppTheme current,
    required VoidCallback onTap,
  }) {
    final isSelected = theme == current;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.redAccent : Colors.grey.shade600,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
