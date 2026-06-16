import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'pitch_analysis.dart';

enum TunerPermissionState {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
  unavailable,
}

class PitchSample {

  const PitchSample({
    required this.signalState,
    required this.frequencyHz,
    required this.confidence,
    required this.rmsDb,
  });
  final TunerSignalState signalState;
  final double? frequencyHz;
  final double confidence;
  final double rmsDb;
}

abstract class AudioInput {
  int get sampleRate;
  bool get isRecording;

  Future<TunerPermissionState> permissionStatus();
  Future<TunerPermissionState> requestPermission();
  Future<Stream<Uint8List>> start();
  Future<void> stop();
  Future<void> dispose();
}

class RecordAudioInput implements AudioInput {

  RecordAudioInput({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();
  final AudioRecorder _recorder;
  int _sampleRate = 44100;
  bool _isRecording = false;

  @override
  int get sampleRate => _sampleRate;

  @override
  bool get isRecording => _isRecording;

  bool get _isSecureWebContext {
    if (!kIsWeb) return true;
    final uri = Uri.base;
    return uri.scheme == 'https' ||
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '::1';
  }

  @override
  Future<TunerPermissionState> permissionStatus() async {
    if (!_isSecureWebContext) return TunerPermissionState.unavailable;
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted || status.isLimited) {
        return TunerPermissionState.granted;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        return TunerPermissionState.permanentlyDenied;
      }
      return TunerPermissionState.denied;
    } catch (_) {
      try {
        final granted = await _recorder.hasPermission(request: false);
        return granted
            ? TunerPermissionState.granted
            : TunerPermissionState.denied;
      } catch (_) {
        return TunerPermissionState.unavailable;
      }
    }
  }

  @override
  Future<TunerPermissionState> requestPermission() async {
    if (!_isSecureWebContext) return TunerPermissionState.unavailable;
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted || status.isLimited) {
        return TunerPermissionState.granted;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        return TunerPermissionState.permanentlyDenied;
      }
      return TunerPermissionState.denied;
    } catch (_) {
      try {
        final granted = await _recorder.hasPermission();
        return granted
            ? TunerPermissionState.granted
            : TunerPermissionState.denied;
      } catch (_) {
        return TunerPermissionState.unavailable;
      }
    }
  }

  @override
  Future<Stream<Uint8List>> start() async {
    if (_isRecording) {
      throw StateError('Microphone capture is already active');
    }
    if (!await _recorder.isEncoderSupported(AudioEncoder.pcm16bits)) {
      throw UnsupportedError('PCM16 microphone streaming is unavailable');
    }

    _sampleRate = 44100;
    await _recorder.setOnConfigChanged((config) {
      _sampleRate = config.sampleRate;
    });
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        streamBufferSize: 4096,
      ),
    );
    _isRecording = true;
    return stream;
  }

  @override
  Future<void> stop() async {
    if (!_isRecording) return;
    _isRecording = false;
    await _recorder.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}

/// Cross-platform microphone pitch detector with serialized frame analysis.
class PitchDetector {

  PitchDetector({this._audioInput});
  static const int bufferSize = 4096;
  static const int hopSize = 1024;

  AudioInput? _audioInput;
  final List<int> _pendingBytes = <int>[];
  final List<double> _recentFrequencies = <double>[];

  StreamSubscription<Uint8List>? _subscription;
  Uint8List? _latestFrame;
  bool _analysisRunning = false;
  bool _isListening = false;
  bool _disposed = false;
  double _noiseFloorDb = -55;
  DateTime? _signalStartedAt;
  DateTime _lastEmission = DateTime.fromMillisecondsSinceEpoch(0);

  AudioInput get _input => _audioInput ??= RecordAudioInput();

  void Function(double frequency)? onPitchDetected;
  ValueChanged<PitchSample>? onSample;

  bool get isListening => _isListening;
  int get sampleRate => _input.sampleRate;

  void setSensitivity(double sensitivity) {
    final normalized = sensitivity.clamp(0.0, 100.0) / 100;
    _noiseFloorDb = -40 - (30 * normalized);
  }

  Future<TunerPermissionState> permissionStatus() {
    return _input.permissionStatus();
  }

  Future<TunerPermissionState> requestPermission() {
    return _input.requestPermission();
  }

  Future<void> openPermissionSettings() => openAppSettings();

  Future<void> startListening() async {
    if (_disposed) throw StateError('PitchDetector has been disposed');
    if (_isListening) return;

    final permission = await _input.permissionStatus();
    if (permission != TunerPermissionState.granted) {
      throw StateError('Microphone permission is not granted');
    }

    _resetPipeline();
    _isListening = true;
    try {
      final stream = await _input.start();
      _subscription = stream.listen(
        _handleChunk,
        onError: (Object error, StackTrace stackTrace) {
          _emit(
            const PitchSample(
              signalState: TunerSignalState.unstable,
              frequencyHz: null,
              confidence: 0,
              rmsDb: -120,
            ),
            force: true,
          );
        },
        onDone: () => _isListening = false,
        cancelOnError: false,
      );
    } catch (_) {
      _isListening = false;
      rethrow;
    }
  }

