import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/audio_region.dart';
import '../models/metronome_session.dart';
import '../models/midi_pattern.dart';
import '../models/section.dart';
import '../models/section_span.dart';
import '../models/song_lab.dart';
import '../models/time_signature.dart';
import '../providers/data/backing_transport_provider.dart';
import '../providers/data/data_providers.dart';
import '../providers/data/metronome_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/practice_stats_provider.dart';
import '../repositories/metronome_session_repository.dart';
import '../services/audio/audio_analysis.dart';
import '../services/audio/audio_markers.dart';
import '../services/audio/audio_note_edit.dart';
import '../services/audio/song_peaks.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/play_mode.dart';
import '../utils/snackbar.dart';
import '../widgets/audio/waveform_painter.dart';
import 'practice_setup_wizard.dart';

Future<String?> _defaultCacheAudioFile(Uint8List bytes, String name) async {
  final file = File('${(await getTemporaryDirectory()).path}/$name');
  if (!await file.exists() || await file.length() != bytes.length) {
    await file.writeAsBytes(bytes, flush: true);
  }
  return file.path;
}

/// Named regions keep practice loops attached to the original recording.
class PracticeRegionsScreen extends ConsumerStatefulWidget {
  const PracticeRegionsScreen({
    required this.entry,
    this.bandId,
    @visibleForTesting this.player,
    super.key,
  });

  final SongLabEntry entry;
  final String? bandId;

  /// Loops played for less than this are taps and previews, not practice,
  /// and stay out of the practice log.
  @visibleForTesting
  static int minLoggedMs = 10000;

  @visibleForTesting
  static bool autoOpenSetup = true;

  /// Decoder for fine-tuning and click & drums mode; tests swap it, since SoLoud's native
  /// decoder isn't loaded there.
  @visibleForTesting
  static Future<Int16List?> Function(
    Uint8List bytes, {
    required int sampleRate,
    required int durationMs,
  })
  decodePcm = decodeSongPcm;

  @visibleForTesting
  static Future<String?> Function(Uint8List bytes, String name) cacheAudioFile =
      _defaultCacheAudioFile;

  /// Allows widget tests to supply a player without native audio.
  final AudioPlayer? player;

  @override
  ConsumerState<PracticeRegionsScreen> createState() =>
      _PracticeRegionsScreenState();
}

class _PracticeRegionsScreenState extends ConsumerState<PracticeRegionsScreen> {
  late SongLabEntry _entry;
  late final AudioPlayer _player;
  final _subs = <StreamSubscription<dynamic>>[];
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _loaded = false;
  bool _editing = false;
  bool _setupOpen = false;
  int? _heldPad;
  late bool _snap;
  double _speed = 1;
  int _preRoll = 0;
  (int, int)? _selection;
  int _clipStart = 0;
  int? _clipEnd;
  bool _changingClip = false;
  Future<void> _loopUpdate = Future<void>.value();
  int _idCounter = 0;
  double _dragMs = 0;
  List<AudioRegion>? _beforeDrag;
  Int16List? _pcm;
  Future<void>? _pcmLoad;
  Int16List? _analysisPcm;
  Future<Int16List?>? _analysisPcmLoad;
  Future<Uint8List>? _bytes;
  Timer? _auditionTimer;

  /// Seam loop (fine-tune): clip-relative (head, tail); past the head of
  /// each pass playback jumps to the tail, so only the join repeats.
  (int, int)? _seam;
  static const _seamMs = 1500;

  /// One level of undo for Shift edits (they save immediately).
  List<AudioRegion>? _undoRegions;

  // Practice log: one session per loop selection, written when it changes or
  // the screen closes. Captured in initState because ref is gone by dispose.
  late final MetronomeSessionRepository _sessions;
  late final bool _logSessions;
  DateTime? _sessionStart;
  DateTime? _playingSince;
  int _playedMs = 0;
  int _reps = 0;
  int _lastPosMs = 0;

  // Click & drums mode: the song plays as a backing stem inside the click
  // engine (sample-locked, 100% speed) instead of through just_audio.
  bool _sync = false;
  bool _preparingSync = false;
  late final MetronomeNotifier _metronome;

  int get _durationMs => _duration.inMilliseconds;
  int get _positionMs => _clipStart + _position.inMilliseconds;
  int get _preRollMs => _entry.grid == null
      ? _preRoll * 1000
      : (_preRoll * _entry.grid!.barMs).round();

