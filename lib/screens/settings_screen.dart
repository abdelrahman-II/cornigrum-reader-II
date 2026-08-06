import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings_model.dart';
import '../providers/settings_provider.dart';
import '../widgets/delimiter_editor.dart';
import '../widgets/model_manager.dart';
import '../widgets/theme_picker.dart';
import '../widgets/voice_manager.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ThemePicker(),
          const Divider(height: 32),

          const Text(
            'Typography & Layout',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          ListTile(
            title: const Text('Font Size'),
            subtitle: Slider(
              value: settings.fontSize,
              min: 12,
              max: 32,
              divisions: 20,
              label: settings.fontSize.toStringAsFixed(0),
              onChanged: (val) => settingsNotifier.updateFontSize(val),
            ),
          ),

          ListTile(
            title: const Text('Line Spacing'),
            subtitle: Slider(
              value: settings.lineSpacing,
              min: 1.0,
              max: 2.5,
              divisions: 15,
              label: settings.lineSpacing.toStringAsFixed(1),
              onChanged: (val) => settingsNotifier.updateLineSpacing(val),
            ),
          ),

          ListTile(
            title: const Text('Font Family'),
            trailing: DropdownButton<FontFamily>(
              value: settings.fontFamily,
              onChanged: (font) {
                if (font != null) settingsNotifier.updateFontFamily(font);
              },
              items: FontFamily.values
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.name.toUpperCase()),
                      ))
                  .toList(),
            ),
          ),

          ListTile(
            title: const Text('Highlight Color'),
            trailing: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: settings.highlightColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Pick Highlight Color'),
                  content: BlockPicker(
                    pickerColor: settings.highlightColor,
                    onColorChanged: (color) {
                      settingsNotifier.updateHighlightColor(color);
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
          ),

          const Divider(height: 32),

          const Text(
            'Reading & Performance',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          SwitchListTile(
            title: const Text('Keep Screen Awake'),
            value: settings.keepScreenAwake,
            onChanged: (val) => settingsNotifier.toggleKeepScreenAwake(val),
          ),

          SwitchListTile(
            title: const Text('Auto Scroll on Sentence Change'),
            value: settings.autoScroll,
            onChanged: (val) => settingsNotifier.toggleAutoScroll(val),
          ),

          SwitchListTile(
            title: const Text('Horizontal Page Flip View'),
            subtitle: const Text('Swipe left/right sentence by sentence'),
            value: settings.isHorizontalFlip,
            onChanged: (val) => settingsNotifier.toggleHorizontalFlip(val),
          ),

          ListTile(
            title: const Text('Sentence Queue / Prefetch (1 to 10)'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: settings.batchSize.toDouble().clamp(1.0, 10.0),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${settings.batchSize} sentences',
                  onChanged: (val) {
                    settingsNotifier.updateBatchMode(settings.batchMode, val.round());
                  },
                ),
                Text(
                  'Prefetches ${settings.batchSize} sentence(s) ahead in memory for smooth TTS playback.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          const ModelManager(),

          const Divider(height: 32),

          const VoiceManager(),

          const Divider(height: 32),

          const DelimiterEditor(),
        ],
      ),
    );
  }
}
