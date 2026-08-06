import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../services/audio/audio_note_edit.dart';
import '../../../services/audio/audio_note_recorder.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../utils/snackbar.dart';

enum _RecordingPermissionState {
  granted,
  denied,
  permanentlyDenied,
  unavailable,
}

/// Result of the recording sheet (#69): audio bytes + metadata for upload.
class LabRecordingResult {
  LabRecordingResult({
    required this.bytes,
    required this.ext,
    this.title,
    this.notes,
    this.peaks = const [],
  });

  final Uint8List bytes;
  final String ext;
  final String? title;
  final String? notes;

  /// Waveform bars for the audio note editor. Empty for attached files, whose
  /// levels we never saw.
  final List<int> peaks;
}

/// Capture-or-attach sheet for Song Lab audio ideas (#69). Capture, don't
/// edit: record / pick a file, name it, add manual timestamp notes
/// ("00:42 good chorus entry"). Live amplitude bars while recording;
/// no playback waveform, no DAW — by design.
class LabRecordingSheet extends StatefulWidget {
  const LabRecordingSheet({this.autoStart = false, super.key});

  /// Start recording as soon as the sheet opens (Home "Audio note", #145).
  final bool autoStart;

  @override
  State<LabRecordingSheet> createState() => _LabRecordingSheetState();
}

