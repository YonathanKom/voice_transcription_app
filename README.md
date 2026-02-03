# 🎙️ Production-Grade Offline Voice Transcription App

A Flutter application featuring offline-first voice transcription powered by OpenAI Whisper, built with production-grade architecture and Material 3 design.

## 🏗️ Architecture

**Pattern**: Feature-First Clean Architecture
**State Management**: Riverpod 3.0 (compile-time safe, zero boilerplate)
**AI Inference**: Whisper.cpp via GGML (hardware-accelerated, CoreML on iOS)
**Audio**: 16kHz PCM WAV recording optimized for Whisper

## 📦 Tech Stack (Gold Standard Feb 2026)

| Component | Library | Rationale |
|-----------|---------|-----------|
| State Management | `flutter_riverpod` | Modern default with compile-time safety |
| AI Inference | `whisper_ggml` | Best Whisper.cpp wrapper with CoreML support |
| Audio Recording | `record` | Most reliable 16kHz PCM WAV recorder |
| Permissions | `permission_handler` | Standard permission management |
| Storage | `path_provider` | Platform-agnostic file paths |

## 🚀 Installation

### 1. Add Dependencies

```bash
# State Management
flutter pub add flutter_riverpod
flutter pub add riverpod_annotation
flutter pub add dev:riverpod_generator
flutter pub add dev:build_runner

# Offline Whisper AI
flutter pub add whisper_ggml

# Audio Recording
flutter pub add record

# Core utilities
flutter pub add path_provider
flutter pub add permission_handler
```

### 2. Configure Platforms

#### iOS (ios/Runner/Info.plist)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record your voice for transcription</string>
```

#### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### 3. Add Whisper Model to Assets

**Option A: Bundle model in app (Offline-First)**
1. Download a Whisper GGML model from [Hugging Face](https://huggingface.co/ggerganov/whisper.cpp/tree/main)
2. Create `assets/models/` directory
3. Add model file (e.g., `ggml-tiny.bin`)
4. Update `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/models/ggml-tiny.bin
```

**Option B: Auto-download on first run**
- Skip assets setup
- Model downloads automatically (requires internet once)

## 📁 Project Structure

```
lib/
├── main.dart
├── features/
│   └── transcription/
│       ├── data/
│       │   ├── models/
│       │   │   └── transcription_state.dart
│       │   └── services/
│       │       ├── whisper_service.dart
│       │       └── audio_service.dart
│       ├── presentation/
│       │   ├── providers/
│       │   │   └── transcription_provider.dart
│       │   └── screens/
│       │       └── transcription_screen.dart
│       └── domain/
│           └── entities/
```

## 🎯 Key Features

### ✅ Production-Ready
- **Background Isolates**: Transcription runs off main thread (60/120fps UI)
- **Memory Safety**: Strict typing, automatic resource disposal
- **Error Handling**: Comprehensive try-catch with user-friendly messages
- **Permission Management**: Runtime permission requests with settings fallback

### ✅ Offline-First
- **Zero Network Dependency**: All processing happens on-device
- **Model Caching**: Models copied from assets to device storage
- **CoreML Acceleration**: 3x faster on Apple Silicon (iOS/macOS)

### ✅ Material 3 UI
- **Adaptive Theming**: Light/dark mode support
- **State-Driven UI**: Real-time updates via Riverpod
- **Accessibility**: Semantic labels, high contrast support

## 🔧 How It Works

### 1. Model Initialization
```dart
// On app start
WhisperService.initialize()
  → Checks for model in assets
  → Copies to device storage
  → Falls back to download if needed
```

### 2. Audio Recording
```dart
// 16kHz PCM WAV (Whisper requirement)
RecordConfig(
  encoder: AudioEncoder.wav,
  sampleRate: 16000,
  numChannels: 1,
)
```

### 3. Background Transcription
```dart
// Runs on compute isolate
compute(_transcribeOnIsolate, params)
  → Loads audio file
  → Runs Whisper inference
  → Returns transcription text
```

## 📊 Performance

| Model | Size | Speed (iPhone 13) | Accuracy |
|-------|------|-------------------|----------|
| Tiny  | 75 MB | ~2-3s per minute | Good |
| Base  | 142 MB | ~5-8s per minute | Better |
| Small | 466 MB | ~15-20s per minute | Best |

**Recommendation**: Start with `tiny` for development, use `base` for production.

## 🐛 Troubleshooting

### Model not initializing
- Verify model file in `assets/models/`
- Check `pubspec.yaml` assets declaration
- Run `flutter clean && flutter pub get`

### Audio not recording
- Check microphone permissions in device settings
- Verify `Info.plist` (iOS) / `AndroidManifest.xml` (Android)
- Test on physical device (simulator audio can be unreliable)

### Slow transcription
- Ensure running in **Release mode** (`flutter run --release`)
- Use smaller model (tiny/base)
- On iOS, verify CoreML is enabled

## 📝 License

MIT License - feel free to use in commercial projects.

## 🙏 Credits

- **OpenAI Whisper**: Speech recognition model
- **Whisper.cpp**: C++ port by Georgi Gerganov
- **whisper_ggml**: Flutter wrapper
- **Riverpod**: State management by Remi Rousselet
