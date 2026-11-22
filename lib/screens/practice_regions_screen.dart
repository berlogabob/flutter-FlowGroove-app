import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_region.dart';
import '../models/metronome_session.dart';
import '../models/midi_pattern.dart';
import '../models/section.dart';
import '../models/section_span.dart';
import '../models/song.dart';
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
import '../services/audio/song_structure.dart' show SongStructure;
import '../theme/mono_pulse_theme.dart';
import '../utils/play_mode.dart';
import '../utils/snackbar.dart';
import '../widgets/confirmation_dialog.dart';
import 'practice_regions/auto_slice_sheet.dart';
import 'practice_regions/grid_editor_dialog.dart';
import 'practice_regions/region_name_sheet.dart';
import 'practice_regions/slice_edit_sheet.dart';
import 'practice_regions/song_map/song_map_edit.dart' as song_map_edit;
import 'practice_regions/song_map/song_map_letters.dart';
import 'practice_regions/song_map/song_map_pads.dart';
import 'practice_regions/song_map/song_map_tempo_banner.dart';
import 'practice_regions/song_map/song_map_timeline.dart';
import 'practice_regions/song_map/song_map_transport.dart';
import 'practice_regions/song_map/song_map_view.dart';
import 'practice_setup_wizard.dart';

part 'practice_regions/notes_panel.dart';
part 'practice_regions/file_actions.dart';

