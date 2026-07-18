import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../services/audio/pcm_wav_recorder.dart';
import '../../../theme/mono_pulse_theme.dart';

/// Result of the recording sheet (#69): audio bytes + metadata for upload.
class LabRecordingResult {
  LabRecordingResult({
    required this.bytes,
    required this.ext,
    this.title,
    this.notes,
  });

  final Uint8List bytes;
  final String ext;
  final String? title;
  final String? notes;
}

/// Capture-or-attach sheet for Song Lab audio ideas (#69). Capture, don't
/// edit: record / pick a file, name it, add manual timestamp notes
/// ("00:42 good chorus entry"). Live amplitude bars while recording;
/// no playback waveform, no DAW — by design.
class LabRecordingSheet extends StatefulWidget {
  const LabRecordingSheet({this.autoStart = false, super.key});

  /// Start recording as soon as the sheet opens (Home "Audio note", #145) —
  /// silently ignored when the mic permission is denied or unavailable.
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
  StreamSubscription<Amplitude>? _ampSub;
  final List<double> _amps = [];
  Uint8List? _bytes;
  String _ext = 'm4a';
  String? _pickedName;
  PcmWavRecorder? _wavRecorder;

  /// Web records uncompressed WAV (~5.3MB/min mono); stop before the 25MB
  /// Storage cap. Native m4a has no practical cap in one memo.
  static const int _webMaxSeconds = 240;

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
    _ampSub?.cancel();
    if (_wavRecorder?.isRecording ?? false) {
      unawaited(_wavRecorder!.cancel());
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
      // concurrent stop would drain an already-emptied PCM buffer and
      // silently overwrite the recording with a headers-only WAV.
      if (_stopInFlight) return;
      _stopInFlight = true;
      _ticker?.cancel();
      await _ampSub?.cancel();
      _ampSub = null;
      final Uint8List? bytes;
      final String ext;
      if (kIsWeb) {
        bytes = await _wavRecorder?.stop();
        ext = 'wav';
      } else {
        final path = await _recorder.stop();
        bytes = path == null ? null : await File(path).readAsBytes();
        ext = 'm4a';
      }
      // 44 bytes = a WAV header with zero samples — not a recording.
      final hasAudio =
          bytes != null && bytes.isNotEmpty && !(ext == 'wav' && bytes.length <= 44);
      setState(() {
        if (hasAudio) {
          _bytes = bytes;
          _ext = ext;
          _pickedName = null;
        }
        _recording = false;
      });
      _stopInFlight = false;
      return;
    }
    if (!await _recorder.hasPermission()) return;
    if (kIsWeb) {
      // No filesystem on web: stream PCM16 (the tuner's proven capture path)
      // and wrap it into WAV on stop (#150).
      final recorder = _wavRecorder ??= PcmWavRecorder(_recorder);
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
    } else {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/lab_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((a) {
            if (!mounted) return;
            setState(() {
              _amps.add(a.current);
              if (_amps.length > _RecordingWavePainter.maxBars) {
                _amps.removeAt(0);
              }
            });
          });
    }
    _elapsed = 0;
    _amps.clear();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (kIsWeb && _recording && _elapsed >= _webMaxSeconds) {
        unawaited(_toggleRecord());
      }
    });
    setState(() {
      _recording = true;
      _bytes = null;
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
      return 'Recording… $m:$s';
    }
    if (_bytes != null) {
      final mb = (_bytes!.length / (1024 * 1024)).toStringAsFixed(1);
      return _pickedName != null
          ? '$_pickedName · ${mb}MB'
          : 'Recording ready · ${mb}MB';
    }
    return 'Record an idea or attach a file';
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
