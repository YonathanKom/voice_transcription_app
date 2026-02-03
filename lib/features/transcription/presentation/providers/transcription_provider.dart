import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import '../../data/services/whisper_service.dart';
import '../../data/services/audio_service.dart';
import '../../data/models/transcription_state.dart';

/// Provider for Whisper transcription service (singleton)
final whisperServiceProvider = Provider<WhisperTranscriptionService>((ref) {
  final service = WhisperTranscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for audio recording service (singleton)
final audioServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = AudioRecordingService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// State notifier for model initialization
class ModelNotifier extends StateNotifier<ModelState> {
  final WhisperTranscriptionService _whisperService;

  ModelNotifier(this._whisperService) : super(const ModelUninitialized());

  /// Initialize Whisper model
  Future<void> initializeModel({WhisperModel model = WhisperModel.tiny}) async {
    state = ModelInitializing(modelName: model.modelName);
    
    try {
      await _whisperService.initialize(model: model);
      state = ModelReady(modelName: model.modelName);
    } catch (e) {
      debugPrint('[ModelNotifier] Initialization failed: $e');
      state = ModelError(message: 'Failed to initialize model: ${e.toString()}');
    }
  }

  /// Change model
  Future<void> changeModel(WhisperModel model) async {
    state = ModelInitializing(modelName: model.modelName);
    
    try {
      await _whisperService.changeModel(model);
      state = ModelReady(modelName: model.modelName);
    } catch (e) {
      debugPrint('[ModelNotifier] Model change failed: $e');
      state = ModelError(message: 'Failed to change model: ${e.toString()}');
    }
  }
}

/// Provider for model state
final modelStateProvider = StateNotifierProvider<ModelNotifier, ModelState>((ref) {
  final whisperService = ref.watch(whisperServiceProvider);
  return ModelNotifier(whisperService);
});

/// State notifier for transcription operations
class TranscriptionNotifier extends StateNotifier<TranscriptionState> {
  final WhisperTranscriptionService _whisperService;
  final AudioRecordingService _audioService;
  
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;

  TranscriptionNotifier(
    this._whisperService,
    this._audioService,
  ) : super(const TranscriptionIdle());

  /// Request microphone permission
  Future<bool> requestPermission() async {
    try {
      return await _audioService.requestPermission();
    } catch (e) {
      state = TranscriptionError(
        message: 'Failed to request permission',
        exception: e as Exception,
      );
      return false;
    }
  }

  /// Start recording
  Future<void> startRecording() async {
    // Check permission
    if (!await _audioService.hasPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        state = const TranscriptionError(
          message: 'Microphone permission denied',
        );
        return;
      }
    }

    try {
      await _audioService.startRecording();
      _recordingStartTime = DateTime.now();
      
      // Update state every 100ms with recording duration
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_recordingStartTime != null) {
          final duration = DateTime.now().difference(_recordingStartTime!);
          state = TranscriptionRecording(duration: duration);
        }
      });
    } catch (e) {
      _recordingTimer?.cancel();
      state = TranscriptionError(
        message: 'Failed to start recording',
        exception: e as Exception,
      );
    }
  }

  /// Stop recording and transcribe
  Future<void> stopRecordingAndTranscribe() async {
    _recordingTimer?.cancel();
    _recordingStartTime = null;

    try {
      // Stop recording
      final audioPath = await _audioService.stopRecording();
      
      if (audioPath == null) {
        state = const TranscriptionError(
          message: 'Recording failed - no audio file created',
        );
        return;
      }

      final file = File(audioPath);
      final size = await file.length();
      debugPrint('Recording saved. Size: $size bytes');

      // Start transcription
      state = TranscriptionProcessing(audioPath: audioPath);
      
      final startTime = DateTime.now();
      final transcription = await _whisperService.transcribeAudio(
        audioPath: audioPath,
        language: 'auto',
      );
      final processingTime = DateTime.now().difference(startTime);

      if (transcription != null && transcription.isNotEmpty) {
        state = TranscriptionCompleted(
          text: transcription,
          audioPath: audioPath,
          processingTime: processingTime,
        );
      } else {
        state = const TranscriptionError(
          message: 'Transcription failed - no text returned',
        );
      }
    } catch (e) {
      debugPrint('[TranscriptionNotifier] Error: $e');
      state = TranscriptionError(
        message: 'Transcription failed: ${e.toString()}',
        exception: e as Exception,
      );
    }
  }

  /// Cancel recording
  Future<void> cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingStartTime = null;
    
    await _audioService.cancelRecording();
    state = const TranscriptionIdle();
  }

  /// Reset to idle state
  void reset() {
    _recordingTimer?.cancel();
    _recordingStartTime = null;
    state = const TranscriptionIdle();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }
}

/// Provider for transcription state
final transcriptionProvider = StateNotifierProvider<TranscriptionNotifier, TranscriptionState>((ref) {
  final whisperService = ref.watch(whisperServiceProvider);
  final audioService = ref.watch(audioServiceProvider);
  return TranscriptionNotifier(whisperService, audioService);
});