  void _handleChunk(Uint8List bytes) {
    if (!_isListening || bytes.isEmpty) return;
    _pendingBytes.addAll(bytes);
    if (_pendingBytes.length.isOdd) return;

    const frameBytes = bufferSize * 2;
    const hopBytes = hopSize * 2;
    while (_pendingBytes.length >= frameBytes) {
      _latestFrame = Uint8List.fromList(_pendingBytes.sublist(0, frameBytes));
      _pendingBytes.removeRange(0, hopBytes);
    }
    _scheduleLatestFrame();
  }

  void _scheduleLatestFrame() {
    if (_analysisRunning || _latestFrame == null || !_isListening) return;
    final frame = _latestFrame!;
    _latestFrame = null;
    _analysisRunning = true;
    _analyse(frame).whenComplete(() {
      _analysisRunning = false;
      if (_latestFrame != null) _scheduleLatestFrame();
    });
  }

  Future<void> _analyse(Uint8List frame) async {
    final map = await compute(analysePitchFrame, <String, Object?>{
      'bytes': frame,
      'sampleRate': sampleRate,
      'noiseFloorDb': _noiseFloorDb,
      'minFrequency': 35.0,
      'maxFrequency': 2100.0,
    });
    if (!_isListening) return;

    final analysis = PitchAnalysisResult.fromMap(map);
    if (!analysis.hasPitch || analysis.confidence < 0.65) {
      _signalStartedAt = null;
      _recentFrequencies.clear();
      _emit(
        PitchSample(
          signalState: analysis.rmsDb < _noiseFloorDb
              ? TunerSignalState.noSignal
              : TunerSignalState.unstable,
          frequencyHz: null,
          confidence: analysis.confidence,
          rmsDb: analysis.rmsDb,
        ),
      );
      return;
    }

    final now = DateTime.now();
    _signalStartedAt ??= now;
    if (now.difference(_signalStartedAt!) < const Duration(milliseconds: 120)) {
      _emit(
        PitchSample(
          signalState: TunerSignalState.unstable,
          frequencyHz: null,
          confidence: analysis.confidence,
          rmsDb: analysis.rmsDb,
        ),
      );
      return;
    }

    _recentFrequencies.add(analysis.frequencyHz!);
    if (_recentFrequencies.length > 5) _recentFrequencies.removeAt(0);
    final sorted = [..._recentFrequencies]..sort();
    final frequency = sorted[sorted.length ~/ 2];
    final sample = PitchSample(
      signalState: analysis.confidence >= 0.8
          ? TunerSignalState.detected
          : TunerSignalState.unstable,
      frequencyHz: frequency,
      confidence: analysis.confidence,
      rmsDb: analysis.rmsDb,
    );
    _emit(sample);
    if (sample.signalState == TunerSignalState.detected) {
      onPitchDetected?.call(frequency);
    }
  }

  void _emit(PitchSample sample, {bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastEmission) < const Duration(milliseconds: 33)) {
      return;
    }
    _lastEmission = now;
    onSample?.call(sample);
  }

  Future<double> detectPitchFromBuffer(Uint8List pcmData) async {
    if (pcmData.isEmpty) return 0;
    final result = PitchAnalysisResult.fromMap(
      analysePitchFrame(<String, Object?>{
        'bytes': pcmData,
        'sampleRate': sampleRate,
        'noiseFloorDb': -100.0,
        'minFrequency': 35.0,
        'maxFrequency': 2100.0,
      }),
    );
    return result.frequencyHz ?? 0;
  }

  @Deprecated('Use detectPitchFromBuffer instead')
  Future<double> detectPitch(List<int> pcmData) {
    return detectPitchFromBuffer(Uint8List.fromList(pcmData));
  }

  List<double> pcm16ToDouble(Uint8List pcmData) {
    final result = <double>[];
    final data = ByteData.sublistView(pcmData);
    for (var offset = 0; offset + 1 < pcmData.length; offset += 2) {
      result.add(data.getInt16(offset, Endian.little) / 32768.0);
    }
    return result;
  }

  Future<void> stopListening() async {
    final input = _audioInput;
    if (!_isListening && (input == null || !input.isRecording)) return;
    _isListening = false;
    await _subscription?.cancel();
    _subscription = null;
    await input?.stop();
    _resetPipeline();
  }

  void _resetPipeline() {
    _pendingBytes.clear();
    _latestFrame = null;
    _recentFrequencies.clear();
    _signalStartedAt = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopListening();
    await _audioInput?.dispose();
    _audioInput = null;
  }
}
