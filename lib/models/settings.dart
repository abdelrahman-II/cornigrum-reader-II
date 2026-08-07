// من المفروض ان هذا الملف مقرر حذفه لاحقا

// enum AppTheme { obsidian, sepia, light, pitchBlack }
// enum FontFamily { merriweather, inter, cairo, amiri, monospace, custom }

// class KokoroModelItem {
//   final String id;
//   final String name;
//   final String path;
//   final String? size;
//   final bool isCustom;

//   KokoroModelItem({
//     required this.id,
//     required this.name,
//     required this.path,
//     this.size,
//     this.isCustom = false,
//   });
// }

// class ReaderSettings {
//   AppTheme theme;
//   String highlightColor;
//   double fontSize;
//   double speechRate;
//   int prefetchLimit;
//   int batchSize;
//   double lineSpacing;
//   double sideMargin;
//   FontFamily fontFamily;
//   int fontWeight;
//   String? customFontName;
//   String? customFontPath;
//   bool keepScreenAwake;
//   bool autoScroll;
//   bool showRtfMonitor;
//   bool isHorizontalFlip;
//   String modelPath;
//   String? customModelName;
//   List<KokoroModelItem> availableModels;
//   String voicePath;
//   String voiceName;
//   String primaryDelimiters;
//   String secondaryDelimiters;

//   ReaderSettings({
//     this.theme = AppTheme.obsidian,
//     this.highlightColor = '#DC2626',
//     this.fontSize = 18.0,
//     this.speechRate = 1.0,
//     this.prefetchLimit = 5,
//     this.batchSize = 8,
//     this.lineSpacing = 1.5,
//     this.sideMargin = 16.0,
//     this.fontFamily = FontFamily.merriweather,
//     this.fontWeight = 400,
//     this.customFontName,
//     this.customFontPath,
//     this.keepScreenAwake = true,
//     this.autoScroll = true,
//     this.showRtfMonitor = true,
//     this.isHorizontalFlip = false,
//     this.modelPath = 'assets/models/kokoro.onnx',
//     this.customModelName,
//     List<KokoroModelItem>? availableModels,
//     this.voicePath = 'assets/voices/af_heart.bin',
//     this.voiceName = 'Heart (US Female)',
//     this.primaryDelimiters = '.!?\n',
//     this.secondaryDelimiters = ',;:—',
//   }) : availableModels = availableModels ?? [
//           KokoroModelItem(
//             id: 'kokoro-v1.0',
//             name: 'Kokoro-v1.0 (Built-in Quantized Q8)',
//             path: 'assets/models/kokoro.onnx',
//             size: '82MB',
//           ),
//           KokoroModelItem(
//             id: 'kokoro-v1.1-fp16',
//             name: 'Kokoro-v1.1 (High Precision FP16)',
//             path: 'assets/models/kokoro-fp16.onnx',
//             size: '164MB',
//           ),
//           KokoroModelItem(
//             id: 'kokoro-multi',
//             name: 'Kokoro-v0.19 Multilingual (Arabic/English/CJK)',
//             path: 'assets/models/kokoro-multi.onnx',
//             size: '95MB',
//           ),
//         ];
// }
