import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart' as pid;
import 'package:pcm_stream_recorder/pcm_stream_recorder.dart';

/// Pitch Detector service for microphone input
///
/// Stage 3: Real pitch detection using YIN algorithm via pitch_detector_dart package
/// Uses pcm_stream_recorder for real-time PCM audio capture
/// Provides accurate frequency detection from microphone input for tuner functionality
class PitchDetector {
  PcmStreamRecorder? _recorder;
  pid.PitchDetector? _pitchDetectorDart;
  bool _isInitialized = false;
  bool _isListening = false;

  StreamSubscription<Uint8List>? _pcmSubscription;

  /// Callback for detected pitch (frequency in Hz)
  Function(double frequency)? onPitchDetected;

  /// Sample rate for audio recording
  static const int sampleRate = 44100;

  /// Buffer size for pitch detection (must be power of 2 for optimal performance)
  static const int bufferSize = 2048;

  /// Initialize the audio recorder and pitch detection algorithm
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    try {
      _recorder = PcmStreamRecorder();

      // Initialize the YIN pitch detection algorithm with named parameters
      _pitchDetectorDart = pid.PitchDetector(
        audioSampleRate: sampleRate * 1.0,
        bufferSize: bufferSize,
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing pitch detector: $e');
      rethrow;
    }
  }

  /// Request microphone permission
  ///
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        // Open app settings for user to manually grant permission
        await openAppSettings();
        return false;
      }

      return false;
    } catch (e) {
      debugPrint('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Start listening to microphone
  ///
  /// Stage 3: Real-time pitch detection enabled using YIN algorithm
  /// Calls onPitchDetected callback when pitch is detected
  Future<void> startListening() async {
    await _ensureInitialized();

    try {
      // Check permission first
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission not granted');
      }

      // Start recording with PCM stream
      final pcmStream = await _recorder!.start(sampleRate: sampleRate);

      // Listen to PCM data and detect pitch in real-time
      _pcmSubscription = pcmStream.listen((pcmChunk) async {
        if (!_isListening || _pitchDetectorDart == null) return;

        final frequency = await detectPitchFromBuffer(pcmChunk);

        if (frequency > 0 && onPitchDetected != null) {
          onPitchDetected!(frequency);
        }
      });

      _isListening = true;
      debugPrint('Pitch detector started (Stage 3: real detection mode)');
    } catch (e) {
      debugPrint('Error starting pitch detector: $e');
      rethrow;
    }
  }

  /// Stop listening to microphone
  Future<void> stopListening() async {
    try {
      _pcmSubscription?.cancel();
      _pcmSubscription = null;

      if (_recorder != null && _isListening) {
        await _recorder!.stop();
        _isListening = false;
        debugPrint('Pitch detector stopped');
      }
    } catch (e) {
      debugPrint('Error stopping pitch detector: $e');
    }
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Process audio buffer for pitch detection
  ///
  /// Stage 3: Uses YIN algorithm for accurate pitch detection
  ///
  /// [pcmData] - PCM16 audio data from microphone
  /// Returns detected frequency in Hz, or 0.0 if no pitch detected
  Future<double> detectPitchFromBuffer(Uint8List pcmData) async {
    final detector = _pitchDetectorDart;
    if (detector == null || pcmData.isEmpty) {
      return 0.0;
    }

    try {
      // Use YIN algorithm to detect pitch from PCM16 buffer (async)
      final result = await detector.getPitchFromIntBuffer(pcmData);

      // Return detected pitch if valid, otherwise 0.0
      if (result.pitched && result.pitch > 0) {
        return result.pitch;
      }

      return 0.0;
    } catch (e) {
      debugPrint('Error detecting pitch: $e');
      return 0.0;
    }
  }

  /// Process audio buffer for pitch detection (legacy method for compatibility)
  @Deprecated('Use detectPitchFromBuffer instead')
  Future<double> detectPitch(List<int> pcmData) {
    return detectPitchFromBuffer(Uint8List.fromList(pcmData));
  }

  /// Convert PCM bytes to double samples
  ///
  /// Used for debugging or alternative processing
  List<double> pcm16ToDouble(Uint8List pcmData) {
    final samples = <double>[];
    for (int i = 0; i < pcmData.length; i += 2) {
      if (i + 1 < pcmData.length) {
        final sample = (pcmData[i] | (pcmData[i + 1] << 8));
        samples.add(sample / 32768.0);
      }
    }
    return samples;
  }

  /// Get the pitch detector instance for advanced usage
  pid.PitchDetector? get detector => _pitchDetectorDart;

  /// Dispose of resources
  Future<void> dispose() async {
    try {
      await stopListening();
      if (_recorder != null) {
        await _recorder!.dispose();
        _recorder = null;
      }
      _pitchDetectorDart = null;
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error disposing pitch detector: $e');
    }
  }
}
