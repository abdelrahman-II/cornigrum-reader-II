import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/reader_provider.dart';
import 'providers/settings_provider.dart';
import 'services/storage_service.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await StorageService.init();

  final container = ProviderContainer(
    overrides: [
      storageServiceProvider.overrideWithValue(storageService),
    ],
  );

  // // Initialize Native Engine in background
  // container.read(readerProvider.notifier).initEngine();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CornigrumApp(),
    ),
  );
}
