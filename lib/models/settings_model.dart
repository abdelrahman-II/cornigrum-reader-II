import 'package:flutter/material.dart';
import '../models/voice.dart'; 

enum AppTheme { obsidian, sepia, light, pitchBlack }
enum BatchMode { sentenceCount, pageBased }
enum FontFamily { merriweather, inter }

class SettingsModel {
  final AppTheme theme;
  final Color highlightColor;
  final double fontSize;
  final double lineSpacing;
  final double sideMargin;
  final FontFamily fontFamily;
  final bool keepScreenAwake;
  final bool autoScroll;
  final String modelPath;
  final String voicePath;
  final String voiceName;
  final List<Voice> customVoices;
  final String primaryDelimiters;
  final String secondaryDelimiters;
  final BatchMode batchMode;
  final int batchSize;
  final double playbackSpeed;
  final bool isHorizontalFlip;
  final bool isQuantizedInt8;

  const SettingsModel({
    this.theme = AppTheme.obsidian,
    this.highlightColor = const Color(0xFFDC2626),
    this.fontSize = 18.0,
    this.lineSpacing = 1.5,
    this.sideMargin = 16.0,
    this.fontFamily = FontFamily.merriweather,
    this.keepScreenAwake = true,
    this.autoScroll = true,
    this.modelPath = '',
    this.voicePath = '',
    this.voiceName = 'No Voice Selected',
    this.customVoices = const [],
    this.primaryDelimiters = '.!?\n',
    this.secondaryDelimiters = ',;:—',
    this.batchMode = BatchMode.sentenceCount,
    this.batchSize = 5,
    this.playbackSpeed = 1.0,
    this.isHorizontalFlip = false,
    this.isQuantizedInt8 = false,
  });

  SettingsModel copyWith({
    AppTheme? theme,
    Color? highlightColor,
    double? fontSize,
    double? lineSpacing,
    double? sideMargin,
    FontFamily? fontFamily,
    bool? keepScreenAwake,
    bool? autoScroll,
    String? modelPath,
    String? voicePath,
    String? voiceName,
    List<Voice>? customVoices,
    String? primaryDelimiters,
    String? secondaryDelimiters,
    BatchMode? batchMode,
    int? batchSize,
    double? playbackSpeed,
    bool? isHorizontalFlip,
    bool? isQuantizedInt8,
  }) {
    return SettingsModel(
      theme: theme ?? this.theme,
      highlightColor: highlightColor ?? this.highlightColor,
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      sideMargin: sideMargin ?? this.sideMargin,
      fontFamily: fontFamily ?? this.fontFamily,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      autoScroll: autoScroll ?? this.autoScroll,
      modelPath: modelPath ?? this.modelPath,
      voicePath: voicePath ?? this.voicePath,
      voiceName: voiceName ?? this.voiceName,
      customVoices: customVoices ?? this.customVoices,
      primaryDelimiters: primaryDelimiters ?? this.primaryDelimiters,
      secondaryDelimiters: secondaryDelimiters ?? this.secondaryDelimiters,
      batchMode: batchMode ?? this.batchMode,
      batchSize: batchSize ?? this.batchSize,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isHorizontalFlip: isHorizontalFlip ?? this.isHorizontalFlip,
      isQuantizedInt8: isQuantizedInt8 ?? this.isQuantizedInt8,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme.index,
        'highlightColor': highlightColor.toARGB32(),
        'fontSize': fontSize,
        'lineSpacing': lineSpacing,
        'sideMargin': sideMargin,
        'fontFamily': fontFamily.index,
        'keepScreenAwake': keepScreenAwake,
        'autoScroll': autoScroll,
        'modelPath': modelPath,
        'voicePath': voicePath,
        'voiceName': voiceName,
        'customVoices': customVoices.map((v) => v.toJson()).toList(),
        'primaryDelimiters': primaryDelimiters,
        'secondaryDelimiters': secondaryDelimiters,
        'batchMode': batchMode.index,
        'batchSize': batchSize,
        'playbackSpeed': playbackSpeed,
        'isHorizontalFlip': isHorizontalFlip,
        'isQuantizedInt8': isQuantizedInt8,
      };

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
        theme: AppTheme.values[(json['theme'] ?? 0).clamp(0, AppTheme.values.length - 1)],
        highlightColor: Color(json['highlightColor'] ?? 0xFFDC2626),
        fontSize: (json['fontSize'] ?? 18.0).toDouble(),
        lineSpacing: (json['lineSpacing'] ?? 1.5).toDouble(),
        sideMargin: (json['sideMargin'] ?? 16.0).toDouble(),
        fontFamily: FontFamily.values[(json['fontFamily'] ?? 0).clamp(0, FontFamily.values.length - 1)],
        keepScreenAwake: json['keepScreenAwake'] ?? true,
        autoScroll: json['autoScroll'] ?? true,
        modelPath: json['modelPath'] ?? '',
        voicePath: json['voicePath'] ?? '',
        voiceName: json['voiceName'] ?? 'No Voice Selected',
        customVoices: (json['customVoices'] as List<dynamic>?)
                ?.map((item) => Voice.fromJson(item as Map<String, dynamic>))
                .toList() ??
            const [],
        primaryDelimiters: json['primaryDelimiters'] ?? '.!?\n',
        secondaryDelimiters: json['secondaryDelimiters'] ?? ',;:—',
        batchMode: BatchMode.values[(json['batchMode'] ?? 0).clamp(0, BatchMode.values.length - 1)],
        batchSize: (json['batchSize'] ?? 5).clamp(1, 10),
        playbackSpeed: (json['playbackSpeed'] ?? 1.0).toDouble(),
        isHorizontalFlip: json['isHorizontalFlip'] ?? false,
        isQuantizedInt8: json['isQuantizedInt8'] ?? false,
      );
}
