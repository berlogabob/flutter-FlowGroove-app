import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
import '../services/audio/audio_file_cache.dart';
import '../services/audio/audio_markers.dart';
import '../services/audio/audio_note_edit.dart';
import '../services/audio/m4a_muxer.dart';
import '../services/audio/mp3_encoder.dart';
import '../services/audio/song_peaks.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/play_mode.dart';
import '../utils/snackbar.dart';
import '../widgets/audio/waveform_painter.dart';
import '../widgets/confirmation_dialog.dart';
import 'practice_regions/auto_slice_sheet.dart';
import 'practice_regions/grid_editor_dialog.dart';
import 'practice_regions/region_name_sheet.dart';
import 'practice_regions/slice_edit_sheet.dart';
import 'practice_setup_wizard.dart';

part 'practice_regions/notes_panel.dart';
part 'practice_regions/file_actions.dart';

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

  /// Allows widget tests to supply a player without native audio.
  final AudioPlayer? player;

  @override
  ConsumerState<PracticeRegionsScreen> createState() =>
      _PracticeRegionsScreenState();
}

class _PracticeRegionsScreenState extends ConsumerState<PracticeRegionsScreen> {
  late SongLabEntry _entry;
  late final TextEditingController _title;

  /// Saves the title whenever the field loses focus (tap outside, back).
  final _titleFocus = FocusNode();
  bool _busy = false;
  late final AudioPlayer _player;
  final _subs = <StreamSubscription<dynamic>>[];
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _loaded = false;
  bool _editing = false;
  bool _setupOpen = false;
  int? _heldPad;
  final _padPointers = <int>{};

  /// Shift: the slice last tapped; the waveform zooms to it.
  int? _focus;
  (int, int)? _dragView;

  /// A hold + tap just made a run: swallow the taps those fingers end in.
  bool _runMade = false;
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
  Int16List? _analysisPcm;
  Future<Int16List?>? _analysisPcmLoad;
  Future<Uint8List>? _uncachedBytes;
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

  /// Visible waveform range: the whole song, or in Shift the focused slice
  /// plus a little of each neighbour. Frozen while a marker is dragged.
  (int, int) get _view {
    final drag = _dragView;
    if (drag != null) return drag;
    final focus = _focus;
    if (!_editing || focus == null || focus >= _entry.regions.length) {
      return (0, _durationMs);
    }
    final region = _entry.regions[focus];
    final pad = math.max(1000, region.lengthMs ~/ 6);
    return (
      math.max(0, region.startMs - pad),
      math.min(_durationMs, region.endMs + pad),
    );
  }

