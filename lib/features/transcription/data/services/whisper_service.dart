import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// Service class for managing Whisper model and transcription
/// Handles model initialization, copying from assets, and background transcription
class WhisperTranscriptionService {
  final WhisperController _controller = WhisperController();
  WhisperModel _model = WhisperModel.tiny; // Default to tiny for speed
  bool _isInitialized = false;

  /// Get current model
  WhisperModel get currentModel => _model;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the Whisper model
  /// Downloads model if needed, or copies from assets for offline use
  Future<void> initialize({WhisperModel? model}) async {
    if (model != null) {
      _model = model;
    }

    try {
      // Try to load model from assets first (for offline-first approach)
      await _loadModelFromAssets();
      _isInitialized = true;
      debugPrint('[WhisperService] Model ${_model.modelName} initialized from assets');
    } catch (assetError) {
      debugPrint('[WhisperService] Asset loading failed: $assetError');
      
      try {
        // Fallback: download model if assets not available
        await _controller.downloadModel(_model);
        _isInitialized = true;
        debugPrint('[WhisperService] Model ${_model.modelName} downloaded');
      } catch (downloadError) {
        _isInitialized = false;
        debugPrint('[WhisperService] Model initialization failed: $downloadError');
        rethrow;
      }
    }
  }

  /// Load Whisper model from app assets to device storage
  /// This ensures completely offline operation
  Future<void> _loadModelFromAssets() async {
    final modelFileName = 'ggml-${_model.modelName}.bin';
    final modelPath = await _controller.getPath(_model);
    final modelFile = File(modelPath);

    // Check if model already exists
    if (await modelFile.exists()) {
      final stats = await modelFile.stat();
      // Verify file is not corrupted (reasonable minimum size)
      if (stats.size > 1024 * 100) {
        debugPrint('[WhisperService] Model already exists at: $modelPath');
        return;
      }
    }

    // Load model from assets
    debugPrint('[WhisperService] Loading model from assets: $modelFileName');
    final assetData = await rootBundle.load('assets/models/$modelFileName');
    
    // Write to device storage
    await modelFile.create(recursive: true);
    await modelFile.writeAsBytes(
      assetData.buffer.asUint8List(
        assetData.offsetInBytes,
        assetData.lengthInBytes,
      ),
    );

    final fileSizeMB = (await modelFile.length()) / (1024 * 1024);
    debugPrint('[WhisperService] Model copied to: $modelPath (${fileSizeMB.toStringAsFixed(1)} MB)');
  }

  /// Transcribe audio file on a background isolate to prevent UI blocking
  /// Returns transcription text or null on error
  Future<String?> transcribeAudio({
    required String audioPath,
    String language = 'auto',
    Function(String)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('WhisperService not initialized. Call initialize() first.');
    }

    if (!await File(audioPath).exists()) {
      throw ArgumentError('Audio file does not exist: $audioPath');
    }

    try {
      // Run transcription on background isolate
      final result = await _controller.transcribe(
        model: _model,
        audioPath: audioPath,
        lang: language,
      );

      return result?.transcription.text;
    } catch (e) {
      debugPrint('[WhisperService] Transcription error: $e');
      return null;
    }
  }

  /// Change the Whisper model (requires re-initialization)
  Future<void> changeModel(WhisperModel newModel) async {
    _model = newModel;
    _isInitialized = false;
    await initialize();
  }

  /// Cleanup resources
  void dispose() {
    _isInitialized = false;
  }
}
