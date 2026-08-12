import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/settings_model.dart';
import '../services/storage_service.dart';
import '../models/voice.dart';


import 'isolate_bridge_provider.dart';
import 'reader_provider.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});

class SettingsNotifier extends StateNotifier<SettingsModel> {
  final StorageService _storage;
  final Ref _ref; //  إضافة الـ Ref كمتغير داخل الكلاس

  SettingsNotifier(this._storage, this._ref) : super(const SettingsModel()) {
    _load();
  }

  void _load() {
    state = _storage.loadSettings();
    if (state.keepScreenAwake) {
      WakelockPlus.enable();
    }
  }

  Future<void> updateTheme(AppTheme theme) async {
    state = state.copyWith(theme: theme);
    await _storage.saveSettings(state);
  }

  Future<void> updateHighlightColor(Color color) async {
    state = state.copyWith(highlightColor: color);
    await _storage.saveSettings(state);
  }

  Future<void> updateFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    await _storage.saveSettings(state);
  }

  Future<void> updateLineSpacing(double spacing) async {
    state = state.copyWith(lineSpacing: spacing);
    await _storage.saveSettings(state);
  }

  Future<void> updateSideMargin(double margin) async {
    state = state.copyWith(sideMargin: margin);
    await _storage.saveSettings(state);
  }

  Future<void> updateFontFamily(FontFamily font) async {
    state = state.copyWith(fontFamily: font);
    await _storage.saveSettings(state);
  }

  Future<void> toggleKeepScreenAwake(bool value) async {
    state = state.copyWith(keepScreenAwake: value);
    if (value) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
    await _storage.saveSettings(state);
  }

  Future<void> toggleAutoScroll(bool value) async {
    state = state.copyWith(autoScroll: value);
    await _storage.saveSettings(state);
  }

  Future<void> updateModelPathWithInt8(String path, bool isInt8) async {
    state = state.copyWith(modelPath: path, isQuantizedInt8: isInt8);
    await _storage.saveSettings(state);
  }

  Future<void> clearModel() async {
    final currentPath = state.modelPath;
    if (currentPath.isNotEmpty) {
      try {
        final file = File(currentPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // ignore errors
      }
    }
    state = state.copyWith(
      modelPath: '',
      isQuantizedInt8: false,
    );
    await _storage.saveSettings(state);
  }

  Future<void> updateModelPath(String path) async {
    state = state.copyWith(modelPath: path);
    await _storage.saveSettings(state);
  }

  Future<void> updateVoice(String voicePath, String voiceName) async {
    state = state.copyWith(voicePath: voicePath, voiceName: voiceName);
    await _storage.saveSettings(state);
  }

  Future<void> addCustomVoice(Voice voice) async {
    final updatedList = List<Voice>.from(state.customVoices)..add(voice);
    state = state.copyWith(
      customVoices: updatedList,
      voicePath: voice.embeddingPath,
      voiceName: voice.name,
    );
    await _storage.saveSettings(state);
  }

  Future<void> removeCustomVoice(String voiceId) async {
    final updatedList = state.customVoices.where((v) => v.id != voiceId).toList();
    var newVoicePath = state.voicePath;
    var newVoiceName = state.voiceName;

    if (state.customVoices.any((v) => v.id == voiceId && v.embeddingPath == state.voicePath)) {
      if (updatedList.isNotEmpty) {
        newVoicePath = updatedList.first.embeddingPath;
        newVoiceName = updatedList.first.name;
      } else {
        newVoicePath = '';
        newVoiceName = 'No Voice Selected';
      }
    }

    state = state.copyWith(
      customVoices: updatedList,
      voicePath: newVoicePath,
      voiceName: newVoiceName,
    );
    await _storage.saveSettings(state);
  }

  Future<void> updateDelimiters(String primary, String secondary) async {
    state = state.copyWith(
      primaryDelimiters: primary,
      secondaryDelimiters: secondary,
    );
    await _storage.saveSettings(state);

    //  تعديل استخدام ref إلى _ref واستدعاء الـ Providers المصدرة
    final bridge = _ref.read(isolateBridgeProvider);
    await bridge.setDelimiters(primary, secondary);

    final readerState = _ref.read(readerProvider);
    if (readerState.currentBook != null) {
      await _ref.read(readerProvider.notifier).reloadCurrentBook();
    }
  }

  Future<void> updateBatchMode(BatchMode mode, int size) async {
    state = state.copyWith(batchMode: mode, batchSize: size);
    await _storage.saveSettings(state);
  }

  Future<void> updatePlaybackSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _storage.saveSettings(state);
  }

  Future<void> toggleHorizontalFlip(bool value) async {
    state = state.copyWith(isHorizontalFlip: value);
    await _storage.saveSettings(state);
  }

  Future<void> updateIsQuantizedInt8(bool value) async {
    state = state.copyWith(isQuantizedInt8: value);
    await _storage.saveSettings(state);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsModel>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage, ref);
});