import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

class DelimiterEditor extends ConsumerStatefulWidget {
  const DelimiterEditor({super.key});

  @override
  ConsumerState<DelimiterEditor> createState() => _DelimiterEditorState();
}

class _DelimiterEditorState extends ConsumerState<DelimiterEditor> {
  late TextEditingController _primaryController;
  late TextEditingController _secondaryController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _primaryController = TextEditingController(text: settings.primaryDelimiters);
    _secondaryController = TextEditingController(text: settings.secondaryDelimiters);
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAlignment.start,
      children: [
        const Text(
          'Text Parsing Delimiters',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _primaryController,
          decoration: const InputDecoration(
            labelText: 'Primary Delimiters (Sentence end)',
            border: OutlineInputBorder(),
            hintText: '.!?\\n',
          ),
          onChanged: (val) {
            settingsNotifier.updateDelimiters(val, _secondaryController.text);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _secondaryController,
          decoration: const InputDecoration(
            labelText: 'Secondary Delimiters (Pause/Phrase)',
            border: OutlineInputBorder(),
            hintText: ',;:—',
          ),
          onChanged: (val) {
            settingsNotifier.updateDelimiters(_primaryController.text, val);
          },
        ),
      ],
    );
  }
}
