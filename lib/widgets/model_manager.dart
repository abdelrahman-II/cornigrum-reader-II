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
  bool? _isInt8ForCurrentModel; // مخزن مؤقت للخيار المرتبط بالموديل الحالي

  @override
  void initState() {
    super.initState();
    // قراءة الخيار من الإعدادات
    final settings = ref.read(settingsProvider);
    _isInt8ForCurrentModel = settings.isQuantizedInt8;
  }

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

        // سؤال المستخدم عن نوع Int8
        final isInt8 = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Model Type'),
            content: const Text('Is this an Int8 quantized model?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No (FP32)'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes (Int8)'),
              ),
            ],
          ),
        );
        if (isInt8 == null) {
          setState(() => _isImporting = false);
          return;
        }

        // نسخ الملف إلى مجلد التطبيق
        final appDir = await getApplicationDocumentsDirectory();
        final modelsDir = Directory(p.join(appDir.path, 'models'));
        if (!await modelsDir.exists()) {
          await modelsDir.create(recursive: true);
        }

        final targetFileName = p.basename(pickedFile.path);
        final targetPath = p.join(modelsDir.path, targetFileName);
        // نسخ (لا نقل)
        final savedModelFile = await pickedFile.copy(targetPath);

        // تحديث الإعدادات
        await ref.read(settingsProvider.notifier).updateModelPath(savedModelFile.path);
        await ref.read(settingsProvider.notifier).updateIsQuantizedInt8(isInt8);
        _isInt8ForCurrentModel = isInt8;

        // إعادة تهيئة المحرك
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

  Future<void> _deleteModel() async {
    final settings = ref.read(settingsProvider);
    final modelPath = settings.modelPath;
    if (modelPath.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: const Text('Are you sure you want to delete this model file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
      }
      // إعادة تعيين الإعدادات
      await ref.read(settingsProvider.notifier).updateModelPath('');
      await ref.read(settingsProvider.notifier).updateIsQuantizedInt8(false);
      _isInt8ForCurrentModel = false;
      // إعادة تهيئة المحرك (سيظهر خطأ بعدم وجود موديل)
      await ref.read(readerProvider.notifier).initEngine();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Model deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    // قراءة قيمة Int8 المخزنة مع الموديل
    final isInt8 = settings.isQuantizedInt8;

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
            color: hasModel 
                ? Colors.green.withOpacity(0.1) 
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasModel ? Colors.green.shade400 : Colors.orange.shade400,
            ),
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
                    if (hasModel)
                      Text(
                        'Int8: ${isInt8 ? "Yes" : "No"}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              if (hasModel)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _deleteModel,
                  tooltip: 'Delete model',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // عرض حالة خيار Int8 (غير قابل للتغيير أثناء وجود موديل)
        SwitchListTile(
          title: const Text('Int8 Quantized Model'),
          subtitle: const Text('This option is locked to the imported model type.'),
          value: isInt8,
          onChanged: null, // معطل
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),

        // زر رفع الموديل
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isImporting ? null : _pickAndImportModel,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: _isImporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(_isImporting ? 'Importing Model...' : 'Import .onnx Model File'),
          ),
        ),
      ],
    );
  }
}