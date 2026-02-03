import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Service for audio recording with hardware-optimized settings
/// Configured for 16kHz PCM WAV format required by Whisper
class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get current recording path
  String? get currentRecordingPath => _currentRecordingPath;

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    
    if (status.isGranted) {
      debugPrint('[AudioService] Microphone permission granted');
      return true;
    } else if (status.isDenied) {
      debugPrint('[AudioService] Microphone permission denied');
      return false;
    } else if (status.isPermanentlyDenied) {
      debugPrint('[AudioService] Microphone permission permanently denied');
      // Guide user to app settings
      await openAppSettings();
      return false;
    }
    
    return false;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Start recording audio with Whisper-optimized settings
  /// Returns path where audio will be saved
  Future<String?> startRecording() async {
    // Check permission first
    if (!await hasPermission()) {
      debugPrint('[AudioService] No microphone permission');
      throw PermissionDeniedException('Microphone permission required');
    }

    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final directory = await getApplicationDocumentsDirectory();
      _currentRecordingPath = '${directory.path}/recording_$timestamp.wav';

      // Configure for Whisper requirements: 16kHz PCM WAV
      const config = RecordConfig(
        encoder: AudioEncoder.wav, // WAV container
        sampleRate: 16000, // 16kHz sample rate (Whisper requirement)
        bitRate: 256000, // 256 kbps
        numChannels: 1, // Mono audio
      );

      await _recorder.start(config, path: _currentRecordingPath!);
      _isRecording = true;
      
      debugPrint('[AudioService] Recording started: $_currentRecordingPath');
      return _currentRecordingPath;
    } catch (e) {
      debugPrint('[AudioService] Failed to start recording: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      rethrow;
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      debugPrint('[AudioService] Not currently recording');
      return null;
    }

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      
      if (path != null && await File(path).exists()) {
        final fileSize = await File(path).length();
        debugPrint('[AudioService] Recording stopped: $path (${fileSize ~/ 1024} KB)');
        
        // Verify file is not too small (corrupted)
        if (fileSize < 1024) {
          debugPrint('[AudioService] Warning: Recording file too small, may be corrupted');
        }
        
        return path;
      }
      
      debugPrint('[AudioService] Recording file not found');
      return null;
    } catch (e) {
      debugPrint('[AudioService] Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (_isRecording) {
      try {
        await _recorder.cancel();
        _isRecording = false;
        
        // Delete the file if it exists
        if (_currentRecordingPath != null) {
          final file = File(_currentRecordingPath!);
          if (await file.exists()) {
            await file.delete();
            debugPrint('[AudioService] Recording cancelled and deleted');
          }
        }
        
        _currentRecordingPath = null;
      } catch (e) {
        debugPrint('[AudioService] Failed to cancel recording: $e');
      }
    }
  }

  /// Check if device supports recording
  Future<bool> isEncoderSupported(AudioEncoder encoder) async {
    return await _recorder.isEncoderSupported(encoder);
  }

  /// Cleanup resources
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    _recorder.dispose();
  }

  /// Delete a recording file
  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[AudioService] Deleted recording: $path');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AudioService] Failed to delete recording: $e');
      return false;
    }
  }

  /// Get list of all recordings
  Future<List<String>> getAllRecordings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.wav'))
          .map((file) => file.path)
          .toList();
      
      debugPrint('[AudioService] Found ${files.length} recordings');
      return files;
    } catch (e) {
      debugPrint('[AudioService] Failed to list recordings: $e');
      return [];
    }
  }
}

/// Custom exception for permission denied
class PermissionDeniedException implements Exception {
  final String message;
  PermissionDeniedException(this.message);
  
  @override
  String toString() => 'PermissionDeniedException: $message';
}
