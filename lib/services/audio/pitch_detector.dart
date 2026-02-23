import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// Pitch Detector service for microphone input
///
/// Stage 2: Stub implementation with simulated pitch detection
/// Stage 3: Will implement real pitch detection using FFT or YIN algorithm
class PitchDetector {
  FlutterSoundRecorder? _recorder;
  bool _isInitialized = false;
  bool _isListening = false;

  /// Sample rate for audio recording
  static const int sampleRate = 44100;

  /// Initialize the audio recorder
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    try {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
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
  /// Stage 2: This is a stub - actual pitch detection is simulated
  /// Stage 3: Will implement real-time pitch detection
  Future<void> startListening() async {
    await _ensureInitialized();

    try {
      // Check permission first
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission not granted');
      }

      // Start recorder (Stage 2: we don't actually process the audio)
      await _recorder!.startRecorder(
        toFile: null, // Don't save to file
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: sampleRate,
      );

      _isListening = true;
      debugPrint('Pitch detector started (Stage 2: simulated mode)');
    } catch (e) {
      debugPrint('Error starting pitch detector: $e');
      rethrow;
    }
  }

  /// Stop listening to microphone
  Future<void> stopListening() async {
    if (!_isInitialized || _recorder == null) return;

    try {
      if (_isListening) {
        await _recorder!.stopRecorder();
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
  /// Stage 2: Stub - returns simulated values
  /// Stage 3: Will implement real FFT-based pitch detection
  double detectPitch(List<int> pcmData) {
    // Stage 2: Return simulated frequency
    // This will be replaced with actual pitch detection in Stage 3
    return 440.0; // A4 reference
  }

  /// Calculate frequency from audio buffer using autocorrelation
  ///
  /// Stage 3: Will implement this properly
  double _autocorrelate(List<int> pcmData) {
    // Placeholder for Stage 3 implementation
    // This will use the YIN algorithm or similar for accurate pitch detection
    return 440.0;
  }

  /// Convert PCM bytes to double samples
  List<double> _pcm16ToDouble(List<int> pcmData) {
    final samples = <double>[];
    for (int i = 0; i < pcmData.length; i += 2) {
      if (i + 1 < pcmData.length) {
        final sample = (pcmData[i] | (pcmData[i + 1] << 8));
        samples.add(sample / 32768.0);
      }
    }
    return samples;
  }

  /// Dispose of resources
  Future<void> dispose() async {
    try {
      await stopListening();
      if (_recorder != null) {
        await _recorder!.closeRecorder();
        _recorder = null;
      }
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error disposing pitch detector: $e');
    }
  }
}

/// Stage 3: Real pitch detection helper class
///
/// This will be implemented in Stage 3 with proper FFT analysis
class PitchDetectionAlgorithm {
  /// YIN algorithm for pitch detection
  ///
  /// More accurate than simple autocorrelation
  static double yin(List<double> samples, int sampleRate) {
    // TODO: Implement YIN algorithm for Stage 3
    return 440.0;
  }

  /// FFT-based pitch detection
  ///
  /// Uses Fast Fourier Transform to find dominant frequency
  static double fft(List<double> samples, int sampleRate) {
    // TODO: Implement FFT-based detection for Stage 3
    return 440.0;
  }

  /// Convert frequency to MIDI note number
  static double frequencyToMidi(double frequency) {
    if (frequency <= 0) return 0;
    return 69 + 12 * (log(frequency / 440.0) / ln2);
  }

  /// Convert MIDI note number to frequency
  static double midiToFrequency(double midi) {
    return 440.0 * pow(2.0, (midi - 69) / 12.0);
  }

  // Helper math functions
  static double log(double x) => _log(x);
  static double ln2 = 0.6931471805599453;
  static double _log(double x) => log2(x) * ln2;
  static double log2(double x) => _log2(x);
  static double _log2(double x) => log(x) / ln2;
  static double pow(double base, double exp) => _pow(base, exp);
  static double _pow(double base, double exp) => exp == 0
      ? 1.0
      : exp == 1
      ? base
      : base * _pow(base, exp - 1);
}