  bool get _canEdit =>
      !ref.read(isDemoUserProvider) &&
      (widget.bandId == null || ref.read(canEditBandProvider(widget.bandId!)));

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _snap = _entry.grid != null;
    _player = widget.player ?? AudioPlayer();
    _sessions = ref.read(metronomeSessionRepositoryProvider);
    _logSessions = !ref.read(isDemoUserProvider);
    _metronome = ref.read(metronomeProvider.notifier);
    unawaited(_load());
    unawaited(_backfillPeaks());
  }

  /// Imported song files arrive without peaks; decode once so regions can be
  /// marked against the waveform. Saved for editors, shown locally for
  /// everyone else. Silent on failure — the plain strip still works.
  Future<void> _backfillPeaks() async {
    if (_entry.peaks.isNotEmpty || _entry.attachmentIds.isEmpty) return;
    try {
      final bytes = await (_bytes ??= ref.read(audioBytesFetcherProvider)(
        _entry.attachmentIds.first,
      ));
      final peaks = await decodeSongPeaks(bytes);
      if (peaks == null || !mounted || _entry.peaks.isNotEmpty) return;
      final updated = _entry.copyWith(peaks: peaks);
      if (_canEdit) {
        await _save(updated);
      } else {
        setState(() => _entry = updated);
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_entry.attachmentIds.isEmpty) return;
    try {
      final url = _entry.attachmentIds.first;
      String? path;
      if (!kIsWeb) {
        try {
          final bytes = await (_bytes ??= ref.read(audioBytesFetcherProvider)(
            url,
          ));
          final parts = Uri.parse(url).path.split('/').last.split('.');
          final ext = parts.length > 1 && parts.last.isNotEmpty
              ? parts.last
              : 'mp3';
          path = await PracticeRegionsScreen.cacheAudioFile(
            bytes,
            'practice_${_entry.id}.$ext',
          );
        } catch (_) {}
      }
      final duration = path == null
          ? await _player.setUrl(url)
          : await _player.setFilePath(path);
      if (!mounted) return;
      setState(() {
        _duration = duration ?? Duration.zero;
        _loaded = true;
      });
      _subs.addAll([
        _player.durationStream.listen((duration) {
          // Clipping reports the loop's duration, not the whole recording.
          if (!mounted ||
              duration == null ||
              _changingClip ||
              _clipEnd != null) {
            return;
          }
          setState(() => _duration = duration);
        }),
        _player.positionStream.listen((position) {
          if (!mounted) return;
          // A looping clip jumps back to its start: count the pass.
          final ms = position.inMilliseconds;
          if (_playing && _clipEnd != null && ms + 1000 < _lastPosMs) _reps++;
          _lastPosMs = ms;
          final seam = _seam;
          if (seam != null && !_changingClip && ms > seam.$1 && ms < seam.$2) {
            unawaited(_player.seek(Duration(milliseconds: seam.$2)));
          }
          setState(() => _position = position);
        }),
        _player.playerStateStream.listen((state) {
          if (!mounted) return;
          if (!_sync) _clock(state.playing);
          setState(() => _playing = state.playing);
        }),
      ]);
      await _applyLoop();
      if (mounted &&
          PracticeRegionsScreen.autoOpenSetup &&
          _entry.regions.isEmpty &&
          _canEdit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_rerunSetup());
        });
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, "Couldn't load audio: $e", error: true);
      }
    }
  }

  void _clock(bool playing) {
    if (playing) {
      _playingSince ??= DateTime.now();
      _sessionStart ??= _playingSince;
    } else {
      _stopClock();
    }
  }

  void _stopClock() {
    final since = _playingSince;
    if (since == null) return;
    _playedMs += DateTime.now().difference(since).inMilliseconds;
    _playingSince = null;
  }

  String? _loopLabel() {
    final selection = _selection;
    if (selection == null) return null;
    final (a, b) = selection;
    final regions = _entry.regions;
    return a == b
        ? _name(regions[a])
        : '${_name(regions[a])} → ${_name(regions[b])}';
  }

  /// Writes the current loop's practice to the log and starts a fresh one.
  void _flushSession() {
    _stopClock();
    final start = _sessionStart;
    if (_logSessions &&
        start != null &&
        _playedMs >= PracticeRegionsScreen.minLoggedMs) {
      final songId = _entry.songId;
      unawaited(
        _sessions
            .save(
              MetronomeSession(
                id: 'regions_${DateTime.now().microsecondsSinceEpoch}',
                startedAt: start,
                endedAt: DateTime.now(),
                startBpm: _entry.grid?.bpm.round() ?? 0,
                songId: songId.isEmpty || songId == '_inbox' ? null : songId,
                elapsedSeconds: _playedMs ~/ 1000,
                regionName: _loopLabel() ?? 'Whole song',
                loopReps: _reps,
              ),
            )
            .catchError((Object _) {}),
      );
    }
    _playedMs = 0;
    _reps = 0;
    _lastPosMs = 0;
    _sessionStart = null;
    if (_playing) _playingSince = _sessionStart = DateTime.now();
  }

  @override
  void dispose() {
    _auditionTimer?.cancel();
    _flushSession();
    if (_sync) _metronome.stop();
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _save(SongLabEntry updated) async {
    if (!mounted || !_canEdit) return;
    setState(() => _entry = updated);
    try {
      await ref
          .read(labRepositoryProvider)
          .saveEntry(updated, bandId: widget.bandId);
    } catch (e) {
      if (mounted) showAppSnackBar(context, "Couldn't save: $e", error: true);
    }
  }

  int _snapped(int ms) => _snap && _entry.grid != null
      ? _entry.grid!.snap(ms, durationMs: _durationMs)
      : ms.clamp(0, _durationMs);

  void _clampSelection() {
    final selection = _selection;
    if (selection == null) return;
    if (_entry.regions.isEmpty || selection.$1 >= _entry.regions.length) {
      _selection = null;
    } else {
      _selection = (
        selection.$1,
        selection.$2.clamp(0, _entry.regions.length - 1),
      );
    }
  }

  Future<void> _changeRegions(
    List<AudioRegion> regions, {
    List<AudioRegion>? undoTo,
  }) async {
    if (!_canEdit) return;
    setState(() {
      _undoRegions = undoTo ?? _entry.regions;
      _selection = remapSelection(_entry.regions, regions, _selection);
      _entry = _entry.copyWith(regions: regions);
      _clampSelection();
    });
    final loop = _applyLoop();
    if (_sync) _syncLaunch(startIfStopped: false);
    await _save(_entry);
    await loop;
  }

  /// Serialise clip reloads so fast taps cannot leave an older loop active.
  Future<void> _applyLoop() => _loopUpdate = _loopUpdate.then((_) async {
    if (!mounted || !_loaded) return;
    final selection = _selection;
    if (selection == null && _clipEnd == null) return;
    final span = selection == null
        ? null
        : loopSpan(_entry.regions, selection, preRollMs: _preRollMs);
    // Renames and edits outside the loop must not restart playback mid-pass.
    if (span != null && span.$1 == _clipStart && span.$2 == _clipEnd) return;
    final wasPlaying = _player.playing;
    // Leaving a loop keeps playing from where the loop was, not the top.
    final resume = Duration(milliseconds: _positionMs);
    _changingClip = true;
    try {
      if (wasPlaying) await _player.pause();
      if (!mounted) return;
      if (selection == null) {
        await _player.setClip();
        if (!mounted) return;
        await _player.setLoopMode(LoopMode.off);
        if (!mounted) return;
        setState(() {
          _clipStart = 0;
          _clipEnd = null;
          _position = resume;
        });
      } else {
        final (start, end) = span!;
        setState(() {
          _clipStart = start;
          _clipEnd = end;
          _position = Duration.zero;
          _lastPosMs = 0;
        });
        await _player.setClip(
          start: Duration(milliseconds: start),
          end: Duration(milliseconds: end),
        );
        if (!mounted) return;
        await _player.setLoopMode(LoopMode.one);
        if (!mounted) return;
      }
      await _player.seek(selection == null ? resume : Duration.zero);
      if (mounted && wasPlaying) unawaited(_player.play());
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, "Couldn't set loop: $e", error: true);
      }
    } finally {
      _changingClip = false;
    }
  });

  Future<void> _seekTo(int ms) => _player.seek(
    Duration(
      milliseconds: (ms - _clipStart).clamp(
        0,
        (_clipEnd ?? _durationMs) - _clipStart,
      ),
    ),
  );

  Future<void> _seekTimeline(int ms) async {
    if (_clipEnd != null && (ms < _clipStart || ms >= _clipEnd!)) {
      _flushSession();
      setState(() => _selection = null);
      await _applyLoop();
      if (!mounted) return;
      if (_sync) _syncLaunch(startIfStopped: false);
    }
    await _seekTo(ms);
  }

  void _selectRegions((int, int)? selection) {
    _flushSession();
    setState(() => _selection = selection);
    if (_sync) _syncLaunch(startIfStopped: false);
    unawaited(_applyLoop());
  }

  // --- click & drums ----------------------------------------------------

  /// Launchable spans: each region, the whole song, and the selected run.
  List<SectionSpan> _syncSpans() {
    final grid = _entry.grid!;
    final spans = regionSpans(_entry.regions, grid);
    final songBars = grid.barAt(_durationMs).ceil();
    final selection = _selection;
    return [
      ...spans,
      if (songBars > 0)
        SectionSpan(sectionId: 'song', startBar: 0, bars: songBars),
      if (selection != null && selection.$1 != selection.$2)
        SectionSpan(
          sectionId: 'run',
          startBar: grid.barAt(_entry.regions[selection.$1].startMs).round(),
          bars:
              grid.barAt(_entry.regions[selection.$2].endMs).round() -
              grid.barAt(_entry.regions[selection.$1].startMs).round(),
        ),
    ];
  }

  String get _syncTarget {
    final selection = _selection;
    if (selection == null) return 'song';
    return selection.$1 == selection.$2
        ? _entry.regions[selection.$1].id
        : 'run';
  }

  /// Points the transport at the current selection; a running loop switches
  /// on the next bar line.
  void _syncLaunch({bool startIfStopped = true}) {
    final transport = ref.read(backingTransportProvider.notifier)
      ..setSpans(_syncSpans())
      ..setMode(PlayMode.loop);
    if (ref.read(metronomeProvider).isPlaying || startIfStopped) {
      unawaited(transport.launch(_syncTarget));
    }
  }

  Future<void> _setSync(bool on) async {
    final grid = _entry.grid;
    if (!on || grid == null) {
      _flushSession();
      _metronome.stop();
      setState(() => _sync = false);
      return;
    }
    setState(() => _preparingSync = true);
    try {
      await _player.pause();
      _flushSession();
      _metronome
        ..stop()
        ..setBpm(grid.bpm.round())
        ..setTimeSignature(
          TimeSignature(numerator: grid.beatsPerBar, denominator: 4),
        );
      final transport = ref.read(backingTransportProvider.notifier);
      final rate = await transport.engineSampleRate();
      final bytes = await (_bytes ??= ref.read(audioBytesFetcherProvider)(
        _entry.attachmentIds.first,
      ));
      final pcm = await PracticeRegionsScreen.decodePcm(
        bytes,
        sampleRate: rate,
        durationMs: _durationMs,
      );
      if (!mounted) return;
      if (pcm == null) {
        showAppSnackBar(
          context,
          "This file can't play with the click here — use mp3 or wav",
          error: true,
        );
        return;
      }
      final drums = await _songDrums();
      await transport.attachAudio(
        audio: alignToDownbeat(pcm, grid.offsetMs, rate),
        spans: _syncSpans(),
        drums: drums,
      );
      if (!mounted) return;
      setState(() {
        _sync = true;
      });
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          "Couldn't start click & drums: $e",
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _preparingSync = false);
    }
  }

  /// The song's first drum pattern from its Lab, if it has one.
  Future<MidiPattern?> _songDrums() async {
    try {
      final entries = await ref
          .read(labRepositoryProvider)
          .watchEntries(_entry.songId, bandId: widget.bandId)
          .first
          .timeout(const Duration(seconds: 5));
      for (final e in entries) {
        if (e.type == LabEntryType.midi && e.midi != null) return e.pattern;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _togglePlay() async {
    if (_sync) {
      if (ref.read(metronomeProvider).isPlaying) {
        _metronome.stop();
      } else {
        _syncLaunch();
      }
      return;
    }
    if (_playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      unawaited(_player.play());
    }
  }

  Future<void> _addMarker() async {
    if (!_canEdit) return;
    final at = _snapped(_positionMs);
    final regions = splitRegions(
      _entry.regions,
      atMs: at,
      durationMs: _durationMs,
      newId: () => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
    );
    if (identical(regions, _entry.regions)) return;
    await _changeRegions(regions);
  }

  Future<void> _loadFineTunePcm() async {
    if (_entry.attachmentIds.isEmpty) return;
    try {
      final bytes = await (_bytes ??= ref.read(audioBytesFetcherProvider)(
        _entry.attachmentIds.first,
      ));
      _pcm = await PracticeRegionsScreen.decodePcm(
        bytes,
        sampleRate: 44100,
        durationMs: _durationMs,
      );
    } catch (_) {
      // Fine-tuning still works when the file cannot be decoded.
    }
  }

  Future<Int16List?> _ensurePcm() {
    if (_analysisPcm != null) return Future.value(_analysisPcm);
    return _analysisPcmLoad ??= (() async {
      if (_entry.attachmentIds.isEmpty) return null;
      try {
        final bytes = await (_bytes ??= ref.read(audioBytesFetcherProvider)(
          _entry.attachmentIds.first,
        ));
        return _analysisPcm = await PracticeRegionsScreen.decodePcm(
          bytes,
          sampleRate: 22050,
          durationMs: _durationMs,
        );
      } catch (_) {
        return null;
      }
    })();
  }

  Future<void> _autoSlice() async {
    if (!_canEdit) return;
    var mode = 0;
    var everyBars = 4;
    var sensitivity = 1.5;
    final grid = _entry.grid;
    ({double bpm, int firstDownbeatMs})? suggestion;
    final pcmFuture = _ensurePcm().then((pcm) {
      if (pcm != null && pcm.isNotEmpty) suggestion = estimateGrid(pcm, 22050);
      return pcm;
    });
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.mp.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, sheetSetState) => FutureBuilder<Int16List?>(
          future: pcmFuture,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final pcm = snapshot.data;
            final hasPcm = pcm != null && pcm.isNotEmpty;
            final cuts = mode == 1 && grid != null
                ? gridCuts(grid, everyBars: everyBars, durationMs: _durationMs)
                : mode == 2 && hasPcm
                ? detectOnsets(
                        pcm,
                        22050,
                        sensitivity: sensitivity,
                        minGapMs: 250,
                      )
                      .map(
                        (ms) => _snap && grid != null
                            ? grid.snap(ms, durationMs: _durationMs)
                            : ms,
                      )
                      .toList()
                : <int>[];
            final count = regionsFromCuts(
              cuts,
              durationMs: _durationMs,
              newId: () => '',
            ).length;
            final canApply = mode == 0
                ? !loading && suggestion != null
                : mode == 1
                ? grid != null
                : !loading && hasPcm;
            return Padding(
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auto slice',
                        style: MonoPulseTypography.titleLarge,
                      ),
                      Wrap(
                        spacing: MonoPulseSpacing.sm,
                        children: [
                          for (final (i, label) in [
                            (0, 'Suggest tempo grid'),
                            (1, 'Slice every N bars'),
                            (2, 'Chop by transients'),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: mode == i,
                              onSelected: (_) => sheetSetState(() => mode = i),
                            ),
                        ],
                      ),
                      if (loading && mode != 1)
                        const Center(child: CircularProgressIndicator()),
                      if (!loading && !hasPcm && mode != 1)
                        const Text('Audio could not be decoded for analysis.'),
                      if (mode == 0 && !loading && hasPcm)
                        Text(
                          suggestion == null
                              ? 'Not enough audio to suggest a tempo grid.'
                              : '${suggestion!.bpm.toStringAsFixed(1)} BPM · downbeat '
                                    '${_time(suggestion!.firstDownbeatMs)}.'
                                    '${(suggestion!.firstDownbeatMs % 1000).toString().padLeft(3, '0')}',
                        ),
                      if (mode == 1) ...[
                        if (grid == null) const Text('Set a tempo grid first.'),
                        Wrap(
                          spacing: MonoPulseSpacing.sm,
                          children: [
                            for (final bars in [1, 2, 4, 8])
                              ChoiceChip(
                                label: Text('$bars'),
                                selected: everyBars == bars,
                                onSelected: grid == null
                                    ? null
                                    : (_) =>
                                          sheetSetState(() => everyBars = bars),
                              ),
                          ],
                        ),
                      ],
                      if (mode == 2) ...[
                        Text('Sensitivity ${sensitivity.toStringAsFixed(1)}'),
                        Slider(
                          value: sensitivity,
                          min: 0.5,
                          max: 3,
                          onChanged: hasPcm
                              ? (value) =>
                                    sheetSetState(() => sensitivity = value)
                              : null,
                        ),
                      ],
                      if (mode != 0 && canApply) Text('$count slices'),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: !canApply
                              ? null
                              : () => Navigator.pop(
                                  sheetContext,
                                  mode == 0
                                      ? AudioGrid(
                                          bpm: suggestion!.bpm,
                                          offsetMs: suggestion!.firstDownbeatMs,
                                        )
                                      : cuts,
                                ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    if (!mounted || !_canEdit || result == null) return;
    if (result is AudioGrid) {
      await _setGrid(result);
    } else if (result is List<int>) {
      if (_entry.regions.isNotEmpty) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Replace ${_entry.regions.length} regions?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace'),
              ),
            ],
          ),
        );
        if (replace != true || !mounted || !_canEdit) return;
      }
      await _changeRegions(
        regionsFromCuts(
          result,
          durationMs: _durationMs,
          newId: () =>
              '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
          keepNamesFrom: _entry.regions,
        ),
      );
    }
  }

  Future<void> _audition(
    int ms, {
    int preRollMs = 1000,
    int windowMs = 2000,
  }) async {
    _auditionTimer?.cancel();
    if (_sync) await _setSync(false);
    if (!mounted) return;
    _flushSession();
    setState(() => _selection = null);
    await _applyLoop();
    if (!mounted) return;
    await _player.setSpeed(1);
    if (!mounted) return;
    setState(() => _speed = 1);
    await _seekTo(ms - preRollMs);
    if (!mounted) return;
    unawaited(_player.play());
    _auditionTimer = Timer(Duration(milliseconds: windowMs), () {
      if (mounted) unawaited(_player.pause());
    });
  }

  Future<void> _undo() async {
    final before = _undoRegions;
    if (before == null) return;
    await _changeRegions(before);
    if (mounted) setState(() => _undoRegions = null);
  }

  /// Loops [startMs, endMs) through the same clip practice uses, skipping
  /// the middle, so the loop's join plays over and over.
  Future<void> _loopSeam(int startMs, int endMs) async {
    _auditionTimer?.cancel();
    if (_sync) await _setSync(false);
    if (!mounted) return;
    _flushSession();
    setState(() => _selection = null);
    await (_loopUpdate = _loopUpdate.then((_) async {
      if (!mounted || !_loaded) return;
      _changingClip = true;
      try {
        await _player.pause();
        await _player.setClip(
          start: Duration(milliseconds: startMs),
          end: Duration(milliseconds: endMs),
        );
        await _player.setLoopMode(LoopMode.one);
        if (!mounted) return;
        final length = endMs - startMs;
        setState(() {
          _clipStart = startMs;
          _clipEnd = endMs;
          _position = Duration.zero;
          _lastPosMs = 0;
          _seam = length > 2 * _seamMs ? (_seamMs, length - _seamMs) : null;
        });
        await _player.seek(Duration(milliseconds: _seam?.$2 ?? 0));
        if (mounted) unawaited(_player.play());
      } catch (_) {
        // Fine-tuning still works without the preview.
      } finally {
        _changingClip = false;
      }
    }));
  }

  /// [loop] is the slice run whose join matters (default: the selection when
  /// it touches this marker, else the slice ending here).
  Future<void> _fineTune(int boundaryIndex, {(int, int)? loop}) async {
    if (!_canEdit) return;
    await (_pcmLoad ??= _loadFineTunePcm());
    if (!mounted || !_canEdit) return;
    final grid = _entry.grid;
    final pcm = _pcm;
    var ms = _entry.regions[boundaryIndex].endMs;
    var dragMs = ms.toDouble();
    var snap = BoundarySnap.off;
    var beatMode = false;
    var jogAngle = 0.0;
    var jogPendingMs = 0.0;
    var detentAngle = 0.0;
    var previousAngle = 0.0;
    Duration? previousTime;
    final beatMs = grid == null ? null : grid.barMs / grid.beatsPerBar;
    int constrain(int value) =>
        moveBoundary(_entry.regions, boundaryIndex, value)[boundaryIndex].endMs;
    int snapped(int value) => constrain(switch (snap) {
      BoundarySnap.off => value,
      BoundarySnap.bar => grid!.snap(value, durationMs: _durationMs),
      BoundarySnap.beat => snapToBeat(grid!, value, durationMs: _durationMs),
      BoundarySnap.zeroCrossing => zeroCrossingNear(pcm!, 44100, value),
    });
    final selection = _selection;
    final seamLoop =
        loop ??
        (selection != null &&
                (selection.$2 == boundaryIndex ||
                    selection.$1 == boundaryIndex + 1)
            ? selection
            : (boundaryIndex, boundaryIndex));
    var seamOn = false;
    var seamMs = -1;
    Timer? seamDebounce;
    void playSeam() {
      final regions = moveBoundary(_entry.regions, boundaryIndex, ms);
      unawaited(
        _loopSeam(regions[seamLoop.$1].startMs, regions[seamLoop.$2].endMs),
      );
    }

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.mp.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, sheetSetState) {
          // Re-loop the seam once the marker settles after a change.
          if (seamOn && ms != seamMs) {
            seamMs = ms;
            seamDebounce?.cancel();
            seamDebounce = Timer(const Duration(milliseconds: 250), playSeam);
          }
          void nudge(int delta) =>
              sheetSetState(() => ms = snapped(ms + delta));
          return Padding(
            padding: EdgeInsets.fromLTRB(
              MonoPulseSpacing.lg,
              MonoPulseSpacing.lg,
              MonoPulseSpacing.lg,
              MediaQuery.viewInsetsOf(context).bottom + MonoPulseSpacing.lg,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fine-tune M${boundaryIndex + 1}',
                      style: MonoPulseTypography.titleLarge,
                    ),
                    Text(
                      _preciseTime(ms),
                      style: MonoPulseTypography.titleMedium,
                    ),
                    if (pcm != null && pcm.isNotEmpty)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onHorizontalDragStart: (_) =>
                                dragMs = ms.toDouble(),
                            onHorizontalDragUpdate: (details) =>
                                sheetSetState(() {
                                  dragMs +=
                                      details.delta.dx *
                                      2000 /
                                      constraints.maxWidth;
                                  ms = constrain(dragMs.round());
                                }),
                            onHorizontalDragEnd: (_) =>
                                sheetSetState(() => ms = snapped(ms)),
                            child: CustomPaint(
                              size: Size(constraints.maxWidth, 140),
                              painter: _BoundaryWaveformPainter(
                                pcm: pcm,
                                boundaryMs: ms,
                              ),
                            ),
                          );
                        },
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          label: 'Jog wheel',
                          child: GestureDetector(
                            key: const ValueKey('marker-jog-wheel'),
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (details) {
                              final offset =
                                  details.localPosition - const Offset(80, 80);
                              previousAngle = math.atan2(offset.dy, offset.dx);
                              previousTime = details.sourceTimeStamp;
                              jogPendingMs = 0;
                              detentAngle = 0;
                            },
                            onPanUpdate: (details) {
                              final offset =
                                  details.localPosition - const Offset(80, 80);
                              final angle = math.atan2(offset.dy, offset.dx);
                              final delta = math.atan2(
                                math.sin(angle - previousAngle),
                                math.cos(angle - previousAngle),
                              );
                              final time = details.sourceTimeStamp;
                              final elapsed =
                                  time != null && previousTime != null
                                  ? (time - previousTime!).inMicroseconds /
                                        1000000
                                  : 0.0;
                              previousAngle = angle;
                              previousTime = time;
                              sheetSetState(() {
                                jogAngle += delta;
                                jogPendingMs += jogDeltaMs(
                                  delta,
                                  elapsed > 0 ? delta / elapsed : 0,
                                  beatMode: beatMode,
                                  beatMs: beatMs,
                                );
                                final step = beatMode
                                    ? (jogPendingMs / beatMs!).truncate() *
                                          beatMs
                                    : jogPendingMs.roundToDouble();
                                jogPendingMs -= step;
                                ms = constrain(ms + step.round());
                                detentAngle += delta;
                                final detents = (detentAngle / (math.pi / 12))
                                    .truncate();
                                detentAngle -= detents * (math.pi / 12);
                                for (var i = 0; i < detents.abs(); i++) {
                                  unawaited(HapticFeedback.selectionClick());
                                }
                              });
                            },
                            onPanEnd: (_) {
                              sheetSetState(() => ms = snapped(ms));
                              if (_loaded && !seamOn) {
                                unawaited(
                                  _audition(ms, preRollMs: 0, windowMs: 300),
                                );
                              }
                            },
                            child: CustomPaint(
                              size: const Size(160, 160),
                              painter: _JogWheelPainter(
                                angle: jogAngle,
                                surface: context.mp.blackSurface,
                                outline: context.mp.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: MonoPulseSpacing.sm),
                        Column(
                          children: [
                            for (final mode in [false, if (grid != null) true])
                              ChoiceChip(
                                label: Text(mode ? 'beat' : 'ms'),
                                selected: beatMode == mode,
                                onSelected: (_) => sheetSetState(() {
                                  beatMode = mode;
                                  jogPendingMs = 0;
                                }),
                              ),
                          ],
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final delta in [-10, -1, 1, 10])
                            TextButton(
                              onPressed: () => nudge(delta),
                              child: Text(
                                '${delta > 0 ? '+' : '−'}${delta.abs()} ms',
                              ),
                            ),
                          if (grid != null)
                            for (final direction in [-1, 1])
                              TextButton(
                                onPressed: () => nudge(
                                  (direction * grid.barMs / grid.beatsPerBar)
                                      .round(),
                                ),
                                child: Text(
                                  '${direction > 0 ? '+' : '−'}1 beat',
                                ),
                              ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<BoundarySnap>(
                        segments: [
                          const ButtonSegment(
                            value: BoundarySnap.off,
                            label: Text('Off'),
                          ),
                          ButtonSegment(
                            value: BoundarySnap.bar,
                            label: const Text('Bar'),
                            enabled: grid != null,
                          ),
                          ButtonSegment(
                            value: BoundarySnap.beat,
                            label: const Text('Beat'),
                            enabled: grid != null,
                          ),
                          ButtonSegment(
                            value: BoundarySnap.zeroCrossing,
                            label: const Text('Zero crossing'),
                            enabled: pcm != null && pcm.isNotEmpty,
                          ),
                        ],
                        selected: {snap},
                        onSelectionChanged: (value) =>
                            sheetSetState(() => snap = value.single),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _loaded && !seamOn
                              ? () => _audition(ms)
                              : null,
                          child: const Text('Audition'),
                        ),
                        FilterChip(
                          key: const ValueKey('loop-seam'),
                          label: const Text('Loop seam'),
                          selected: seamOn,
                          onSelected: _loaded
                              ? (on) => sheetSetState(() {
                                  seamOn = on;
                                  seamMs = ms;
                                  seamDebounce?.cancel();
                                  if (on) {
                                    playSeam();
                                  } else {
                                    _seam = null;
                                    unawaited(_player.pause());
                                  }
                                })
                              : null,
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, ms),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    seamDebounce?.cancel();
    final seamed = seamOn;
    _seam = null;
    if (seamed) await _player.pause();
    if (mounted && result != null) {
      await _changeRegions(moveBoundary(_entry.regions, boundaryIndex, result));
    }
    // Hand the edited loop back to practice, ready to play.
    if (mounted && seamed) _selectRegions(seamLoop);
  }

  Future<void> _rename(String id) async {
    if (!_canEdit) return;
    final region = _entry.regions.firstWhere((region) => region.id == id);
    final controller = TextEditingController(text: region.name);
    ModalRoute<dynamic>? sheetRoute;
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.mp.surface,
      builder: (sheetContext) {
        sheetRoute = ModalRoute.of(sheetContext);
        return StatefulBuilder(
          builder: (context, sheetSetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              MonoPulseSpacing.lg,
              MonoPulseSpacing.lg,
              MonoPulseSpacing.lg,
              MediaQuery.viewInsetsOf(context).bottom + MonoPulseSpacing.lg,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Region name',
                      style: MonoPulseTypography.titleLarge,
                    ),
                    Wrap(
                      spacing: MonoPulseSpacing.sm,
                      children: [
                        for (final template in Section.templates)
                          ChoiceChip(
                            label: Text(template),
                            selected: controller.text == template,
                            onSelected: (_) => sheetSetState(() {
                              controller.text = template;
                            }),
                          ),
                      ],
                    ),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: 'Name'),
                      onChanged: (_) => sheetSetState(() {}),
                      onSubmitted: (value) =>
                          Navigator.pop(sheetContext, value),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(sheetContext, controller.text),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    // Keep the controller alive until the sheet finishes dismissing.
    unawaited(sheetRoute?.completed.then((_) => controller.dispose()));
    if (!mounted || !_canEdit || name == null || name.trim().isEmpty) return;
    await _changeRegions([
      for (final region in _entry.regions)
        if (region.id == id) region.copyWith(name: name.trim()) else region,
    ]);
  }

  Future<void> _setGrid(AudioGrid? grid) async {
    if (!_canEdit) return;
    // The loaded stem was aligned to the old grid.
    if (_sync) await _setSync(false);
    if ((_entry.grid == null) != (grid == null)) {
      setState(() {
        _preRoll = 0;
        _snap = grid != null;
      });
    }
    await _save(
      grid == null
          ? _entry.copyWith(clearGrid: true)
          : _entry.copyWith(grid: grid),
    );
    await _applyLoop();
  }

  Future<void> _editGrid() async {
    if (!_canEdit) return;
    final bpm = TextEditingController(text: '${_entry.grid?.bpm ?? 120}');
    var beats = _entry.grid?.beatsPerBar ?? 4;
    var offsetMs = _entry.grid?.offsetMs ?? 0;
    String? error;
    ModalRoute<dynamic>? dialogRoute;
    final grid = await showDialog<AudioGrid>(
      context: context,
      builder: (dialogContext) {
        dialogRoute = ModalRoute.of(dialogContext);
        return StatefulBuilder(
          builder: (context, dialogSetState) => AlertDialog(
            backgroundColor: context.mp.surface,
            title: const Text('Tempo grid'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: bpm,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'BPM',
                      errorText: error,
                    ),
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () => dialogSetState(() {
                          final value = double.tryParse(bpm.text.trim());
                          if (value != null && value.isFinite && value > 0) {
                            offsetMs = (_positionMs % (60000 / value * beats))
                                .round();
                          }
                        }),
                        child: const Text('Downbeat here'),
                      ),
                      TextButton(
                        onPressed: () => dialogSetState(() => offsetMs -= 10),
                        child: const Text('-10 ms'),
                      ),
                      TextButton(
                        onPressed: () => dialogSetState(() => offsetMs += 10),
                        child: const Text('+10 ms'),
                      ),
                    ],
                  ),
                  Text('Downbeat ${_preciseTime(offsetMs)}'),
                  DropdownButton<int>(
                    value: beats,
                    items: [
                      for (var n = 2; n <= 7; n++)
                        DropdownMenuItem(
                          value: n,
                          child: Text('$n beats per bar'),
                        ),
                    ],
                    onChanged: (value) => dialogSetState(() => beats = value!),
                  ),
                ],
              ),
            ),
            actions: [
              if (_entry.grid != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    unawaited(_setGrid(null));
                  },
                  child: const Text('Remove grid'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = double.tryParse(bpm.text.trim());
                  if (value == null || !value.isFinite || value <= 0) {
                    dialogSetState(() => error = 'Enter a positive BPM');
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    AudioGrid(
                      bpm: value,
                      beatsPerBar: beats,
                      offsetMs: offsetMs,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    unawaited(dialogRoute?.completed.then((_) => bpm.dispose()));
    if (mounted && grid != null) await _setGrid(grid);
  }

  String _name(AudioRegion region) =>
      region.name.isEmpty ? 'Unnamed' : region.name;
  String _time(int ms) => formatTimestamp(ms, padMinutes: false);
  String _preciseTime(int ms) =>
      '${formatTimestamp(ms)}.${(ms % 1000).toString().padLeft(3, '0')}';

  Widget _pads() {
    final sections = <String, Section>{};
    if (_entry.regions.any((region) => region.sectionId != null) &&
        _entry.songId.isNotEmpty &&
        _entry.songId != '_inbox') {
      final songs = ref
          .watch(
            widget.bandId == null
                ? songsProvider
                : bandSongsProvider(widget.bandId!),
          )
          .value;
      final song = songs?.where((song) => song.id == _entry.songId).firstOrNull;
      for (final section in song?.sections ?? <Section>[]) {
        sections[section.id] = section;
      }
    }
    final grid = _entry.grid;
    return GridView.builder(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisExtent: 56,
        crossAxisSpacing: MonoPulseSpacing.sm,
        mainAxisSpacing: MonoPulseSpacing.sm,
      ),
      itemCount: _entry.regions.length,
      itemBuilder: (context, i) {
        final region = _entry.regions[i];
        final selection = _selection;
        final selected =
            selection != null && i >= selection.$1 && i <= selection.$2;
        final color = selected
            ? MonoPulseColors.accentOrange
            : sections[region.sectionId]?.color ??
                  colorForName(region.name) ??
                  context.mp.blackSurface;
        final foreground =
            ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? MonoPulseColors.white
            : MonoPulseColors.black;
        return Semantics(
          button: true,
          selected: selected,
          // A second finger can win the gesture arena and swallow
          // onLongPressEnd; lifting the held finger always releases it.
          child: Listener(
            onPointerUp: (_) {
              if (_heldPad == i) _heldPad = null;
            },
            onPointerCancel: (_) {
              if (_heldPad == i) _heldPad = null;
            },
            child: GestureDetector(
              key: ValueKey('region-pad-${region.id}'),
              onLongPressStart: (_) => _heldPad = i,
              onLongPressEnd: (_) => _heldPad = null,
              onLongPressCancel: () {
                if (_heldPad == i) _heldPad = null;
              },
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                if (_canEdit && _editing) {
                  unawaited(_editSlice(i));
                  return;
                }
                final held = _heldPad;
                _selectRegions(
                  held != null
                      ? (held < i ? held : i, held > i ? held : i)
                      : _selection == (i, i)
                      ? null
                      : (i, i),
                );
              },
              child: Material(
                color: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MonoPulseRadius.large),
                  side: BorderSide(
                    color: selected ? MonoPulseColors.accentOrange : color,
                    width: MonoPulseBorder.bold,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(MonoPulseSpacing.sm),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name(region),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MonoPulseTypography.bodyLarge.copyWith(
                            color: foreground,
                          ),
                        ),
                        Text(
                          grid == null
                              ? '${_time(region.startMs)}–${_time(region.endMs)}'
                              // Inclusive last bar: 8 bars from bar 1 is 1–8.
                              : 'Bars ${grid.barAt(region.startMs).round() + 1}–${math.max(grid.barAt(region.startMs).round() + 1, grid.barAt(region.endMs).round())}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MonoPulseTypography.bodySmall.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _rerunSetup() async {
    if (!_canEdit || !_loaded || _durationMs <= 0 || _setupOpen) return;
    _setupOpen = true;
    try {
      if (_entry.regions.isNotEmpty) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Replace ${_entry.regions.length} sections?'),
            content: const Text(
              'Your current sections will be replaced when you finish setup.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace'),
              ),
            ],
          ),
        );
        if (replace != true || !mounted || !_canEdit) return;
      }
      final songs = _entry.songId.isEmpty || _entry.songId == '_inbox'
          ? null
          : ref
                .read(
                  widget.bandId == null
                      ? songsProvider
                      : bandSongsProvider(widget.bandId!),
                )
                .value;
      final song = songs?.where((song) => song.id == _entry.songId).firstOrNull;
      final result = await showPracticeSetupWizard(
        context,
        durationMs: _durationMs,
        detectGrid: () async {
          final pcm = await _ensurePcm();
          return pcm == null || pcm.isEmpty ? null : estimateGrid(pcm, 22050);
        },
        fileMarkers: () async {
          try {
            final bytes = await (_bytes ??= ref.read(audioBytesFetcherProvider)(
              _entry.attachmentIds.first,
            ));
            return readAudioMarkers(bytes);
          } catch (_) {
            return <FileMarker>[];
          }
        },
        previewGrid: (grid) =>
            _audition(grid.offsetMs, preRollMs: 0, windowMs: 4000),
        songSectionNames: [
          for (final section in song?.sections ?? <Section>[]) section.name,
        ],
        newId: () => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
      );
      _auditionTimer?.cancel();
      if (!mounted || !_canEdit) return;
      await _player.pause();
      if (!mounted || result == null) return;
      await _setGrid(result.grid);
      if (!mounted) return;
      if (result.regions != null) await _changeRegions(result.regions!);
      if (!mounted) return;
      if (result.markByEar) {
        await _changeRegions(const []);
        if (mounted)
          setState(() {
            _editing = true;
            _heldPad = null;
          });
      }
    } finally {
      _setupOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit =
        !ref.watch(isDemoUserProvider) &&
        (widget.bandId == null ||
            ref.watch(canEditBandProvider(widget.bandId!)));
    final regions = _entry.regions;
    final grid = _entry.grid;
    final selection = _selection;
    final syncPlaying =
        _sync && ref.watch(metronomeProvider.select((m) => m.isPlaying));
    final syncBar = _sync
        ? ref.watch(backingTransportProvider.select((t) => t.songBar))
        : 0;
    ref.listen(metronomeProvider.select((m) => m.isPlaying), (_, playing) {
      if (_sync) _clock(playing);
    });
    final playing = _sync ? syncPlaying : _playing;
    final positionMs = _sync && grid != null
        ? grid.msOfBar(syncBar)
        : _positionMs;
    final editing = canEdit && _editing;
    return Scaffold(
      backgroundColor: context.mp.black,
      appBar: AppBar(
        title: Text(
          editing ? 'Tap a pad to edit' : _entry.title ?? 'Practice regions',
        ),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Undo',
              icon: const Icon(Icons.undo),
              onPressed: _undoRegions == null ? null : _undo,
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              switch (value) {
                case 'playback':
                  unawaited(_playbackOptions());
                case 'snap':
                  setState(() => _snap = !_snap);
                case 'grid':
                  unawaited(_editGrid());
                case 'slice':
                  unawaited(_autoSlice());
                case 'setup':
                  unawaited(_rerunSetup());
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'playback',
                child: Text('Speed, pre-roll, drums'),
              ),
              if (canEdit) ...[
                if (grid != null)
                  CheckedPopupMenuItem(
                    value: 'snap',
                    checked: _snap,
                    child: const Text('Snap to bar'),
                  ),
                const PopupMenuItem(value: 'grid', child: Text('Tempo grid')),
                PopupMenuItem(
                  value: 'slice',
                  enabled: _loaded && _durationMs > 0,
                  child: const Text('Auto slice'),
                ),
                PopupMenuItem(
                  value: 'setup',
                  enabled: _loaded && _durationMs > 0,
                  child: const Text('Re-run setup'),
                ),
              ],
            ],
          ),
        ],
      ),
      body: SafeArea(
        // Everything fits one screen: only the pads scroll.
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MonoPulseSpacing.lg,
                MonoPulseSpacing.sm,
                MonoPulseSpacing.lg,
                0,
              ),
              child: _timeline(editing),
            ),
            if (editing && regions.any((region) => region.name.isEmpty))
              _nameChips(),
            Expanded(
              child: regions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No sections yet'),
                          if (canEdit)
                            FilledButton(
                              onPressed: _loaded && _durationMs > 0
                                  ? _rerunSetup
                                  : null,
                              child: const Text('Set up sections'),
                            ),
                        ],
                      ),
                    )
                  : _pads(),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MonoPulseSpacing.lg,
                MonoPulseSpacing.sm,
                MonoPulseSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  Text(
                    _sync
                        ? 'Bar ${syncBar + 1}'
                        : '${_time(positionMs)} / ${_time(_durationMs)}',
                    style: MonoPulseTypography.bodySmall,
                  ),
                  const SizedBox(width: MonoPulseSpacing.md),
                  if (selection != null)
                    Expanded(
                      child: Text(
                        'Looping ${_name(regions[selection.$1])}'
                        '${selection.$1 == selection.$2 ? '' : ' → ${_name(regions[selection.$2])}'}',
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MonoPulseTypography.bodySmall.copyWith(
                          color: MonoPulseColors.accentOrange,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // MPC-style bar: Shift | Play | spare, Play dead centre.
            Padding(
              padding: const EdgeInsets.all(MonoPulseSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: canEdit
                        ? _barButton(
                            key: const ValueKey('shift'),
                            icon: Icons.keyboard_capslock,
                            label: 'Shift',
                            active: editing,
                            onPressed: () => setState(() {
                              _editing = !_editing;
                              _heldPad = null;
                            }),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: MonoPulseSpacing.sm),
                  Expanded(
                    child: _barButton(
                      onLongPress: _playbackOptions,
                      key: const ValueKey('play'),
                      icon: playing ? Icons.pause : Icons.play_arrow,
                      label: playing
                          ? 'Pause'
                          : _speed == 1
                          ? 'Play'
                          : 'Play ${(_speed * 100).round()}%',
                      active: true,
                      tooltip: 'Hold for speed, pre-roll, drums',
                      onPressed: _loaded && _durationMs > 0
                          ? _togglePlay
                          : null,
                    ),
                  ),
                  const SizedBox(width: MonoPulseSpacing.sm),
                  Expanded(
                    child: editing
                        ? _barButton(
                            key: const ValueKey('add-marker'),
                            icon: Icons.add_location_alt_outlined,
                            label: 'Add marker',
                            onPressed: _loaded && _durationMs >= 2 * minRegionMs
                                ? _addMarker
                                : null,
                          )
                        // ponytail: spare slot, keeps Play centred.
                        : const SizedBox(
                            height: 64,
                            child: OutlinedButton(
                              onPressed: null,
                              child: SizedBox.shrink(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shift: tap a name to give it to the first unnamed slice, in order, so a
  /// freshly chopped song gets its map in a few taps.
  Widget _nameChips() {
    final songs = _entry.songId.isEmpty || _entry.songId == '_inbox'
        ? null
        : ref
              .watch(
                widget.bandId == null
                    ? songsProvider
                    : bandSongsProvider(widget.bandId!),
              )
              .value;
    final song = songs?.where((song) => song.id == _entry.songId).firstOrNull;
    final names = {
      for (final section in song?.sections ?? <Section>[]) section.name,
      ...Section.templates,
    };
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg),
        children: [
          for (final name in names)
            Padding(
              padding: const EdgeInsets.only(right: MonoPulseSpacing.sm),
              child: ActionChip(
                key: ValueKey('name-chip-$name'),
                label: Text(name),
                backgroundColor: colorForName(name),
                onPressed: () {
                  final i = _entry.regions.indexWhere((r) => r.name.isEmpty);
                  if (i < 0) return;
                  unawaited(HapticFeedback.selectionClick());
                  unawaited(
                    _changeRegions([
                      for (final (j, region) in _entry.regions.indexed)
                        j == i ? region.copyWith(name: name) : region,
                    ]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// One of the three equal bottom-bar buttons.
  Widget _barButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    bool active = false,
    String? tooltip,
  }) {
    final button = SizedBox(
      height: 64,
      child: active
          ? FilledButton(
              key: key,
              onPressed: onPressed,
              onLongPress: onLongPress,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: MonoPulseColors.accentOrange,
                foregroundColor: MonoPulseColors.black,
              ),
              child: _slot(icon, label),
            )
          : OutlinedButton(
              key: key,
              onPressed: onPressed,
              onLongPress: onLongPress,
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: _slot(icon, label),
            ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _slot(IconData icon, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: MonoPulseTypography.bodySmall.fontSize),
      ),
    ],
  );

  /// Hold Play (or ⋮): speed, pre-roll and click & drums in one sheet.
  Future<void> _playbackOptions() async {
    final grid = _entry.grid;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.mp.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, sheetSetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Speed ${(_speed * 100).round()}%',
                  style: MonoPulseTypography.titleMedium,
                ),
                Wrap(
                  spacing: MonoPulseSpacing.sm,
                  children: [
                    for (final percent in [50, 60, 70, 75, 80, 85, 90, 100])
                      ChoiceChip(
                        label: Text('$percent%'),
                        selected: (_speed * 100).round() == percent,
                        onSelected: _sync
                            ? null
                            : (_) {
                                setState(() => _speed = percent / 100);
                                sheetSetState(() {});
                                unawaited(_player.setSpeed(percent / 100));
                              },
                      ),
                  ],
                ),
                const SizedBox(height: MonoPulseSpacing.md),
                const Text('Pre-roll', style: MonoPulseTypography.titleMedium),
                Wrap(
                  spacing: MonoPulseSpacing.sm,
                  children: [
                    for (final value in [0, 1, 2])
                      ChoiceChip(
                        label: Text(grid == null ? '$value s' : '$value bars'),
                        selected: _preRoll == value,
                        onSelected: (_) {
                          setState(() => _preRoll = value);
                          sheetSetState(() {});
                          unawaited(_applyLoop());
                        },
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Click & drums'),
                  subtitle: canSyncToClick(grid)
                      ? null
                      : const Text('Needs a whole-number BPM grid'),
                  value: _sync,
                  onChanged: canSyncToClick(grid) && _loaded && !_preparingSync
                      ? (value) async {
                          await _setSync(value);
                          sheetSetState(() {});
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shift + pad: the slice's start and end, rename, delete. A slice's end
  /// is the next slice's start (the map stays gapless).
  Future<void> _editSlice(int i) async {
    final regions = _entry.regions;
    final region = regions[i];
    final next = i + 1 < regions.length ? regions[i + 1] : null;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.mp.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_name(region), style: MonoPulseTypography.titleLarge),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => Navigator.pop(sheetContext, 'rename'),
            ),
            ListTile(
              key: const ValueKey('slice-start'),
              leading: const Text('Start'),
              title: Text(_preciseTime(region.startMs)),
              subtitle: i == 0
                  ? null
                  : Text('Also end of ${_name(regions[i - 1])}'),
              enabled: i > 0,
              trailing: const Icon(Icons.tune),
              onTap: () => Navigator.pop(sheetContext, 'start'),
            ),
            ListTile(
              key: const ValueKey('slice-end'),
              leading: const Text('End'),
              title: Text(_preciseTime(region.endMs)),
              subtitle: next == null
                  ? null
                  : Text('Also start of ${_name(next)}'),
              enabled: next != null,
              trailing: const Icon(Icons.tune),
              onTap: () => Navigator.pop(sheetContext, 'end'),
            ),
            if (regions.length > 1)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete slice'),
                subtitle: Text(
                  i == 0
                      ? 'Its time joins the next slice'
                      : 'Its time joins the slice before it',
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || !_canEdit) return;
    switch (action) {
      case 'rename':
        await _rename(region.id);
      case 'start':
        await _fineTune(i - 1, loop: (i, i));
      case 'end':
        await _fineTune(i, loop: (i, i));
      case 'delete':
        await _changeRegions(mergeRegion(regions, i));
    }
  }

  Widget _timeline(bool editing) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 96,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _loaded && _durationMs > 0
                      ? (details) {
                          final ms =
                              (details.localPosition.dx / width * _durationMs)
                                  .round();
                          final index = _entry.regions.indexWhere(
                            (region) =>
                                ms >= region.startMs && ms < region.endMs,
                          );
                          if (editing && index >= 0) {
                            unawaited(_rename(_entry.regions[index].id));
                          } else if (!editing) {
                            unawaited(_seekTimeline(ms));
                          }
                        }
                      : null,
                  child: CustomPaint(
                    painter: _RegionsPainter(
                      entry: _entry,
                      durationMs: _durationMs,
                      positionMs: _sync && _entry.grid != null
                          ? _entry.grid!.msOfBar(
                              ref.read(backingTransportProvider).songBar,
                            )
                          : _positionMs,
                      selection: _selection,
                      dim: context.mp.textSecondary,
                      textColor: context.mp.textPrimary,
                    ),
                  ),
                ),
              ),
              if (editing && _durationMs > 0)
                for (var i = 0; i < _entry.regions.length - 1; i++)
                  _boundaryHandle(i, width),
            ],
          ),
        );
      },
    ),
  );

  Widget _boundaryHandle(int index, double width) {
    final centre = _entry.regions[index].endMs / _durationMs * width;
    final left = (centre - 24).clamp(
      0.0,
      (width - 48).clamp(0.0, double.infinity),
    );
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: 48,
      child: GestureDetector(
        key: ValueKey('marker-handle-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _fineTune(index),
        onHorizontalDragStart: (_) {
          _beforeDrag = _entry.regions;
          _dragMs = _entry.regions[index].endMs.toDouble();
        },
        onHorizontalDragUpdate: (details) {
          if (!_canEdit) return;
          // Accumulate unsnapped motion, otherwise small drags stick to a bar.
          _dragMs += details.delta.dx / width * _durationMs;
          setState(
            () => _entry = _entry.copyWith(
              regions: moveBoundary(
                _entry.regions,
                index,
                _snapped(_dragMs.round()),
              ),
            ),
          );
        },
        onHorizontalDragEnd: (_) {
          unawaited(_changeRegions(_entry.regions, undoTo: _beforeDrag));
          _beforeDrag = null;
        },
        onHorizontalDragCancel: () {
          final before = _beforeDrag;
          if (before != null) {
            setState(() => _entry = _entry.copyWith(regions: before));
          }
          _beforeDrag = null;
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: Offset(centre - left - 1.5, 0),
            child: Container(width: 3, color: MonoPulseColors.accentOrange),
          ),
        ),
      ),
    );
  }
}

/// Paint in file coordinates even while just_audio plays a relative clip.
class _JogWheelPainter extends CustomPainter {
  _JogWheelPainter({
    required this.angle,
    required this.surface,
    required this.outline,
  });

  final double angle;
  final Color surface;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    canvas.drawCircle(center, radius, Paint()..color = surface);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final direction = Offset(math.sin(angle), -math.cos(angle));
    canvas.drawLine(
      center + direction * (radius - 20),
      center + direction * (radius - 4),
      Paint()
        ..color = MonoPulseColors.accentOrange
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_JogWheelPainter oldDelegate) =>
      angle != oldDelegate.angle ||
      surface != oldDelegate.surface ||
      outline != oldDelegate.outline;
}

class _RegionsPainter extends CustomPainter {
  _RegionsPainter({
    required this.entry,
    required this.durationMs,
    required this.positionMs,
    required this.selection,
    required this.dim,
    required this.textColor,
  });

  final SongLabEntry entry;
  final int durationMs;
  final int positionMs;
  final (int, int)? selection;
  final Color dim;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (durationMs <= 0 || size.width <= 0) return;
    double x(int ms) => (ms / durationMs).clamp(0.0, 1.0) * size.width;
    if (entry.peaks.isNotEmpty) {
      WaveformPainter(
        peaks: entry.peaks,
        trimStart: 0,
        trimEnd: 1,
        playhead: positionMs / durationMs,
        markerFractions: const [],
        dim: dim,
      ).paint(canvas, size);
    }
    for (var i = 0; i < entry.regions.length; i++) {
      final region = entry.regions[i];
      final selected =
          selection != null && i >= selection!.$1 && i <= selection!.$2;
      final color =
          colorForName(region.name) ?? MonoPulseColors.sectionColors[i % 6];
      final rect = Rect.fromLTRB(
        x(region.startMs),
        0,
        x(region.endMs),
        size.height,
      );
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: selected ? 0.45 : 0.2),
      );
      if (selected) {
        canvas.drawRect(
          rect.deflate(1),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas
        ..save()
        ..clipRect(rect);
      final label = TextPainter(
        text: TextSpan(
          text: region.name.isEmpty ? 'Unnamed' : region.name,
          style: MonoPulseTypography.bodySmall.copyWith(color: textColor),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: (rect.width - 8).clamp(0.0, double.infinity));
      label.paint(canvas, rect.topLeft + const Offset(4, 4));
      label.dispose();
      canvas.restore();
    }
    final grid = entry.grid;
    if (grid != null) {
      final line = Paint()..color = dim.withValues(alpha: 0.5);
      final first = grid.barAt(0).ceil();
      final last = grid.barAt(durationMs).floor();
      // At very high tempos, skip lines closer than a pixel to keep paint bounded.
      final stride = (durationMs / grid.barMs / size.width).ceil().clamp(
        1,
        1 << 30,
      );
      for (var bar = first; bar <= last; bar += stride) {
        final dx = x(grid.msOfBar(bar));
        canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), line);
      }
    }
    canvas.drawLine(
      Offset(x(positionMs), 0),
      Offset(x(positionMs), size.height),
      Paint()
        ..color = textColor
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_RegionsPainter oldDelegate) => true;
}

/// Two seconds of PCM, reduced to a min/max envelope per pixel column.
class _BoundaryWaveformPainter extends CustomPainter {
  const _BoundaryWaveformPainter({required this.pcm, required this.boundaryMs});

  final Int16List pcm;
  final int boundaryMs;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final wave = Paint()
      ..color = MonoPulseColors.accentOrange.withValues(alpha: 0.6);
    final start = (boundaryMs - 1000) * 44100 / 1000;
    final samplesPerPixel = 88200 / size.width;
    for (var x = 0; x < size.width.ceil(); x++) {
      final from = (start + x * samplesPerPixel).floor().clamp(0, pcm.length);
      final to = (start + (x + 1) * samplesPerPixel).ceil().clamp(
        0,
        pcm.length,
      );
      if (from >= to) continue;
      var low = pcm[from];
      var high = low;
      for (var i = from + 1; i < to; i++) {
        if (pcm[i] < low) low = pcm[i];
        if (pcm[i] > high) high = pcm[i];
      }
      canvas.drawLine(
        Offset(x.toDouble(), size.height / 2 - high / 32768 * size.height / 2),
        Offset(x.toDouble(), size.height / 2 - low / 32768 * size.height / 2),
        wave,
      );
    }
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()
        ..color = MonoPulseColors.accentOrange
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _BoundaryWaveformPainter oldDelegate) =>
      pcm != oldDelegate.pcm || boundaryMs != oldDelegate.boundaryMs;
}

/// Same name, same colour: "Chorus" and "Chorus 2" match, in pads and on the
/// waveform. Null for unnamed regions.
Color? colorForName(String name) {
  final base = name.trim().toLowerCase().replaceAll(RegExp(r'[\s\d]+$'), '');
  if (base.isEmpty) return null;
  const colors = MonoPulseColors.sectionColors;
  final template = Section.templates.indexWhere((t) => t.toLowerCase() == base);
  if (template >= 0) return colors[template % colors.length];
  final hash = base.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7fffffff);
  return colors[hash % colors.length];
}