  /// Under a bar (or 2 s without a grid): usually a stray tap or count-in.
  bool _isShort(AudioRegion region) =>
      !region.skip && region.lengthMs < (_entry.grid?.barMs ?? 2000);
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
    _title = TextEditingController(text: _entry.title ?? '');
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) unawaited(_saveTitle());
    });
    _snap = _entry.grid != null;
    _player = widget.player ?? AudioPlayer();
    _sessions = ref.read(metronomeSessionRepositoryProvider);
    _logSessions = !ref.read(isDemoUserProvider);
    _metronome = ref.read(metronomeProvider.notifier);
    unawaited(_load());
    unawaited(_backfillPeaks());
  }

  /// RMS bars at a usable resolution. Parts, splits and shrinks slice the
  /// parent's bars (a ninth of a long file is ~20 bars), so few bars also
  /// means re-derive.
  bool get _peaksFine => _entry.peaksRms && _entry.peaks.length >= 100;

  /// Decode missing or legacy max-sample peaks so regions can be marked
  /// against the waveform. Saved for editors, shown locally for
  /// everyone else. Silent on failure — the plain strip still works.
  Future<void> _backfillPeaks() async {
    if (_peaksFine || _entry.attachmentIds.isEmpty) return;
    try {
      final bytes = await _readAudioBytes();
      final peaks = await decodeSongPeaks(bytes);
      if (peaks == null || !mounted || _peaksFine) return;
      final updated = _entry.copyWith(peaks: peaks, peaksRms: true);
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
      try {
        path = (await _cachedFile())?.path;
      } catch (_) {}
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
          } else if (seam == null && _playing && !_sync && !_changingClip) {
            _skipFrom(ms);
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
          _durationMs >= 60000 &&
          _entry.regions.isEmpty &&
          _canEdit) {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted ||
            prefs.getBool('practice_setup_seen_${_entry.id}') == true) {
          return;
        }
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
    // A dispose racing a load can throw inside just_audio; nothing to recover.
    unawaited(_player.dispose().catchError((Object _) {}));
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) => setState(change);

  Future<void> _save(
    SongLabEntry updated, {
    bool requireSuccess = false,
  }) async {
    if (!mounted || !_canEdit) {
      if (requireSuccess) throw StateError('Recording is no longer editable');
      return;
    }
    if (!requireSuccess) setState(() => _entry = updated);
    try {
      await ref
          .read(labRepositoryProvider)
          .saveEntry(updated, bandId: widget.bandId);
      if (requireSuccess && mounted) {
        setState(() {
          _entry = updated;
          _selection = null;
          _focus = null;
          _undoRegions = null;
        });
      }
    } catch (e) {
      if (requireSuccess) rethrow;
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

  /// The grid moved back whole bars so its bar 0 is at or before the file
  /// start: the pickup before the first downbeat plays instead of being cut.
  AudioGrid get _syncGrid {
    final grid = _entry.grid!;
    final pickupBars = (grid.offsetMs / grid.barMs).ceil();
    return grid.copyWith(
      offsetMs: (grid.offsetMs - pickupBars * grid.barMs).round(),
    );
  }

  /// Launchable spans: each region, the whole song, and the selected run.
  List<SectionSpan> _syncSpans() {
    final grid = _syncGrid;
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
      final bytes = await _readAudioBytes();
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
        audio: alignToDownbeat(pcm, _syncGrid.offsetMs, rate),
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

  /// The song page's BPM, which picks the detected tempo's octave.
  double? _songBpm() {
    if (_entry.songId.isEmpty || _entry.songId == '_inbox') return null;
    final songs = ref
        .read(
          widget.bandId == null
              ? songsProvider
              : bandSongsProvider(widget.bandId!),
        )
        .value;
    final song = songs?.where((s) => s.id == _entry.songId).firstOrNull;
    return (song?.ourBPM ?? song?.originalBPM)?.toDouble();
  }

  /// The song's first drum pattern from its Lab, if it has one.
  Future<MidiPattern?> _songDrums() async {
    if (_entry.songId.isEmpty || _entry.songId == '_inbox') return null;
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

  Future<File?> _cachedFile() => audioFileCache(
    _entry.attachmentIds.first,
    ref.read(audioBytesFetcherProvider),
  );

  Future<Uint8List> _readAudioBytes() async {
    try {
      final file = await _cachedFile();
      if (file != null) return await file.readAsBytes();
    } catch (_) {}
    return _uncachedBytes ??= ref.read(audioBytesFetcherProvider)(
      _entry.attachmentIds.first,
    );
  }

  Future<Int16List?> _ensurePcm() {
    if (_analysisPcm != null) return Future.value(_analysisPcm);
    return _analysisPcmLoad ??= (() async {
      if (_entry.attachmentIds.isEmpty) return null;
      try {
        Future<Int16List?> decode() async => PracticeRegionsScreen.decodePcm(
          await _readAudioBytes(),
          sampleRate: 22050,
          durationMs: _durationMs,
        );
        return _analysisPcm = await cachedPcm22k(await _cachedFile(), decode);
      } catch (_) {
        return null;
      }
    })();
  }

  Future<void> _autoSlice() async {
    if (!_canEdit) return;
    final result = await showAutoSliceSheet(
      context,
      grid: _entry.grid,
      ensurePcm: _ensurePcm,
      songBpm: _songBpm,
      durationMs: () => _durationMs,
      snap: () => _snap,
      time: _time,
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
    final pcm = await _ensurePcm();
    if (!mounted || !_canEdit) return;
    final grid = _entry.grid;
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
      BoundarySnap.zeroCrossing => zeroCrossingNear(pcm!, 22050, value),
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
    final name = await showRegionNameSheet(context, initialName: region.name);
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
    final grid = await showGridEditorDialog(
      context,
      getGrid: () => _entry.grid,
      positionMs: () => _positionMs,
      preciseTime: _preciseTime,
      onRemoveGrid: () => _setGrid(null),
    );
    if (mounted && grid != null) await _setGrid(grid);
  }

  String _name(AudioRegion region) =>
      region.name.isEmpty ? 'Unnamed' : region.name;
  String _time(int ms) => formatTimestamp(ms, padMinutes: false);
  String _preciseTime(int ms) =>
      '${formatTimestamp(ms)}.${(ms % 1000).toString().padLeft(3, '0')}';

  /// Jumps over skipped slices; [ms] is clip-relative.
  void _skipFrom(int ms) {
    final target = skipTarget(_entry.regions, _clipStart + ms);
    if (target == null) return;
    final end = _clipEnd ?? _durationMs;
    if (target < end) {
      unawaited(_player.seek(Duration(milliseconds: target - _clipStart)));
    } else if (_clipEnd == null) {
      unawaited(_player.pause());
    } else if (skipTarget(_entry.regions, _clipStart) == null) {
      // The loop's tail is skipped: wrap to its start.
      unawaited(_player.seek(Duration.zero));
    }
  }

  void _releasePad(int pointer, int pad) {
    _padPointers.remove(pointer);
    if (_heldPad == pad) _heldPad = null;
    // Taps resolve after this pointer-up, in the same event; clear after.
    if (_padPointers.isEmpty && _runMade) {
      scheduleMicrotask(() => _runMade = false);
    }
  }

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
    final editing = _canEdit && _editing;
    // Skipped slices only show in Shift, so they can be brought back.
    final visible = [
      for (final (i, region) in _entry.regions.indexed)
        if (editing || !region.skip) i,
    ];
    return GridView.builder(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisExtent: 56,
        crossAxisSpacing: MonoPulseSpacing.sm,
        mainAxisSpacing: MonoPulseSpacing.sm,
      ),
      itemCount: visible.length,
      itemBuilder: (context, slot) {
        final i = visible[slot];
        final region = _entry.regions[i];
        final selection = _selection;
        final selected =
            selection != null && i >= selection.$1 && i <= selection.$2;
        final color = selected
            ? MonoPulseColors.accentOrange
            : region.skip
            ? context.mp.black
            : sections[region.sectionId]?.color ??
                  colorForName(region.name) ??
                  context.mp.blackSurface;
        final foreground =
            ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? MonoPulseColors.white
            : MonoPulseColors.black;
        final playingHere =
            _playing &&
            !_sync &&
            _positionMs >= region.startMs &&
            _positionMs < region.endMs;
        return Semantics(
          button: true,
          selected: selected,
          // Runs, MPC style: hold one pad and tap another. Tracked on raw
          // pointers (no long-press delay, no gesture arena) so the scrolling
          // grid can't steal the hold.
          child: Listener(
            onPointerDown: (event) {
              _padPointers.add(event.pointer);
              final held = _heldPad;
              if (editing || held == null || held == i) {
                _heldPad ??= i;
                return;
              }
              _runMade = true;
              unawaited(HapticFeedback.selectionClick());
              _selectRegions((math.min(held, i), math.max(held, i)));
            },
            onPointerUp: (event) => _releasePad(event.pointer, i),
            onPointerCancel: (event) => _releasePad(event.pointer, i),
            child: GestureDetector(
              key: ValueKey('region-pad-${region.id}'),
              // One-handed: long-press a pad to stretch the loop to it.
              onLongPress: editing || _selection == null
                  ? null
                  : () {
                      final (a, b) = _selection!;
                      unawaited(HapticFeedback.selectionClick());
                      _selectRegions((math.min(a, i), math.max(b, i)));
                    },
              onTap: () {
                if (_runMade) return;
                unawaited(HapticFeedback.selectionClick());
                if (editing) {
                  setState(() => _focus = i);
                  unawaited(
                    _ensurePcm().then((_) {
                      if (mounted) setState(() {});
                    }),
                  );
                  unawaited(_editSlice(i));
                  return;
                }
                _selectRegions(_selection == (i, i) ? null : (i, i));
              },
              child: Material(
                color: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MonoPulseRadius.large),
                  side: BorderSide(
                    color: playingHere
                        ? MonoPulseColors.white
                        : selected
                        ? MonoPulseColors.accentOrange
                        : color,
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
                          _isShort(region)
                              ? '⚠ ${(region.lengthMs / 1000).toStringAsFixed(1)} s'
                              : grid == null
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
          return pcm == null || pcm.isEmpty
              ? null
              : estimateGrid(pcm, 22050, hintBpm: _songBpm());
        },
        fileMarkers: () async {
          try {
            final bytes = await _readAudioBytes();
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('practice_setup_seen_${_entry.id}', true);
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
        !_busy &&
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
        ? _syncGrid.msOfBar(syncBar)
        : _positionMs;
    final editing = canEdit && _editing;
    return Scaffold(
      backgroundColor: context.mp.black,
      appBar: AppBar(
        title: canEdit
            ? TextField(
                key: const ValueKey('recording-title'),
                controller: _title,
                focusNode: _titleFocus,
                style: MonoPulseTypography.titleLarge,
                decoration: InputDecoration(
                  hintText: 'Practice regions',
                  helperText: editing ? 'Tap a pad to edit' : null,
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _saveTitle(),
                onTapOutside: (_) => _titleFocus.unfocus(),
              )
            : Text(_entry.title ?? 'Practice regions'),
        actions: [
          if (editing && _focus != null)
            IconButton(
              tooltip: 'Whole song',
              icon: const Icon(Icons.zoom_out_map),
              onPressed: () => setState(() => _focus = null),
            ),
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
                case 'note':
                  unawaited(_addMarkerAtPlayhead());
                case 'shrink':
                  unawaited(_saveTrim());
                case 'split':
                  unawaited(_splitAtPlayhead());
                case 'share':
                  unawaited(_share());
                case 'share-edges':
                  unawaited(_share(withoutSkippedEdges: true));
                case 'delete':
                  unawaited(_delete());
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
            enabled: !_busy,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'share',
                enabled: _url != null,
                child: const Text('Share'),
              ),
              if (_hasSkippedEdges)
                PopupMenuItem(
                  value: 'share-edges',
                  enabled: _url != null && _durationMs > 0,
                  child: const Text('Share without skipped edges'),
                ),
              const PopupMenuItem(
                value: 'playback',
                child: Text('Speed, pre-roll, drums'),
              ),
              if (canEdit) ...[
                const PopupMenuItem(
                  value: 'note',
                  child: Text('Add note at playhead'),
                ),
                PopupMenuItem(
                  value: 'shrink',
                  enabled: _url != null && _hasSkippedEdges && _durationMs > 0,
                  child: const Text('Shrink file'),
                ),
                if (_canSplit)
                  PopupMenuItem(
                    value: 'split',
                    enabled: _loaded && _durationMs > 0,
                    child: const Text('Split at playhead'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete recording'),
                ),
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
        child: AbsorbPointer(
          absorbing: _busy,
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
              if (_entry.peaks.isEmpty) ...[
                Slider(
                  value: _durationMs == 0
                      ? 0
                      : (positionMs / _durationMs).clamp(0.0, 1.0),
                  onChanged: _loaded && _durationMs > 0
                      ? (v) => _seekTimeline((v * _durationMs).round())
                      : null,
                ),
                Text(
                  'No waveform for this take — tap or drag to seek.',
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: context.mp.textSecondary,
                  ),
                ),
              ],
              if (editing &&
                  regions.any(
                    (region) => region.name.isEmpty || _isShort(region),
                  ))
                _nameChips(),
              Expanded(
                child: regions.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
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
                        ),
                      )
                    : _pads(),
              ),
              Flexible(
                fit: FlexFit.tight,
                child: _NotesPanel(
                  markers: entryNotes(_entry),
                  positionMs: positionMs,
                  onSeek: _seekNote,
                  onAdd: canEdit ? _addMarkerAtPlayhead : null,
                  onDelete: canEdit ? _deleteMarker : null,
                ),
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
                    if (!editing && regions.any((region) => region.skip))
                      Text(
                        '${regions.where((region) => region.skip).length} skipped',
                        style: MonoPulseTypography.bodySmall.copyWith(
                          color: context.mp.textSecondary,
                        ),
                      ),
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
                                _focus = null;
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
                        onPressed: _loaded && _durationMs > 0 && !_busy
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
                              onPressed:
                                  _loaded && _durationMs >= 2 * minRegionMs
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
    final shortCount = _entry.regions.where(_isShort).length;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg),
        children: [
          if (shortCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: MonoPulseSpacing.sm),
              child: ActionChip(
                key: const ValueKey('skip-short'),
                avatar: const Icon(Icons.warning_amber, size: 18),
                label: Text('Skip $shortCount short'),
                onPressed: () => unawaited(
                  _changeRegions([
                    for (final region in _entry.regions)
                      _isShort(region) ? region.copyWith(skip: true) : region,
                  ]),
                ),
              ),
            ),
          if (_entry.regions.any((region) => region.name.isEmpty))
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
    final action = await showSliceEditSheet(
      context,
      regions: regions,
      i: i,
      name: _name,
      preciseTime: _preciseTime,
    );
    if (!mounted || !_canEdit) return;
    switch (action) {
      case 'rename':
        await _rename(region.id);
      case 'start' when i == 0:
        await _trimEdge(i, start: true);
      case 'start':
        await _fineTune(i - 1, loop: (i, i));
      case 'end' when next == null:
        await _trimEdge(i, start: false);
      case 'end':
        await _fineTune(i, loop: (i, i));
      case 'delete':
        await _changeRegions(mergeRegion(regions, i));
      case 'skip':
        await _changeRegions([
          for (final (j, r) in regions.indexed)
            j == i ? r.copyWith(skip: !r.skip) : r,
        ]);
    }
  }

  /// Start of the first slice / end of the last: splits off a skipped
  /// lead-in or tail and fine-tunes its edge. Left untouched, it is removed.
  Future<void> _trimEdge(int i, {required bool start}) async {
    final before = _entry.regions;
    final r = before[i];
    final split = splitRegions(
      before,
      atMs: start ? r.startMs + minEdgeMs : r.endMs - minEdgeMs,
      durationMs: _durationMs,
      newId: () => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
    );
    if (identical(split, before)) return;
    await _changeRegions(split);
    if (!mounted) return;
    final slice = start ? i + 1 : i;
    await _fineTune(i, loop: (slice, slice));
    if (!mounted) return;
    final edge = start ? i : i + 1;
    final now = _entry.regions;
    if (edge < now.length && now[edge].endMs - now[edge].startMs <= minEdgeMs) {
      await _changeRegions(mergeRegion(now, edge), undoTo: before);
    } else {
      setState(() => _undoRegions = before);
    }
  }

  Widget _timeline(bool editing) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final (viewStart, viewEnd) = _view;
        final span = math.max(1, viewEnd - viewStart);
        return SizedBox(
          height: 108,
          child: Stack(
            children: [
              Positioned.fill(
                top: 12,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _loaded && _durationMs > 0
                      ? (details) {
                          final ms =
                              (viewStart +
                                      details.localPosition.dx / width * span)
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
                      viewStart: viewStart,
                      viewEnd: viewEnd,
                      pcm: _focus != null && editing ? _analysisPcm : null,
                      positionMs: _sync && _entry.grid != null
                          ? _syncGrid.msOfBar(
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
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 10,
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('note-ticks'),
                    painter: _NoteTicksPainter(
                      markers: entryNotes(_entry),
                      viewStart: viewStart,
                      viewEnd: viewEnd,
                    ),
                  ),
                ),
              ),
              if (editing && _durationMs > 0)
                for (var i = 0; i < _entry.regions.length - 1; i++)
                  if (_entry.regions[i].endMs >= viewStart &&
                      _entry.regions[i].endMs <= viewEnd)
                    _boundaryHandle(i, width, viewStart, span),
            ],
          ),
        );
      },
    ),
  );

  Widget _boundaryHandle(int index, double width, int viewStart, int span) {
    final centre = (_entry.regions[index].endMs - viewStart) / span * width;
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
          _dragView = _view;
          _dragMs = _entry.regions[index].endMs.toDouble();
        },
        onHorizontalDragUpdate: (details) {
          if (!_canEdit) return;
          // Accumulate unsnapped motion, otherwise small drags stick to a bar.
          _dragMs += details.delta.dx / width * span;
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
          _dragView = null;
        },
        onHorizontalDragCancel: () {
          final before = _beforeDrag;
          if (before != null) {
            setState(() => _entry = _entry.copyWith(regions: before));
          }
          _beforeDrag = null;
          _dragView = null;
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
    required this.viewStart,
    required this.viewEnd,
    required this.pcm,
    required this.positionMs,
    required this.selection,
    required this.dim,
    required this.textColor,
  });

  final SongLabEntry entry;
  final int durationMs;
  final int viewStart;
  final int viewEnd;

  /// Mono 22.05 kHz PCM for a sharp zoomed waveform; peaks otherwise.
  final Int16List? pcm;
  final int positionMs;
  final (int, int)? selection;
  final Color dim;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final span = viewEnd - viewStart;
    if (durationMs <= 0 || span <= 0 || size.width <= 0) return;
    double x(int ms) => ((ms - viewStart) / span).clamp(0.0, 1.0) * size.width;
    final samples = pcm;
    if (samples != null && samples.isNotEmpty && span < durationMs) {
      _paintEnvelope(canvas, size, samples);
    } else if (entry.peaks.isNotEmpty) {
      // Paint the whole song stretched, shifted so the view fills the box.
      final full = size.width * durationMs / span;
      canvas
        ..save()
        ..clipRect(Offset.zero & size)
        ..translate(-viewStart / durationMs * full, 0);
      WaveformPainter(
        peaks: entry.peaks,
        trimStart: 0,
        trimEnd: 1,
        playhead: positionMs / durationMs,
        markerFractions: const [],
        dim: dim,
      ).paint(canvas, Size(full, size.height));
      canvas.restore();
    }
    for (var i = 0; i < entry.regions.length; i++) {
      final region = entry.regions[i];
      final selected =
          selection != null && i >= selection!.$1 && i <= selection!.$2;
      final color = region.skip
          ? dim
          : colorForName(region.name) ?? MonoPulseColors.sectionColors[i % 6];
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
      final first = grid.barAt(viewStart).ceil();
      final last = grid.barAt(viewEnd).floor();
      // At very high tempos, skip lines closer than a pixel to keep paint bounded.
      final stride = (span / grid.barMs / size.width).ceil().clamp(1, 1 << 30);
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

  void _paintEnvelope(Canvas canvas, Size size, Int16List samples) {
    final wave = Paint()
      ..color = MonoPulseColors.accentOrange.withValues(alpha: 0.7);
    final mid = size.height / 2;
    final perPixel = (viewEnd - viewStart) * 22.05 / size.width;
    final start = viewStart * 22.05;
    for (var px = 0; px < size.width.ceil(); px++) {
      final from = (start + px * perPixel).floor().clamp(0, samples.length);
      final to = (start + (px + 1) * perPixel).ceil().clamp(0, samples.length);
      if (from >= to) continue;
      var low = 0, high = 0;
      // ponytail: strided scan, plenty for a phone-width column.
      final stride = math.max(1, (to - from) ~/ 256);
      for (var i = from; i < to; i += stride) {
        final v = samples[i];
        if (v < low) low = v;
        if (v > high) high = v;
      }
      canvas.drawLine(
        Offset(px.toDouble(), mid - high / 32768 * mid),
        Offset(px.toDouble(), mid - low / 32768 * mid),
        wave,
      );
    }
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
    final start = (boundaryMs - 1000) * 22050 / 1000;
    final samplesPerPixel = 2 * 22050 / size.width;
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
