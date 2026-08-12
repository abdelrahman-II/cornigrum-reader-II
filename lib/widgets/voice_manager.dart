import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

import '../models/voice.dart';
import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';
import '../models/settings_model.dart';

class VoiceManager extends ConsumerStatefulWidget {
  const VoiceManager({super.key});

  @override
  ConsumerState<VoiceManager> createState() => _VoiceManagerState();
}

class _VoiceManagerState extends ConsumerState<VoiceManager> {
  List<Voice> _builtInVoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    try {
      // Load index.json from assets/voices/
      final jsonString = await rootBundle.loadString('assets/voices/index.json');
      final List<dynamic> data = jsonDecode(jsonString);

      if (data.isEmpty) {
        throw Exception('Voice index is empty');
      }

      final voices = <Voice>[];
      for (final item in data) {
        // Validate required fields
        final id = item['id'] as String?;
        final file = item['file'] as String?;

        if (file == null) {
          debugPrint('⚠️ Voice entry missing "file" field: $item');
          continue;
        }

        // Verify the asset file exists
        final assetPath = 'assets/voices/$file';
        try {
          await rootBundle.loadString(assetPath);
        } catch (_) {
          debugPrint('⚠️ Voice file missing: $assetPath');
          continue;
        }

        voices.add(Voice(
          id: id ?? file.replaceAll('.json', ''),
          name: item['name'] as String? ?? file.replaceAll('.json', ''),
          embeddingPath: assetPath,
          isBuiltIn: true,
        ));
      }

      setState(() {
        _builtInVoices = voices;
        _isLoading = false;
      });

      if (voices.isEmpty) {
        throw Exception('No valid voice files found');
      }

      debugPrint('✅ Loaded ${voices.length} voices from index.json');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _builtInVoices = [];
      });
      debugPrint('Failed to load voices: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_builtInVoices.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kokoro Voice Preset',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No voices found in assets/voices/. Please add voice JSON files and an index.json file.',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      );
    }

    final currentVoicePath = settings.voicePath;
    final hasVoice = currentVoicePath.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kokoro Voice Preset',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (hasVoice)
              Chip(
                avatar: const Icon(Icons.check, size: 16, color: Colors.green),
                label: Text(
                  settings.voiceName,
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: Colors.green.withOpacity(0.1),
              ),
          ],
        ),
        const SizedBox(height: 8),

        ..._builtInVoices.map((voice) {
          final isSelected = voice.embeddingPath == settings.voicePath;
          return RadioListTile<String>(
            title: Text(voice.name),
            subtitle: Text(
              voice.embeddingPath,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            value: voice.id,
            groupValue: isSelected ? voice.id : null,
            activeColor: settings.highlightColor,
            onChanged: (val) async {
              if (val != null) {
                await settingsNotifier.updateVoice(voice.embeddingPath, voice.name);
                // Re-initialize engine with new voice
                ref.read(readerProvider.notifier).initEngine();
              }
            },
          );
        }),
        const SizedBox(height: 8),
        // Remove upload button as voices are built-in
      ],
    );
  }
}