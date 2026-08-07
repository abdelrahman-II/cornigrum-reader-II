import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';

class ModelManager extends ConsumerStatefulWidget {
  const ModelManager({super.key});

  @override
  ConsumerState<ModelManager> createState() => _ModelManagerState();
}

class _ModelManagerState extends ConsumerState<ModelManager> {
  bool _isImporting = false;

  Future<void> _pickAndImportModel() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        final ext = p.extension(pickedFile.path).toLowerCase();

        if (ext != '.onnx' && !pickedFile.path.endsWith('.onnx')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Warning: Picked file does not have .onnx extension. Attempting import...'),
              ),
            );
          }
        }

        final appDir = await getApplicationDocumentsDirectory();
        final modelsDir = Directory(p.join(appDir.path, 'models'));
        if (!await modelsDir.exists()) {
          await modelsDir.create(recursive: true);
        }

        final targetFileName = p.basename(pickedFile.path);
        final targetPath = p.join(modelsDir.path, targetFileName);
        final savedModelFile = await pickedFile.copy(targetPath);

        await ref.read(settingsProvider.notifier).updateModelPath(savedModelFile.path);
        await ref.read(readerProvider.notifier).initEngine();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kokoro ONNX Model imported successfully!\n${p.basename(savedModelFile.path)}'),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import model: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showModelHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Where to get Kokoro ONNX?'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CorNigrum Reader uses Kokoro-82M ONNX model files for fast, offline speech synthesis.\n',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                'How to get model files:\n'
                '1. Download kokoro.onnx (v1.0) from HuggingFace / GitHub.\n'
                '2. Repository: onnx-community/Kokoro-82M-v1.0-ONNX\n'
                '3. Transfer or download kokoro.onnx to your device.\n'
                '4. Click "Import .onnx Model" button above and select the file.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final modelPath = settings.modelPath;
    final hasModel = modelPath.isNotEmpty &&
        (modelPath.startsWith('assets/') || File(modelPath).existsSync());

    final fileName = modelPath.isNotEmpty ? p.basename(modelPath) : 'None';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kokoro ONNX Model',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              onPressed: _showModelHelpDialog,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasModel ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasModel ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
          ),
          child: Row(
            children: [
              Icon(
                hasModel ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: hasModel ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasModel ? 'Model Loaded' : 'No Model Loaded',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasModel ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Int8 Quantized Model'),
          subtitle: const Text('Enable int8 model flag for faster performance & low memory'),
          value: settings.isQuantizedInt8 || modelPath.toLowerCase().contains('int8'),
          onChanged: (val) async {
            await ref.read(settingsProvider.notifier).updateIsQuantizedInt8(val);
            ref.read(readerProvider.notifier).initEngine();
          },
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _isImporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(_isImporting ? 'Importing Model...' : 'Import .onnx Model File'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _isImporting ? null : _pickAndImportModel,
          ),
        ),
      ),
    );
  }
}
