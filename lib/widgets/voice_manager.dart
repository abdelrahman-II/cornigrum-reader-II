import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/voice.dart';
import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';

class VoiceManager extends ConsumerStatefulWidget {
  const VoiceManager({super.key});

  @override
  ConsumerState<VoiceManager> createState() => _VoiceManagerState();
}

class _VoiceManagerState extends ConsumerState<VoiceManager> {
  bool _isImporting = false;

  Future<void> _pickAndImportVoice() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        final rawFileName = p.basenameWithoutExtension(pickedFile.path);

        final nameController = TextEditingController(text: rawFileName);

        final voiceName = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Voice Preset Name'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Voice Name',
                hintText: 'e.g. Heart Female, Custom Voice 1',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = nameController.text.trim();
                  Navigator.pop(context, text.isEmpty ? rawFileName : text);
                },
                child: const Text('Save Voice'),
              ),
            ],
          ),
        );

        if (voiceName == null) {
          setState(() => _isImporting = false);
          return;
        }

        final appDir = await getApplicationDocumentsDirectory();
        final voicesDir = Directory(p.join(appDir.path, 'voices'));
        if (!await voicesDir.exists()) {
          await voicesDir.create(recursive: true);
        }

        final targetFileName = p.basename(pickedFile.path);
        final targetPath = p.join(voicesDir.path, targetFileName);
        final savedVoiceFile = await pickedFile.copy(targetPath);

        final newVoice = Voice(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: voiceName,
          embeddingPath: savedVoiceFile.path,
          description: 'Custom imported voice binary',
          isBuiltIn: false,
        );

        await ref.read(settingsProvider.notifier).addCustomVoice(newVoice);
        await ref.read(readerProvider.notifier).initEngine();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voice "$voiceName" imported successfully!'),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import voice: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final allVoices = settings.customVoices;

    final currentVoicePath = settings.voicePath;
    final hasVoice = currentVoicePath.isNotEmpty &&
        (currentVoicePath.startsWith('assets/') || File(currentVoicePath).existsSync());

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
                backgroundColor: Colors.green.withValues(alpha: 0.1),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (allVoices.isEmpty)
        //   const Padding(
        //     padding: EdgeInsets.symmetric(vertical: 8),
        //     child: Text(
        //       'No voices imported yet. Click below to add a voice binary (.bin).',
        //       style: TextStyle(color: Colors.grey, fontSize: 13),
        //     ),
        //   )


          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No voices imported yet. Click below to add a voice binary (.bin).',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else
          ...allVoices.map((voice) {
            final exists = voice.embeddingPath.startsWith('assets/') ||
                File(voice.embeddingPath).existsSync();

            return RadioListTile<String>(
              title: Row(
                children: [
                  Expanded(child: Text(voice.name)),
                  if (!voice.isBuiltIn)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      onPressed: () async {
                        await settingsNotifier.removeCustomVoice(voice.id);
                        ref.read(readerProvider.notifier).initEngine();
                      },
                    ),
                ],
              ),
              subtitle: Text(
                exists
                    ? (voice.description ?? p.basename(voice.embeddingPath))
                    : '${voice.description ?? ''} (File missing)',
                style: TextStyle(
                  color: exists ? Colors.grey : Colors.red,
                  fontSize: 12,
                ),
              ),
              value: voice.id,  // استخدام id بدلاً من embeddingPath
              groupValue: _getSelectedVoiceId(settings), // دالة مساعدة
              activeColor: settings.highlightColor,
              onChanged: exists
                  ? (val) async {
                      if (val != null) {
                        // البحث عن الصوت المطابق
                        final selectedVoice = allVoices.firstWhere((v) => v.id == val);
                        await settingsNotifier.updateVoice(selectedVoice.embeddingPath, selectedVoice.name);
                        ref.read(readerProvider.notifier).initEngine();
                      }
                    }
                  : null,
            );
          }),

        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: _isImporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.record_voice_over_rounded),
            label: Text(_isImporting ? 'Importing Voice...' : 'Import Voice File (.bin)'),
            onPressed: _isImporting ? null : _pickAndImportVoice,
          ),
        ),
      ],
    );
  }

  String _getSelectedVoiceId(SettingsModel settings) {
    final allVoices = settings.customVoices;
    for (var v in allVoices) {
      if (v.embeddingPath == settings.voicePath) {
        return v.id;
      }
    }
    return '';
  }

}