class _LabRecordingSheetState extends State<LabRecordingSheet> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _recorder = AudioRecorder();

  bool _recording = false;
  int _elapsed = 0;
  Timer? _ticker;
  final List<double> _amps = [];
  Uint8List? _bytes;
  String _ext = AudioNoteRecorder.extension;
  String? _pickedName;
  List<int> _peaks = const [];
  AudioNoteRecorder? _noteRecorder;

  /// Stop before the 25MB Storage cap. Native records AAC (~16kB/s, so ~26 min
  /// fits); web is stuck with uncompressed WAV at ~88kB/s, hence the gulf.
  static const int _maxSeconds = kIsWeb ? 240 : 1500;

  bool get _isSecureWebContext {
    if (!kIsWeb) return true;
    final uri = Uri.base;
    return uri.scheme == 'https' ||
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '::1';
  }

  bool get _canOpenPermissionSettings =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<_RecordingPermissionState> _permissionStatus() async {
    if (!_isSecureWebContext) return _RecordingPermissionState.unavailable;
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted || status.isLimited) {
        return _RecordingPermissionState.granted;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        return _RecordingPermissionState.permanentlyDenied;
      }
      return _RecordingPermissionState.denied;
    } catch (_) {
      try {
        final granted = await _recorder.hasPermission(request: false);
        return granted
            ? _RecordingPermissionState.granted
            : _RecordingPermissionState.denied;
      } catch (_) {
        return _RecordingPermissionState.unavailable;
      }
    }
  }

  Future<_RecordingPermissionState> _requestPermission() async {
    if (!_isSecureWebContext) return _RecordingPermissionState.unavailable;
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted || status.isLimited) {
        return _RecordingPermissionState.granted;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        return _RecordingPermissionState.permanentlyDenied;
      }
      return _RecordingPermissionState.denied;
    } catch (_) {
      try {
        final granted = await _recorder.hasPermission();
        return granted
            ? _RecordingPermissionState.granted
            : _RecordingPermissionState.denied;
      } catch (_) {
        return _RecordingPermissionState.unavailable;
      }
    }
  }

  Future<void> _openPermissionSettings() => openAppSettings();

  Future<bool> _ensureMicrophonePermission() async {
    if (!_isSecureWebContext) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Recording needs a secure (https) connection.',
          error: true,
        );
      }
      return false;
    }

    var permission = await _permissionStatus();
    if (permission != _RecordingPermissionState.granted &&
        permission != _RecordingPermissionState.permanentlyDenied &&
        permission != _RecordingPermissionState.unavailable) {
      permission = await _requestPermission();
    }
    if (permission == _RecordingPermissionState.granted) return true;
    if (!mounted) return false;

    switch (permission) {
      case _RecordingPermissionState.permanentlyDenied:
        showAppSnackBar(
          context,
          'Microphone access is blocked. Allow it in device settings to record.',
          error: true,
          actionLabel: _canOpenPermissionSettings ? 'Open settings' : null,
          onAction: _canOpenPermissionSettings
              ? () => unawaited(_openPermissionSettings())
              : null,
        );
      case _RecordingPermissionState.denied:
        showAppSnackBar(
          context,
          'Allow microphone access to record an audio idea.',
          error: true,
        );
      case _RecordingPermissionState.unavailable:
        showAppSnackBar(
          context,
          'Microphone recording is unavailable on this device.',
          error: true,
        );
      case _RecordingPermissionState.granted:
        break;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startGuarded());
      });
    }
  }

  Future<void> _startGuarded() async {
    try {
      await _toggleRecord();
    } catch (_) {
      // No recorder plugin (tests) or denied mic: the sheet just opens idle.
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_noteRecorder?.isRecording ?? false) {
      unawaited(_noteRecorder!.cancel());
    }
    _recorder.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool _stopInFlight = false;

  Future<void> _toggleRecord() async {
    if (_recording) {
      // Double-tap on Stop or the auto-cap timer racing a tap: a second
      // concurrent stop would drain an already-emptied buffer and silently
      // overwrite the recording with an empty one.
      if (_stopInFlight) return;
      _stopInFlight = true;
      _ticker?.cancel();
      final levels = _noteRecorder?.levels ?? const <double>[];
      final bytes = await _noteRecorder?.stop();
      // Anything that won't parse as audio (a header-only WAV, an empty AAC
      // stream) isn't a recording and must not overwrite a good take.
      final hasAudio = bytes != null && audioDurationMs(bytes) != null;
      setState(() {
        if (hasAudio) {
          _bytes = bytes;
          _ext = AudioNoteRecorder.extension;
          _peaks = peaksFromLevels(levels);
          _pickedName = null;
        }
        _recording = false;
      });
      _stopInFlight = false;
      return;
    }
    if (!await _ensureMicrophonePermission()) return;
    // Streamed capture in a sliceable format (AAC on native, WAV on web), so
    // the editor can trim a take without an ffmpeg-sized dependency (#150).
    final recorder = _noteRecorder ??= AudioNoteRecorder(_recorder);
    recorder.onLevel = (dbfs) {
      if (!mounted) return;
      setState(() {
        _amps.add(dbfs);
        if (_amps.length > _RecordingWavePainter.maxBars) {
          _amps.removeAt(0);
        }
      });
    };
    await recorder.start();
    _elapsed = 0;
    _amps.clear();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_recording && _elapsed >= _maxSeconds) {
        unawaited(_toggleRecord());
      }
    });
    setState(() {
      _recording = true;
      _bytes = null;
      _peaks = const [];
    });
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(type: FileType.audio);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _bytes = bytes;
      _ext = (file.extension ?? 'm4a').toLowerCase();
      _pickedName = file.name;
      // We never saw this file's levels; the editor falls back to a plain
      // seek bar. ponytail: compute peaks from the bytes if it ever matters.
      _peaks = const [];
      _recording = false;
    });
    if (_title.text.isEmpty && file.name.isNotEmpty) {
      _title.text = file.name.replaceAll(RegExp(r'\.\w+$'), '');
    }
  }

  String get _statusLine {
    if (_recording) {
      final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
      final s = (_elapsed % 60).toString().padLeft(2, '0');
      // Warn before the cap stops the take out from under them, not after.
      final left = _maxSeconds - _elapsed;
      final warning = left <= 60 ? ' · ${left}s left' : '';
      return 'Recording… $m:$s$warning';
    }
    if (_bytes != null) {
      final mb = (_bytes!.length / (1024 * 1024)).toStringAsFixed(1);
      return _pickedName != null
          ? '$_pickedName · ${mb}MB'
          : 'Recording ready · ${mb}MB';
    }
    const limit = _maxSeconds ~/ 60;
    return 'Record an idea (up to $limit min) or attach a file';
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _bytes != null && !_recording;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audio idea', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _statusLine,
              style: MonoPulseTypography.bodySmall.copyWith(
                color: _recording
                    ? MonoPulseColors.accentOrange
                    : context.mp.textSecondary,
              ),
            ),
            if (_recording) ...[
              const SizedBox(height: MonoPulseSpacing.sm),
              CustomPaint(
                size: const Size(double.infinity, 36),
                painter: _RecordingWavePainter(List.of(_amps)),
              ),
            ],
            const SizedBox(height: MonoPulseSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _toggleRecord,
                    icon: Icon(_recording ? Icons.stop : Icons.mic),
                    label: Text(_recording ? 'Stop' : 'Record'),
                  ),
                ),
                const SizedBox(width: MonoPulseSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _recording ? null : _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Attach file'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title (e.g. "Bridge riff idea")',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Timestamp notes (optional)',
                hintText: '00:42 good chorus entry\n01:15 tempo drops',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: MonoPulseSpacing.sm),
                ElevatedButton(
                  onPressed: canSave
                      ? () => Navigator.pop(
                          context,
                          LabRecordingResult(
                            bytes: _bytes!,
                            ext: _ext,
                            title: _title.text.trim().isEmpty
                                ? null
                                : _title.text.trim(),
                            notes: _notes.text.trim().isEmpty
                                ? null
                                : _notes.text.trim(),
                            peaks: _peaks,
                          ),
                        )
                      : null,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Rolling live-amplitude bars shown while recording. Input is dBFS from
/// `record`'s amplitude stream (~-160..0); mapped linearly from a -60dB
/// floor so speech/instrument levels use most of the bar height.
class _RecordingWavePainter extends CustomPainter {
  _RecordingWavePainter(this.amps);

  static const maxBars = 48;
  final List<double> amps;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MonoPulseColors.accentOrange
      ..strokeWidth = size.width / maxBars * 0.6
      ..strokeCap = StrokeCap.round;
    final step = size.width / maxBars;
    final mid = size.height / 2;
    for (var i = 0; i < amps.length; i++) {
      final norm = ((amps[i] + 60) / 60).clamp(0.05, 1.0);
      final h = norm * size.height / 2;
      final x = (maxBars - amps.length + i) * step + step / 2;
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), paint);
    }
  }

  @override
  bool shouldRepaint(_RecordingWavePainter oldDelegate) =>
      oldDelegate.amps != amps;
}

/// Minimal play/pause for a recording entry — capture, don't edit (#69).
class LabAudioPlayer extends StatefulWidget {
  const LabAudioPlayer({required this.url, super.key});

  final String url;

  @override
  State<LabAudioPlayer> createState() => _LabAudioPlayerState();
}

class _LabAudioPlayerState extends State<LabAudioPlayer> {
  final _player = AudioPlayer();
  bool _loaded = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (!_loaded) {
      await _player.setUrl(widget.url);
      _loaded = true;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    unawaited(_player.play());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        final done =
            snapshot.data?.processingState == ProcessingState.completed;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                playing && !done ? Icons.pause_circle : Icons.play_circle,
                color: MonoPulseColors.accentOrange,
              ),
              onPressed: _toggle,
            ),
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, pos) {
                final p = pos.data ?? Duration.zero;
                final total = _player.duration ?? Duration.zero;
                String f(Duration d) =>
                    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
                return Text(
                  _loaded ? '${f(p)} / ${f(total)}' : 'Play',
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: context.mp.textSecondary,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
