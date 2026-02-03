import 'package:flutter/foundation.dart';

/// Transcription state for UI
@immutable
sealed class TranscriptionState {
  const TranscriptionState();
}

/// Initial idle state
class TranscriptionIdle extends TranscriptionState {
  const TranscriptionIdle();
}

/// Recording in progress
class TranscriptionRecording extends TranscriptionState {
  final Duration duration;
  
  const TranscriptionRecording({
    required this.duration,
  });
}

/// Processing/transcribing audio
class TranscriptionProcessing extends TranscriptionState {
  final String audioPath;
  
  const TranscriptionProcessing({
    required this.audioPath,
  });
}

/// Transcription completed successfully
class TranscriptionCompleted extends TranscriptionState {
  final String text;
  final String audioPath;
  final Duration processingTime;
  
  const TranscriptionCompleted({
    required this.text,
    required this.audioPath,
    required this.processingTime,
  });
}

/// Error state
class TranscriptionError extends TranscriptionState {
  final String message;
  final Exception? exception;
  
  const TranscriptionError({
    required this.message,
    this.exception,
  });
}

/// Model initialization state
@immutable
sealed class ModelState {
  const ModelState();
}

class ModelUninitialized extends ModelState {
  const ModelUninitialized();
}

class ModelInitializing extends ModelState {
  final String modelName;
  
  const ModelInitializing({
    required this.modelName,
  });
}

class ModelReady extends ModelState {
  final String modelName;
  
  const ModelReady({
    required this.modelName,
  });
}

class ModelError extends ModelState {
  final String message;
  
  const ModelError({
    required this.message,
  });
}
