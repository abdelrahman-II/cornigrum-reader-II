# CorNigrum Reader - Flutter App

This directory contains the primary Flutter source code for **CorNigrum Reader** powered by **Kokoro-82M ONNX Runtime** and **Riverpod**.

For the full project documentation, architecture overview, prerequisites, and build steps, please refer to the main repository [README.md](../README.md).

## Quick Local Commands

```bash
# 1. Fetch dependencies & assets setup
./scripts/download_assets.sh
flutter pub get

# 2. Run app in debug mode
flutter run

# 3. Build Release APK
flutter build apk --release --no-tree-shake-icons
```

Refer to [BUILD.md](BUILD.md) for detailed CMake & NDK build guidelines.
