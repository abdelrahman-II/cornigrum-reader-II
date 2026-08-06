import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../ffi/isolate_bridge.dart';
import '../models/chapter.dart';

class ExportService {
  final CornigrumIsolateBridge bridge;

  ExportService(this.bridge);

  Future<String> exportChapterToWav({
    required Chapter chapter,
    required double speed,
    required void Function(double progress, String status) onProgress,
  }) async {
    final sentences = await bridge.parseText(chapter.content);
    if (sentences.isEmpty) {
      throw Exception('Chapter contains no text');
    }

    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final wavFiles = <String>[];

    for (int i = 0; i < sentences.length; i++) {
      onProgress(i / sentences.length, 'Synthesizing sentence ${i + 1}/${sentences.length}');
      final partPath = '${exportDir.path}/part_${timestamp}_$i.wav';
      await bridge.exportSentenceToWav(i, speed, partPath);
      wavFiles.add(partPath);
    }

    onProgress(0.95, 'Concatenating WAV parts...');
    final finalPath = '${exportDir.path}/${_sanitizeFileName(chapter.title)}_$timestamp.wav';
    await _concatWavFiles(wavFiles, finalPath);

    for (final part in wavFiles) {
      final f = File(part);
      if (await f.exists()) await f.delete();
    }

    onProgress(1.0, 'Export complete');
    return finalPath;
  }

  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static Future<void> _concatWavFiles(List<String> parts, String outputPath) async {
    if (parts.isEmpty) return;

    final outFile = File(outputPath);
    final sink = outFile.openWrite();

    int totalDataSize = 0;
    int sampleRate = 24000;

    for (final part in parts) {
      final file = File(part);
      final len = await file.length();
      if (len > 44) {
        totalDataSize += (len - 44).toInt();
      }
    }

    final header = List<int>.filled(44, 0);
    final totalFileSize = 36 + totalDataSize;

    header[0] = 0x52; header[1] = 0x49; header[2] = 0x46; header[3] = 0x46; // RIFF
    header[4] = totalFileSize & 0xFF;
    header[5] = (totalFileSize >> 8) & 0xFF;
    header[6] = (totalFileSize >> 16) & 0xFF;
    header[7] = (totalFileSize >> 24) & 0xFF;

    header[8] = 0x57; header[9] = 0x41; header[10] = 0x56; header[11] = 0x45; // WAVE
    header[12] = 0x66; header[13] = 0x6D; header[14] = 0x74; header[15] = 0x20; // fmt 
    header[16] = 16; header[17] = 0; header[18] = 0; header[19] = 0; // Subchunk1Size
    header[20] = 1; header[21] = 0; // AudioFormat (PCM)
    header[22] = 1; header[23] = 0; // NumChannels (1)

    header[24] = sampleRate & 0xFF;
    header[25] = (sampleRate >> 8) & 0xFF;
    header[26] = (sampleRate >> 16) & 0xFF;
    header[27] = (sampleRate >> 24) & 0xFF;

    final byteRate = sampleRate * 2;
    header[28] = byteRate & 0xFF;
    header[29] = (byteRate >> 8) & 0xFF;
    header[30] = (byteRate >> 16) & 0xFF;
    header[31] = (byteRate >> 24) & 0xFF;

    header[32] = 2; header[33] = 0; // BlockAlign
    header[34] = 16; header[35] = 0; // BitsPerSample

    header[36] = 0x64; header[37] = 0x61; header[38] = 0x74; header[39] = 0x61; // data
    header[40] = totalDataSize & 0xFF;
    header[41] = (totalDataSize >> 8) & 0xFF;
    header[42] = (totalDataSize >> 16) & 0xFF;
    header[43] = (totalDataSize >> 24) & 0xFF;

    sink.add(header);

    for (final part in parts) {
      final file = File(part);
      final bytes = await file.readAsBytes();
      if (bytes.length > 44) {
        sink.add(bytes.sublist(44));
      }
    }

    await sink.flush();
    await sink.close();
  }
}
