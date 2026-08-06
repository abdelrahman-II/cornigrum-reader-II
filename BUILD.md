# CorNigrum Reader — Building Instructions 🛠️

## Overview
CorNigrum Reader builds out-of-the-box using the `kokoro_tts_flutter` package **without requiring pre-embedded AI model files in the build source**. Users can import Kokoro `.onnx` model files and voice `.bin` / `.json` files dynamically at runtime in the app UI (Settings & Setup Banner).

## Prerequisites
- **Flutter SDK**: 3.19.x or higher
- **JDK**: 17

## Build Steps

1. **Initialize Directory Structure**:
   ```bash
   cd flutter_app
   chmod +x scripts/download_assets.sh
   ./scripts/download_assets.sh
   ```

2. **Install Flutter Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Build Release APK**:
   ```bash
   flutter build apk --release --no-tree-shake-icons
   ```

Output APK path: `build/app/outputs/flutter-apk/app-release.apk`

## Adding AI Models & Voices in App
1. Open **CorNigrum Reader**.
2. Tap **"Setup"** or go to **Settings (⚙️)**.
3. Tap **"Import .onnx Model File"** and select `kokoro-v1.0.onnx`.
4. Tap **"Import Voice File"** and select your voice preset (`.bin` or `.json`).
5. Offline AI TTS speech synthesis will synthesize and read text seamlessly!

