import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/reader_provider.dart';
import 'providers/settings_provider.dart';
import 'services/storage_service.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

Future<void> setupLogging() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final logFile = File('${dir.path}/app_logs.txt');

    // إعادة تعيين دالة debugPrint الخاصة بـ Flutter
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null) return;

      // 1. الطباعة على الـ Console كالمعتاد
      debugPrintSynchronously(message, wrapWidth: wrapWidth);

      // 2. إضافة السجل إلى الملف بشكل غير متزامن (بدون كتابة Sync حتى لا تُعطل الواجهة)
      logFile.writeAsString(
        '${DateTime.now().toIso8601String()}: $message\n',
        mode: FileMode.append,
        flush: false,
      );
    };

    debugPrint('Logging system initialized successfully. Path: ${logFile.path}');
  } catch (e) {
    // في حال فشل الوصول للذاكرة لأي سبب
    print('Failed to setup logging: $e');
  }
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await StorageService.init();

  final container = ProviderContainer(
    overrides: [
      storageServiceProvider.overrideWithValue(storageService),
    ],
  );

  // Initialize Native Engine in background
  container.read(readerProvider.notifier).initEngine();

  // 2. تفعيل نظام السجلات
  await setupLogging();


  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CornigrumApp(),
    ),
  );
}