({AudioGrid? grid, SongStructure? structure, List<int> cuts})
_analyseSongRequest((Int16List, int, double?, AudioGrid?, int) request) {
  final (pcm, durationMs, hintBpm, existingGrid, songSections) = request;
  final detected = estimateGrid(pcm, 22050, hintBpm: hintBpm);
  final grid = detected == null
      ? existingGrid
      : AudioGrid(
          bpm: detected.bpm,
          offsetMs: detected.firstDownbeatMs.clamp(0, durationMs),
        );
  final structure = grid == null ? null : analyseStructureRequest((pcm, grid));
  if (structure != null) return (grid: grid, structure: structure, cuts: []);
  final changes = sectionCuts(pcm, 22050, grid: grid);
  final cuts = topSectionCuts(
    changes,
    suggestedSectionCuts(changes, songSections: songSections),
  );
  return (grid: grid, structure: null, cuts: cuts);
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

  /// Decoder for the zoom, analysis, fine-tuning, and click & drums mode.
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
  String? _sessionSongTitle;
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
  bool? _notesExpanded;
  bool _editingTitle = false;
  bool _setupOpen = false;
  bool _showAnalyzePrompt = false;
  bool _analyzing = false;
  bool _candidateExitOpen = false;
  ({AudioGrid? grid, List<AudioRegion> regions, Set<int> boundaries})?
  _mapCandidate;

  /// The slice opened for editing in Shift mode.
  int? _focus;

  late bool _snap;
  double _speed = 1;
  late SharedPreferences _tempoPrefs;
  bool? _stretchTempo;
  int _preRoll = 0;
  bool? _loopEnabled;
  (int, int)? _selection;
  int _clipStart = 0;
  int? _clipEnd;
  bool _changingClip = false;
  // The cached song file, and whether the player is on a loop WAV cut from it.
  String? _songPath;
  bool _onLoopWav = false;
  // A loop waiting for the current pass to end (see _queueLoop).
  (int, int)? _pendingLoop;
  Future<void> _loopUpdate = Future<void>.value();
  int _idCounter = 0;
  Int16List? _analysisPcm;
  Future<Int16List?>? _analysisPcmLoad;
  Future<Uint8List>? _uncachedBytes;
  Timer? _auditionTimer;

  /// Seam loop (fine-tune): clip-relative (head, tail); past the head of
  /// each pass playback jumps to the tail, so only the join repeats.
  (int, int)? _seam;
  static const _seamMs = 1500;

  /// One level of undo for region edits (they save immediately).
  List<AudioRegion>? _undoRegions;
  SongMapView? _songMap;
  int? _songMapBoundaryMs;
  int? _songMapCutMs;

  // Practice log: one session per loop selection, written when it changes or
  // the screen closes. Captured in initState because ref is gone by dispose.
  late final MetronomeSessionRepository _sessions;

  /// Title edits still pending at close (keyboard hidden with Back keeps the
  /// field focused, so focus loss never saved them). ref is gone by dispose.
  late final Future<void> Function(SongLabEntry) _saveOnClose;
  late final bool _editableAtOpen;
  late final bool _logSessions;
  DateTime? _sessionStart;
  DateTime? _playingSince;
  int _playedMs = 0;
  int _reps = 0;
  int _lastPosMs = 0;

  // Click & drums mode: the song plays as a backing stem inside the click
  // engine (sample-locked, 100% speed) instead of through just_audio.
  bool _sync = false;
  bool _withDrums = true;
  bool _preparingSync = false;
  late final MetronomeNotifier _metronome;

  int get _durationMs => _duration.inMilliseconds;

  String get _tempoPreferenceKey {
    final songId = _entry.songId;
    return songId.isEmpty || songId == '_inbox'
        ? 'practice_tempo_stretch_entry_${_entry.id}'
        : 'practice_tempo_stretch_song_${widget.bandId ?? ''}_$songId';
  }

  double? get _measuredBpm => (_mapCandidate?.grid ?? _entry.grid)?.bpm;
  double get _stretchFactor =>
      _stretchTempo == true ? songMapStretchFactor(_measuredBpm) : 1;
  bool get _stretched => _stretchFactor != 1;

  Future<void> _applyTempoSpeed() async {
    if (_sync && _stretched) await _setSync(false);
    if (!mounted) return;
    final speed = _stretchFactor * _speed;
    if (_player.speed != speed) await _player.setSpeed(speed);
  }

  Future<void> _chooseTempo(bool stretch) async {
    if (_stretchTempo != null) return;
    setState(() => _stretchTempo = stretch);
    try {
      await Future.wait([
        _applyTempoSpeed(),
        _tempoPrefs.setBool(_tempoPreferenceKey, stretch),
      ]);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          "Couldn't apply tempo choice: $e",
          error: true,
        );
      }
    }
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
      if (!_titleFocus.hasFocus && mounted) {
        setState(() => _editingTitle = false);
        unawaited(_saveTitle());
      }
    });
    _snap = _entry.grid != null;
    _player = widget.player ?? AudioPlayer();
    _sessions = ref.read(metronomeSessionRepositoryProvider);
    final labRepo = ref.read(labRepositoryProvider);
    _saveOnClose = (e) => labRepo.saveEntry(e, bandId: widget.bandId);
    _editableAtOpen = _canEdit;
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
      _songPath = path;
      if (path != null && Platform.isAndroid) {
        unawaited(songWav(path).then((_) {}, onError: (_) {}));
      }
      final duration = path == null
          ? await _player.setUrl(url)
          : await _player.setFilePath(path);
      _tempoPrefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _stretchTempo = _tempoPrefs.getBool(_tempoPreferenceKey);
      await _applyTempoSpeed();
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
          if (!mounted || _changingClip) return;
          if (_pendingLoop != null &&
              (_player.playbackEvent.currentIndex ?? 0) > 0) {
            return; // The next WAV's position uses a different origin.
          }
          // A looping clip jumps back to its start: count the pass.
          final ms = position.inMilliseconds;
          if (_playing && _clipEnd != null && ms + 1000 < _lastPosMs) _reps++;
          _lastPosMs = ms;
          final seam = _seam;
          final end = _clipEnd;
          final pastEnd = end != null && ms >= end - _clipStart;
          if (seam != null && ms > seam.$1 && ms < seam.$2) {
            unawaited(_player.seek(Duration(milliseconds: seam.$2)));
          } else if (seam == null && _playing && !_sync && !pastEnd) {
            _skipFrom(ms);
          }
          setState(() {
            _position = pastEnd || position.isNegative
                ? Duration.zero
                : position;
          });
        }),
        _player.currentIndexStream.listen(_onLoopIndex),
        _player.playerStateStream.listen((state) {
          if (!mounted) return;
          if (!_sync) _clock(state.playing);
          if (!_changingClip) setState(() => _playing = state.playing);
        }),
      ]);
      await _applyLoop();
      if (mounted &&
          PracticeRegionsScreen.autoOpenSetup &&
          _durationMs > 0 &&
          _entry.regions.isEmpty &&
          _canEdit) {
        final prefs = _tempoPrefs;
        if (!mounted ||
            !_canEdit ||
            _entry.regions.isNotEmpty ||
            prefs.getBool('practice_setup_seen_${_entry.id}') == true) {
          return;
        }
        if (!_analyzing && _mapCandidate == null) {
          setState(() => _showAnalyzePrompt = true);
        }
        await prefs.setBool('practice_setup_seen_${_entry.id}', true);
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
    String label(int index) => regions[index].name.trim().isEmpty
        ? 'Section ${index + 1}'
        : regions[index].name;
    return a == b ? label(a) : '${label(a)} → ${label(b)}';
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
                songTitle: _sessionSongTitle,
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
    _songMap?.dispose();
    _auditionTimer?.cancel();
    _flushSession();
    if (_sync) _metronome.stop();
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    // A dispose racing a load can throw inside just_audio; nothing to recover.
    unawaited(_player.dispose().catchError((Object _) {}));
    final title = _title.text.trim();
    if (_editableAtOpen && title != (_entry.title ?? '')) {
      unawaited(
        _saveOnClose(_entry.copyWith(title: title)).catchError((Object _) {}),
      );
    }
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
          if (_url != updated.attachmentIds.firstOrNull) _mapCandidate = null;
          _entry = updated;
          _selection = null;
          _focus = null;
          _undoRegions = null;
          _songMapCutMs = null;
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
    int? cutMs,
  }) async {
    if (!_canEdit) return;
    setState(() {
      _songMapCutMs = cutMs;
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

  /// Points the player at [start, end) of the song: a WAV slice where the
  /// platform can cut one (loops sample-exact, no gap at the seam),
  /// otherwise a clip of the song file.
  Future<void> _loopSource(int start, int end) async {
    final path = _songPath;
    final wav = path == null ? null : await loopWav(path, start, end);
    if (wav != null) {
      await _player.setFilePath(wav);
      _onLoopWav = true;
      return;
    }
    if (_onLoopWav) await _wholeSongSource();
    await _player.setClip(
      start: Duration(milliseconds: start),
      end: Duration(milliseconds: end),
    );
  }

  Future<void> _wholeSongSource() async {
    if (!_onLoopWav) {
      await _player.setClip();
      return;
    }
    _onLoopWav = false;
    final path = _songPath;
    if (path == null) {
      await _player.setUrl(_entry.attachmentIds.first);
    } else {
      await _player.setFilePath(path);
    }
  }

  /// While a loop plays, a new one waits for the end of the current pass,
  /// like a launchpad block: it is queued as the playlist's next item and the
  /// current one stops repeating, so the switch is gapless and in time.
  /// False when it can't be queued (the caller switches straight away).
  Future<bool> _queueLoop((int, int) span) async {
    final path = _songPath;
    final wav = path == null ? null : await loopWav(path, span.$1, span.$2);
    if (wav == null || !mounted) return false;
    // A newer tap replaces the one waiting.
    while (_player.sequence.length > 1) {
      await _player.removeAudioSourceAt(_player.sequence.length - 1);
    }
    await _player.addAudioSource(AudioSource.file(wav));
    await _player.setLoopMode(LoopMode.off);
    if (mounted) setState(() => _pendingLoop = span);
    return true;
  }

  Future<void> _cancelQueuedLoop() async {
    while (_player.sequence.length > 1) {
      await _player.removeAudioSourceAt(_player.sequence.length - 1);
    }
    await _player.setLoopMode(_audioLoopMode);
    if (mounted) setState(() => _pendingLoop = null);
  }

  /// The queued loop took over: it repeats now, and the old one leaves the
  /// playlist.
  void _onLoopIndex(int? index) {
    final pending = _pendingLoop;
    if (index == null || index == 0 || pending == null) return;
    setState(() {
      _pendingLoop = null;
      _clipStart = pending.$1;
      _clipEnd = pending.$2;
      _lastPosMs = 0;
      _position = Duration.zero;
    });
    _loopUpdate = _loopUpdate.then((_) async {
      await _player.setLoopMode(_audioLoopMode);
      await _player.removeAudioSourceAt(0);
    });
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
    if (span != null && span.$1 == _clipStart && span.$2 == _clipEnd) {
      // Back to the playing loop before the switch: keep it.
      if (_pendingLoop != null) await _cancelQueuedLoop();
      return;
    }
    final wasPlaying = _player.playing;
    if (span != null && wasPlaying && _onLoopWav && await _queueLoop(span)) {
      return;
    }
    if (_pendingLoop != null) setState(() => _pendingLoop = null);
    // Leaving a loop keeps playing from where the loop was, not the top.
    final resume = Duration(milliseconds: _positionMs);
    _changingClip = true;
    try {
      if (wasPlaying) await _player.pause();
      if (!mounted) return;
      if (span == null) {
        await _wholeSongSource();
      } else {
        await _loopSource(span.$1, span.$2);
      }
      if (!mounted) return;
      await _player.setLoopMode(_audioLoopMode);
      if (!mounted) return;
      final target = span == null ? resume : Duration.zero;
      await _player.seek(target);
      if (!mounted) return;
      setState(() {
        _clipStart = span?.$1 ?? 0;
        _clipEnd = span?.$2;
        _position = target;
        _lastPosMs = target.inMilliseconds;
      });
      if (wasPlaying) unawaited(_player.play());
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, "Couldn't set loop: $e", error: true);
      }
    } finally {
      _changingClip = false;
      if (mounted) setState(() => _playing = _player.playing);
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
    setState(() {
      _songMap?.overviewSelection = null;
      _selection = selection;
    });
    if (_sync) _syncLaunch(startIfStopped: false);
    unawaited(_applyLoop());
  }

  LoopMode get _audioLoopMode =>
      (_loopEnabled ?? (_selection != null)) ? LoopMode.one : LoopMode.off;

  PlayMode get _syncLoopMode =>
      _loopEnabled == false ? PlayMode.once : PlayMode.loop;

  void _setLoopEnabled(bool enabled) {
    setState(() => _loopEnabled = enabled);
    if (_sync) {
      ref.read(backingTransportProvider.notifier).setMode(_syncLoopMode);
    }
    _loopUpdate = _loopUpdate.then((_) async {
      if (mounted && _pendingLoop == null) {
        await _player.setLoopMode(_audioLoopMode);
      }
    });
  }

  void _setPreRoll(int value) {
    setState(() => _preRoll = value);
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
      ..setMode(_syncLoopMode);
    if (ref.read(metronomeProvider).isPlaying || startIfStopped) {
      unawaited(transport.launch(_syncTarget));
    }
  }

  Future<void> _setSync(bool on, {bool withDrums = true}) async {
    final grid = _entry.grid;
    if (!on || grid == null) {
      _flushSession();
      _metronome.stop();
      setState(() => _sync = false);
      return;
    }
    if (_preparingSync || _stretched) return;
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
      final drums = withDrums ? await _songDrums() : null;
      if (!mounted || _entry.grid != grid || _stretched) return;
      await transport.attachAudio(
        audio: alignToDownbeat(pcm, _syncGrid.offsetMs, rate),
        spans: _syncSpans(),
        drums: drums,
      );
      if (!mounted || _entry.grid != grid || _stretched) return;
      setState(() {
        _sync = true;
        _withDrums = withDrums;
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

  Song? _song() {
    if (_entry.songId.isEmpty || _entry.songId == '_inbox') return null;
    final songs = ref
        .read(
          widget.bandId == null
              ? songsProvider
              : bandSongsProvider(widget.bandId!),
        )
        .value;
    return songs?.where((s) => s.id == _entry.songId).firstOrNull;
  }

  /// The song page's BPM, which picks the detected tempo's octave.
  double? _songBpm() {
    final song = _song();
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
    final wasPlaying = _playing;
    await _loopUpdate;
    if (!mounted) return;
    if (wasPlaying) {
      await _player.pause();
    } else {
      if (_loopEnabled != null && _player.loopMode != _audioLoopMode) {
        if (_pendingLoop == null) await _player.setLoopMode(_audioLoopMode);
        if (!mounted) return;
      }
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
      final url = _url;
      if (url == null) return null;
      final duration = _durationMs;
      try {
        final path = _songPath;
        Future<Int16List?> decode() async {
          final bytes = await _readAudioBytes();
          if (!mounted || _url != url) return null;
          return PracticeRegionsScreen.decodePcm(
            bytes,
            sampleRate: 22050,
            durationMs: duration,
          );
        }

        final pcm = await cachedPcm22k(
          path == null ? null : File(path),
          decode,
        );
        if (!mounted || _url != url) return null;
        if (pcm != null && pcm.isNotEmpty) {
          setState(() => _analysisPcm = pcm);
        }
        return pcm;
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
      songSections: () => _song()?.sections.length ?? 0,
      durationMs: () => _durationMs,
      snap: () => _snap,
      time: _time,
    );
    if (!mounted || !_canEdit || result == null) return;
    if (result is AudioGrid) {
      await _setGrid(result);
    } else if (result is List<int> || result is List<AudioRegion>) {
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
        result is List<AudioRegion>
            ? [
                for (final region in result)
                  AudioRegion(
                    id: '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
                    name: region.name,
                    section: region.section,
                    startMs: region.startMs,
                    endMs: region.endMs,
                  ),
              ]
            : regionsFromCuts(
                result as List<int>,
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
    setState(() => _speed = 1);
    await _applyTempoSpeed();
    if (!mounted) return;
    await _seekTo(ms - preRollMs);
    if (!mounted) return;
    unawaited(_player.play());
    _auditionTimer = Timer(
      Duration(milliseconds: (windowMs / _stretchFactor).round()),
      () {
        if (mounted) unawaited(_player.pause());
      },
    );
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
    _pendingLoop = null;
    if (_sync) await _setSync(false);
    if (!mounted) return;
    _flushSession();
    setState(() => _selection = null);
    await (_loopUpdate = _loopUpdate.then((_) async {
      if (!mounted || !_loaded) return;
      _changingClip = true;
      try {
        await _player.pause();
        await _loopSource(startMs, endMs);
        await _player.setLoopMode(LoopMode.one);
        if (!mounted) return;
        final length = endMs - startMs;
        final seam = length > 2 * _seamMs ? (_seamMs, length - _seamMs) : null;
        final target = Duration(milliseconds: seam?.$2 ?? 0);
        await _player.seek(target);
        if (!mounted) return;
        setState(() {
          _clipStart = startMs;
          _clipEnd = endMs;
          _position = target;
          _lastPosMs = target.inMilliseconds;
          _seam = seam;
        });
        unawaited(_player.play());
      } catch (_) {
        // Fine-tuning still works without the preview.
      } finally {
        _changingClip = false;
        if (mounted) setState(() => _playing = _player.playing);
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

  Future<void> _renameSection(String occurrenceId) async {
    if (!_canEdit) return;
    final view = _songMap!;
    final index = view.sections.indexWhere((s) => s.id == occurrenceId);
    if (index < 0) return;
    final firstPartId = view.regions[view.sectionRange(index).$1].id;
    final groups = <String, SongMapLetter>{};
    final seen = <String>{};
    for (final (index, section) in view.sections.indexed) {
      final name = songMapGroupName(section.name);
      if (name.isNotEmpty && seen.add(name.toLowerCase())) {
        groups[name] = view.sectionLetter(index);
      }
    }
    final result = await showSectionNameSheet(
      context,
      initialName: songMapGroupName(view.sections[index].name),
      groups: groups,
    );
    if (!mounted || !_canEdit || result == null) return;

    final allSections = SongMapView(
      regions: _entry.regions,
      durationMs: _durationMs,
      includeSkipped: true,
    );
    final updated = song_map_edit.editSectionName(
      allSections,
      occurrenceId: firstPartId,
      name: result.name,
      move: result.move,
    );
    allSections.dispose();
    if (!identical(updated, _entry.regions)) await _changeRegions(updated);
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
    await _applyTempoSpeed();
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

  String _name(AudioRegion region) {
    if (region.name.isNotEmpty) return region.name;
    final regions = _entry.regions;
    final index = regions.indexOf(region);
    final view = _songMap;
    if (view != null && identical(view.regions, regions)) {
      for (final (i, child) in view.children().indexed) {
        final (start, end) = view.regionRange(i);
        if (index >= start && index <= end) return songMapRegionName(child, i);
      }
    }
    return songMapRegionName(region, index);
  }

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

  int _barNumber(AudioGrid grid, int ms) =>
      (grid.barAt(ms) + 0.5 / grid.barMs).floor() + 1;

  void _chop(SongMapView view, AudioGrid grid, int position, bool remove) {
    if (!_canEdit) return;
    final regions = _entry.regions;
    final section = view.sectionIndex;
    var cut = view.level == SongMapZoom.part
        ? view.snapMs(position)
        : grid.snap(position, durationMs: view.durationMs);
    List<AudioRegion> updated;
    if (remove) {
      int? nearest;
      final count = view.children().length;
      for (var i = 0; i + 1 < count; i++) {
        final (_, end) = view.regionRange(i);
        final ms = regions[end].endMs;
        if (ms != regions[end + 1].startMs) continue;
        if (nearest == null || (ms - position).abs() < (cut - position).abs()) {
          nearest = end;
          cut = ms;
        }
      }
      if (nearest == null) return;
      updated = song_map_edit.deleteBoundary(
        regions,
        nearest,
        grid: grid,
        withinSection: section != null,
      );
    } else {
      if (section != null) {
        final span = view.sections[section];
        if (cut <= span.startMs || cut >= span.endMs) return;
      }
      updated = song_map_edit.splitAt(
        regions,
        cut,
        grid: grid,
        withinSection: section != null,
      );
    }
    if (identical(updated, regions)) return;
    if (!remove && section == null) {
      view.overviewSelection = view.sections.indexWhere(
        (span) => span.startMs < cut && cut < span.endMs,
      );
      if (view.overviewSelection == -1) view.overviewSelection = null;
    }
    _songMapBoundaryMs = null;
    final bar = _barNumber(grid, cut);
    final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
    final notice = messenger.showSnackBar(
      SnackBar(
        content: Text('${remove ? 'Removed cut' : 'Cut'} at bar $bar'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (mounted && identical(_entry.regions, updated)) {
              unawaited(_undo());
            }
          },
        ),
      ),
    );
    unawaited(_changeRegions(updated, cutMs: remove ? null : cut));
    if (!remove) {
      unawaited(
        notice.closed.then((_) {
          if (mounted && identical(_entry.regions, updated)) {
            setState(() => _songMapCutMs = null);
          }
        }),
      );
    }
  }

  Widget _pads({
    required bool editing,
    required int position,
    required bool playing,
    required Widget? banner,
    required SongMapTempoBanner? tempoBanner,
    Widget? emptyContent,
  }) {
    final regions = _entry.regions;
    final candidate = _canEdit ? _mapCandidate : null;
    final preview = candidate != null && regions.isEmpty;
    final mapRegions = preview ? candidate.regions : regions;
    final grid = _entry.grid;
    final mapGrid = preview ? candidate.grid : grid;
    final duration = _durationMs > 0
        ? _durationMs
        : mapRegions.lastOrNull?.endMs ?? 0;
    final previous = _songMap;
    if (previous == null ||
        previous.regions != mapRegions ||
        previous.grid != mapGrid ||
        previous.durationMs != duration ||
        previous.includeSkipped != editing) {
      final view = SongMapView(
        regions: mapRegions,
        grid: mapGrid,
        durationMs: duration,
        includeSkipped: editing,
      );
      if (previous != null) {
        view.restoreZoom(previous);
        previous.dispose();
      }
      _songMap = view;
    }
    final view = _songMap!;
    if (emptyContent == null &&
        view.sections.isNotEmpty &&
        _loaded &&
        !_busy &&
        _durationMs > 0 &&
        _analysisPcmLoad == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _songMap == view) unawaited(_ensurePcm());
      });
    }
    final queuedId = _sync
        ? ref.watch(backingTransportProvider.select((t) => t.queuedId))
        : null;
    final selection = _selection;
    final canEditMap =
        candidate == null && editing && grid != null && _durationMs > 0;
    final canChop =
        _canEdit &&
        candidate == null &&
        _loaded &&
        _durationMs > 0 &&
        grid != null &&
        grid.barMs.isFinite &&
        grid.barMs >= 1 &&
        grid.beatsPerBar > 0;
    final candidateCuts = {...?candidate?.boundaries, ?_songMapCutMs};
    final boundaries = {
      if (editing && candidate == null)
        for (var i = 0; i + 1 < regions.length; i++)
          if (regions[i].endMs == regions[i + 1].startMs) regions[i].endMs: i,
    };
    final boundary = boundaries.containsKey(_songMapBoundaryMs)
        ? _songMapBoundaryMs
        : null;

    int snap(int ms) => view.level == SongMapZoom.part
        ? view.snapMs(ms)
        : grid!.snap(ms, durationMs: duration);

    void saveEdit(List<AudioRegion> updated, {int? selectedBoundary}) {
      if (identical(updated, regions)) return;
      _songMapBoundaryMs = selectedBoundary;
      unawaited(_changeRegions(updated));
    }

    return ListenableBuilder(
      listenable: view,
      builder: (context, _) {
        final children = view.children();
        final atSong = view.level == SongMapZoom.song;
        final overviewSelection = view.overviewSelection;
        final selectedSections = {?overviewSelection};
        int? editedSection;
        for (var i = 0; i < view.sections.length; i++) {
          final (start, end) = view.sectionRange(i);
          if (overviewSelection == null &&
              selection != null &&
              start <= selection.$2 &&
              end >= selection.$1) {
            selectedSections.add(i);
          }
          final focus = _focus;
          if (editing && focus != null && start <= focus && focus <= end) {
            editedSection = i;
          }
        }
        final positionSection = view.sections.indexWhere(
          (r) => r.startMs <= position && position < r.endMs,
        );
        final cursorSection = positionSection < 0 ? null : positionSection;
        final focusSection =
            editedSection ??
            overviewSelection ??
            (playing ? cursorSection : null) ??
            selectedSections.firstOrNull ??
            cursorSection;
        Widget overview([double waveHeight = SongMapTimeline.waveformHeight]) =>
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MonoPulseSpacing.sm,
              ),
              child: SongMapOverview(
                waveHeight: waveHeight,
                entry: _entry,
                view: view,
                positionMs: position,
                playing: playing,
                selectedIndices: selectedSections,
                focusSection: focusSection,
                candidateBoundariesMs: candidateCuts,
                preview: preview,
                onSectionHold: _canEdit && !preview ? _renameSection : null,
                onSectionTap: (i) {
                  setState(() => view.overviewSelection = i);
                },
                onSeek: _loaded && _durationMs > 0
                    ? (ms) => unawaited(_seekTimeline(ms))
                    : null,
                noteTicks: CustomPaint(
                  key: const ValueKey('note-ticks'),
                  painter: _NoteTicksPainter(
                    markers: entryNotes(_entry),
                    viewStart: 0,
                    viewEnd: duration,
                  ),
                ),
              ),
            );
        if (emptyContent != null) {
          return Column(
            children: [
              overview(),
              Expanded(child: emptyContent),
            ],
          );
        }
        final selected = <int>{};
        if (selection != null) {
          for (var i = 0; i < children.length; i++) {
            final (start, end) = view.regionRange(i);
            if (start <= selection.$2 && end >= selection.$1) selected.add(i);
          }
        }
        final active = playing
            ? children.indexWhere(
                (r) => r.startMs <= position && position < r.endMs,
              )
            : -1;
        final queued =
            selection != null &&
            (_sync
                ? queuedId == _syncTarget
                : _pendingLoop ==
                      loopSpan(regions, selection, preRollMs: _preRollMs));

        void selectRange((int, int) range) {
          _selectRegions((
            view.regionRange(range.$1).$1,
            view.regionRange(range.$2).$2,
          ));
        }

        final pads = SongMapPads(
          key: ValueKey((view, view.sectionIndex, view.partIndex)),
          view: view,
          showChop: _canEdit,
          chopLit: _songMapCutMs != null,
          onChop: canChop
              ? (remove) => _chop(view, grid, position, remove)
              : null,
          selectedIndices: selected,
          playingIndex: active < 0 ? null : active,
          queuedIndex: queued ? selected.firstOrNull : null,
          progress: active < 0
              ? 0
              : (position - children[active].startMs) /
                    children[active].lengthMs,
          onRange: editing || preview ? null : selectRange,
          onHold: preview
              ? null
              : (i) {
                  final (start, end) = view.regionRange(i);
                  if (_canEdit) {
                    if (atSong) {
                      unawaited(_renameSection(children[i].id));
                    } else {
                      unawaited(_rename(children[i].id));
                    }
                  } else if (!editing && selection != null) {
                    _selectRegions((
                      math.min(start, selection.$1),
                      math.max(end, selection.$2),
                    ));
                  }
                },
          onSelect: (i) {
            if (preview) {
              setState(() => view.overviewSelection = view.sectionIndex ?? i);
              unawaited(_seekTimeline(children[i].startMs));
              return;
            }
            final range = view.regionRange(i);
            if (editing && (!atSong || regions[range.$1].section == null)) {
              setState(() => _focus = range.$1);
              unawaited(_editSlice(range.$1));
            } else {
              _selectRegions(selection == range ? null : range);
            }
          },
        );
        Widget timeline(double waveformHeight) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm),
          child: SongMapTimeline(
            key: const ValueKey('song-map-zoom'),
            waveHeight: waveformHeight,
            view: view,
            focusSection: focusSection,
            peaks: _entry.peaks,
            pcm: _analysisPcm,
            positionMs: position,
            playing: playing,
            candidateBoundariesMs: candidateCuts,
            preview: preview,
            cutLabel: _songMapCutMs == null || grid == null
                ? null
                : (_songMapCutMs!, 'bar ${_barNumber(grid, _songMapCutMs!)}'),
            selectedIndices: atSong ? const {} : selected,
            boundariesMs: editing ? boundaries.keys.toSet() : null,
            selectedBoundaryMs: boundary,
            editableBoundaries: boundaries,
            onFineTune: _fineTune,
            onBoundaryTap: canEditMap
                ? (ms) => setState(() => _songMapBoundaryMs = ms)
                : null,
            onBoundaryDrag: !editing || candidate != null
                ? null
                : (drag) {
                    final (from, to) = drag;
                    final index = boundaries[from];
                    if (index == null) return;
                    final cut = grid == null ? _snapped(to) : snap(to);
                    final updated =
                        grid == null || view.level == SongMapZoom.part
                        ? moveBoundary(regions, index, cut)
                        : song_map_edit.moveBoundary(
                            regions,
                            index,
                            cut,
                            grid: grid,
                          );
                    saveEdit(updated, selectedBoundary: cut);
                  },
          ),
        );
        return Column(
          children: [
            if (candidate == null) ...[
              ?banner,
              ?tempoBanner,
            ] else ...[
              ?tempoBanner,
              ?banner,
            ],
            Expanded(
              child: LayoutBuilder(
                key: ValueKey((
                  view.sectionIndex,
                  view.partIndex,
                  banner != null || tempoBanner != null,
                  candidate != null,
                )),
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final rows =
                      mapRegions.length > SongMapPads.columnsForWidth(width)
                      ? 2
                      : 1;
                  final fullHeight =
                      _mapHeightForPads(width, rows) +
                      SongMapTimeline.zoomHeight +
                      (view.level == SongMapZoom.part
                          ? MonoPulseSpacing.xxxl
                          : 0);
                  const normalWaveHeight = SongMapTimeline.waveformHeight;
                  final deficit = math.max<double>(
                    0,
                    fullHeight - constraints.maxHeight,
                  );
                  // Compress the overview first to keep the editable waveform tall.
                  final overviewReduction = math.min(
                    deficit,
                    normalWaveHeight - _minMapWaveformHeight,
                  );
                  final zoomHeight = math.max(
                    _minMapWaveformHeight,
                    normalWaveHeight - (deficit - overviewReduction),
                  );
                  return Column(
                    children: [
                      overview(normalWaveHeight - overviewReduction),
                      timeline(zoomHeight),
                      Flexible(child: pads),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  bool get _canAnalyze => _loaded && _durationMs > 0 && !_analyzing;

  Future<void> _analyze() async {
    if (!_canEdit || !_canAnalyze || _busy) return;
    final url = _url;
    final duration = _durationMs;
    setState(() {
      _showAnalyzePrompt = false;
      _analyzing = true;
    });
    try {
      final pcm = await _ensurePcm();
      if (!mounted || !_canEdit || _url != url) return;
      if (pcm == null || pcm.isEmpty) throw StateError('Missing audio');
      final result = await compute(_analyseSongRequest, (
        pcm,
        duration,
        _songBpm(),
        _entry.grid,
        _song()?.sections.length ?? 0,
      ));
      if (!mounted || !_canEdit || _url != url) return;
      final (:grid, :structure, :cuts) = result;
      if (grid == null && cuts.isEmpty) throw StateError('Missing structure');
      String newId() =>
          '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
      final regions = structure == null
          ? regionsFromCuts(cuts, durationMs: duration, newId: newId)
          : regionsFromStructure(structure, newId: newId);
      final boundaries = structure == null
          ? regions.skip(1).map((region) => region.startMs).toSet()
          : structure.sections
                .skip(1)
                .map((section) => section.startMs)
                .toSet();
      while (_songMap != null && _songMap!.level != SongMapZoom.song) {
        _songMap!.zoomOut();
      }
      setState(
        () => _mapCandidate = (
          grid: grid,
          regions: regions,
          boundaries: boundaries,
        ),
      );
      await _applyTempoSpeed();
    } catch (_) {
      if (mounted && _url == url && _canEdit) {
        showAppSnackBar(
          context,
          'Could not analyze this song.',
          actionLabel: 'Manual setup',
          onAction: _manualSetup,
        );
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _useCandidate() async {
    final candidate = _mapCandidate;
    if (candidate == null || !_canEdit || _busy) return;
    final oldGrid = _entry.grid;
    final oldRegions = _entry.regions;
    setState(() => _busy = true);
    try {
      await _save(
        _entry.copyWith(grid: candidate.grid, regions: candidate.regions),
        requireSuccess: true,
      );
      if (!mounted) return;
      if (_sync) await _setSync(false);
      if (!mounted) return;
      setState(() {
        _mapCandidate = null;
        _songMapBoundaryMs = null;
        _undoRegions = oldRegions;
        if (oldGrid == null && candidate.grid != null) {
          _preRoll = 0;
          _snap = true;
        }
      });
      await _applyTempoSpeed();
      await _applyLoop();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, "Couldn't use new map: $e", error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leaveWithCandidate(Object? result) async {
    if (_mapCandidate == null || _busy || _candidateExitOpen) return;
    _candidateExitOpen = true;
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save the new section map?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: _canEdit ? () => Navigator.pop(context, true) : null,
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (!mounted || save == null) return;
      if (save) {
        await _useCandidate();
        if (!mounted || _mapCandidate != null) return;
      }
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(result);
      }
    } finally {
      _candidateExitOpen = false;
    }
  }

  Widget? _analyzeBanner() {
    final candidate = _mapCandidate;
    if (!_showAnalyzePrompt && !_analyzing && candidate == null) return null;
    final replacing = _entry.regions.isNotEmpty;
    return MaterialBanner(
      content: Text(
        candidate == null
            ? (_analyzing ? 'Analyzing song…' : 'Analyze song')
            : replacing
            ? 'New map'
            : '${candidate.boundaries.length + 1} sections found · check, then Done',
      ),
      actions: [
        if (!_analyzing && candidate == null && !replacing)
          TextButton(
            onPressed: () => setState(() {
              _showAnalyzePrompt = false;
              _editing = true;
            }),
            child: const Text('Set up sections'),
          ),
        if (!_analyzing || candidate != null)
          TextButton(
            onPressed: _busy || _analyzing
                ? null
                : () {
                    setState(() {
                      _showAnalyzePrompt = false;
                      _mapCandidate = null;
                    });
                    unawaited(_applyTempoSpeed());
                  },
            child: Text(candidate == null ? 'Dismiss' : 'Discard'),
          ),
        FilledButton(
          onPressed: _analyzing || _busy
              ? null
              : candidate == null
              ? _analyze
              : _useCandidate,
          child: Text(candidate == null ? 'Analyze' : 'Done'),
        ),
      ],
    );
  }

  // Recover embedded markers or mark by ear if analysis couldn't make a map.
  Future<void> _manualSetup() async {
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
        findSections: (grid) async {
          final pcm = await _ensurePcm();
          return pcm == null || pcm.isEmpty
              ? const []
              : sectionCuts(pcm, 22050, grid: grid);
        },
        findStructure: (grid) async {
          final pcm = await _ensurePcm();
          return pcm == null || pcm.isEmpty
              ? null
              : compute(analyseStructureRequest, (pcm, grid));
        },
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
        if (mounted) {
          setState(() {
            _editing = true;
          });
        }
      }
    } finally {
      _setupOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref
        .watch(
          widget.bandId == null
              ? songsProvider
              : bandSongsProvider(widget.bandId!),
        )
        .value;
    final song = songs?.where((song) => song.id == _entry.songId).firstOrNull;
    if (song != null && song.title.trim().isNotEmpty) {
      _sessionSongTitle = song.title;
    }
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
    final analyzeBanner = canEdit || _mapCandidate != null
        ? _analyzeBanner()
        : null;
    final measuredBpm = _measuredBpm;
    final stretchTarget = songMapStretchTarget(measuredBpm);
    final tempoBanner =
        _loaded && _stretchTempo == null && stretchTarget != null
        ? SongMapTempoBanner(
            measuredBpm: measuredBpm!,
            onStretch: () => _chooseTempo(true),
            onKeep: () => _chooseTempo(false),
          )
        : null;
    final displayedBpm = _stretched ? stretchTarget : measuredBpm;
    final notes = entryNotes(_entry);
    final showPads = regions.isNotEmpty || (_canEdit && _mapCandidate != null);
    final canPlay = _loaded && _durationMs > 0 && !_busy && !_preparingSync;
    final canClick = !_stretched && canSyncToClick(grid) && canPlay;
    final speedPercent = (_speed * 100).round();
    final mapContent = _pads(
      editing: editing,
      position: positionMs,
      playing: playing,
      banner: analyzeBanner,
      tempoBanner: tempoBanner,
      emptyContent: showPads
          ? null
          : Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No sections yet'),
                    if (analyzeBanner != null)
                      analyzeBanner
                    else if (canEdit)
                      FilledButton(
                        onPressed: _canAnalyze
                            ? () => setState(() => _showAnalyzePrompt = true)
                            : null,
                        child: const Text('Analyze song'),
                      ),
                    ?tempoBanner,
                  ],
                ),
              ),
            ),
    );
    final scaffold = Scaffold(
      backgroundColor: context.mp.black,
      bottomNavigationBar: SongMapTransport(
        playing: playing,
        playLabel: playing
            ? 'Pause'
            : _speed == 1
            ? 'Play'
            : 'Play $speedPercent%',
        speedPercent: speedPercent,
        loop: _loopEnabled ?? (_sync || selection != null),
        countIn: _sync
            ? ref.watch(metronomeProvider.select((m) => m.countInBars)) > 0
            : _preRoll > 0,
        click: _sync && !_withDrums,
        clickAndDrums: _sync && _withDrums,
        stretched: _stretched,
        onPlay: canPlay ? _togglePlay : null,
        onStop: canPlay ? _togglePlay : null,
        onPlayLongPress: _playbackOptions,
        onSpeedTap: _busy ? null : _playbackOptions,
        onLoopChanged: canPlay ? _setLoopEnabled : null,
        onCountInChanged: _busy
            ? null
            : (value) {
                if (_sync) {
                  _metronome.setCountInBars(value ? 1 : 0);
                } else {
                  _setPreRoll(value ? 1 : 0);
                }
              },
        onClickChanged: canClick
            ? (value) => _setSync(value, withDrums: false)
            : null,
        onClickAndDrumsChanged: canClick ? _setSync : null,
        clickUnavailableReason: _clickUnavailableReason(grid),
      ),
      appBar: AppBar(
        titleTextStyle:
            (AppBarTheme.of(context).titleTextStyle ??
                    MonoPulseTypography.headlineLarge)
                .copyWith(color: context.mp.textPrimary),
        title: canEdit
            ? _editableTitle()
            : Text(
                _entry.title ?? 'Practice regions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        // Below the bar, not as the title field's helper: that made the field
        // taller than the toolbar and clipped the title.
        bottom: editing
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Text(
                  'Tap a pad to edit',
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: context.mp.textSecondary,
                  ),
                ),
              )
            : null,
        actions: [
          if (displayedBpm != null && displayedBpm.isFinite && displayedBpm > 0)
            Chip(
              label: Text(
                '${displayedBpm % 1 == 0 ? displayedBpm.toInt().toString() : displayedBpm} BPM',
              ),
              backgroundColor: stretchTarget != null && !_stretched
                  ? MonoPulseColors.warning5
                  : context.mp.surfaceRaised,
              visualDensity: VisualDensity.compact,
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
                case 'edit':
                  setState(() {
                    _editing = !_editing;
                    _focus = null;
                  });
                case 'marker':
                  unawaited(_addMarker());
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
                case 'analyze':
                  setState(() => _showAnalyzePrompt = true);
              }
            },
            enabled: !_busy && !_analyzing,
            itemBuilder: (_) => [
              if (canEdit)
                PopupMenuItem(
                  key: const ValueKey('shift'),
                  value: 'edit',
                  child: Tooltip(
                    message: 'Edit',
                    child: Semantics(
                      selected: editing,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Edit'),
                          if (editing) const Icon(Icons.done),
                        ],
                      ),
                    ),
                  ),
                ),
              if (editing)
                PopupMenuItem(
                  key: const ValueKey('add-marker'),
                  value: 'marker',
                  enabled: _loaded && _durationMs >= 2 * minRegionMs,
                  child: const Tooltip(
                    message: 'Add marker',
                    child: Text('Add marker'),
                  ),
                ),
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
                  key: ValueKey('add-note'),
                  value: 'note',
                  child: Tooltip(
                    message: 'Note',
                    child: Text('Add note at playhead', semanticsLabel: 'Note'),
                  ),
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
                  value: 'analyze',
                  enabled: _canAnalyze && _mapCandidate == null,
                  child: const Text('Analyze song'),
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
              if (editing &&
                  regions.any(
                    (region) => region.name.isEmpty || _isShort(region),
                  ))
                _nameChips(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final rows =
                        (_mapCandidate?.regions.length ?? regions.length) >
                            SongMapPads.columnsForWidth(width)
                        ? 2
                        : 1;
                    final padBudget = showPads
                        ? _mapHeightForPads(width, rows) +
                              (analyzeBanner == null ? 0 : 120) +
                              (tempoBanner == null
                                  ? 0
                                  : SongMapTempoBanner.height)
                        : 0.0;
                    final available = constraints.maxHeight;
                    final zoomBudget = showPads ? _zoomBudget : 0.0;
                    final notesRoom = available - padBudget - zoomBudget;
                    final compactNotesRoom =
                        notesRoom +
                        (showPads
                            ? 2 *
                                  (SongMapTimeline.waveformHeight -
                                      _minMapWaveformHeight)
                            : 0);
                    final notesHeight = math.min(
                      MediaQuery.sizeOf(context).height * 0.3,
                      math.max(
                        notesRoom,
                        math.min(
                          available - padBudget,
                          compactNotesRoom
                              .clamp(MonoPulseSpacing.massive, 96)
                              .toDouble(),
                        ),
                      ),
                    );
                    final notesFit =
                        (notes.length + 1) * MonoPulseSpacing.massive <=
                        (rows == 1
                            ? notesHeight
                            : math.min(notesRoom, notesHeight));
                    final expanded = _notesExpanded ?? notesFit;
                    return Column(
                      children: [
                        Expanded(child: mapContent),
                        if (notes.isEmpty && notesHeight >= 48)
                          _emptyNotes(positionMs, canEdit: canEdit)
                        else if (notes.isNotEmpty && available >= 48)
                          if (!expanded || notesHeight < 48)
                            _collapsedNotes(notes.length)
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: notesHeight,
                                    ),
                                    child: _NotesPanel(
                                      markers: notes,
                                      positionMs: positionMs,
                                      onSeek: _seekNote,
                                      onAdd: canEdit
                                          ? _addMarkerAtPlayhead
                                          : null,
                                      onDelete: canEdit ? _deleteMarker : null,
                                    ),
                                  ),
                                ),
                                if (_notesExpanded == true)
                                  IconButton(
                                    tooltip: 'Collapse notes',
                                    onPressed: () =>
                                        setState(() => _notesExpanded = false),
                                    icon: const Icon(Icons.expand_less),
                                  ),
                              ],
                            ),
                      ],
                    );
                  },
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
                          '${_pendingLoop == null ? 'Looping' : 'Next:'} ${_name(regions[selection.$1])}'
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
            ],
          ),
        ),
      ),
    );
    return PopScope(
      canPop: _mapCandidate == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leaveWithCandidate(result));
      },
      child: scaffold,
    );
  }

  static const _minMapWaveformHeight = MonoPulseSpacing.sm;

  double get _zoomBudget => SongMapTimeline.zoomHeight + MonoPulseSpacing.xxxl;

  double _mapHeightForPads(double width, int rows) =>
      SongMapOverview.height +
      (_entry.peaks.isEmpty ? 84 : 0) +
      SongMapPads.heightForRows(context, rows, width);

  Widget _editableTitle() {
    const key = ValueKey('recording-title');
    final style = MonoPulseTypography.titleLarge.copyWith(
      color: context.mp.textPrimary,
    );
    if (!_editingTitle) {
      return InkWell(
        key: key,
        onTap: () => setState(() => _editingTitle = true),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            _title.text.isEmpty ? 'Practice regions' : _title.text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return TextField(
      key: key,
      autofocus: true,
      controller: _title,
      focusNode: _titleFocus,
      style: style,
      decoration: const InputDecoration(
        hintText: 'Practice regions',
        border: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
      onSubmitted: (_) => _saveTitle(),
      onTapOutside: (_) => _titleFocus.unfocus(),
    );
  }

  Widget _collapsedNotes(int count) => ListTile(
    key: const ValueKey('recording-notes'),
    minTileHeight: MonoPulseSpacing.massive,
    title: Text('Notes · $count', style: MonoPulseTypography.titleMedium),
    trailing: const Icon(Icons.expand_more),
    onTap: () => setState(() => _notesExpanded = true),
  );

  Widget _emptyNotes(int positionMs, {required bool canEdit}) => Padding(
    key: const ValueKey('recording-notes'),
    padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Notes', style: MonoPulseTypography.titleMedium),
        if (canEdit)
          Tooltip(
            message:
                'No notes yet. Play the take and drop one where something '
                'happens — tap it later to jump straight back.',
            child: TextButton.icon(
              onPressed: _addMarkerAtPlayhead,
              icon: const Icon(Icons.add, size: 18),
              label: Text('at ${_time(positionMs)}'),
            ),
          ),
      ],
    ),
  );

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
                  backgroundColor: _songMap?.letters
                      .forSectionName(name)
                      ?.color,
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

  String? _clickUnavailableReason(AudioGrid? grid) => _stretched
      ? 'Click & drums is unavailable while audio is stretched'
      : !canSyncToClick(grid)
      ? 'Needs a whole-number BPM grid'
      : !_loaded
      ? 'Loading the take…'
      : _preparingSync
      ? 'Preparing click & drums…'
      : null;

  /// Speed, pre-roll and click & drums in one sheet.
  Future<void> _playbackOptions() async {
    if (_busy) return;
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
                                unawaited(_applyTempoSpeed());
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
                          _setPreRoll(value);
                          sheetSetState(() {});
                        },
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Click & drums'),
                  subtitle: switch (_clickUnavailableReason(grid)) {
                    final reason? => Text(reason),
                    null => null,
                  },
                  value: _sync && _withDrums,
                  onChanged:
                      !_stretched &&
                          canSyncToClick(grid) &&
                          _loaded &&
                          !_preparingSync
                      ? (value) async {
                          // _setSync flags _preparingSync before its first
                          // await; repaint now so the wait is visible.
                          final pending = _setSync(value);
                          sheetSetState(() {});
                          await pending;
                          if (sheetContext.mounted) sheetSetState(() {});
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
