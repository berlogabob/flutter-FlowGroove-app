import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

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
import '../services/audio/audio_note_edit.dart';
import '../services/audio/song_peaks.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/play_mode.dart';
import '../utils/snackbar.dart';
import '../widgets/audio/waveform_painter.dart';
import '../widgets/tools/tool_scaffold.dart';

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

  /// Decoder for click & drums mode; tests swap it, since SoLoud's native
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
  late final AudioPlayer _player;
  final _subs = <StreamSubscription<dynamic>>[];
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _loaded = false;
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
  String? _drumsName;
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
      final bytes = await ref.read(audioBytesFetcherProvider)(
        _entry.attachmentIds.first,
      );
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
      final duration = await _player.setUrl(_entry.attachmentIds.first);
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
          setState(() => _position = position);
        }),
        _player.playerStateStream.listen((state) {
          if (!mounted) return;
          if (!_sync) _clock(state.playing);
          setState(() => _playing = state.playing);
        }),
      ]);
      await _applyLoop();
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

  Future<void> _changeRegions(List<AudioRegion> regions) async {
    if (!_canEdit) return;
    setState(() {
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
    _changingClip = true;
    try {
      if (selection == null) {
        await _player.setClip();
        if (!mounted) return;
        await _player.setLoopMode(LoopMode.off);
        if (!mounted) return;
        setState(() {
          _clipStart = 0;
          _clipEnd = null;
          _position = _player.position;
        });
      } else {
        final (start, end) = loopSpan(
          _entry.regions,
          selection,
          preRollMs: _preRollMs,
        );
        // Renames and edits outside the loop keep the same span: reloading
        // the clip would restart playback mid-pass.
        if (start == _clipStart && end == _clipEnd) return;
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
        await _player.seek(Duration.zero);
      }
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
      final bytes = await ref.read(audioBytesFetcherProvider)(
        _entry.attachmentIds.first,
      );
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
        _drumsName = drums?.name;
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

  Future<void> _split() async {
    if (!_canEdit) return;
    final at = _snapped(_positionMs);
    final regions = splitRegions(
      _entry.regions,
      atMs: at,
      durationMs: _durationMs,
      newId: () => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
    );
    if (identical(regions, _entry.regions)) return;
    final right = regions.firstWhere((region) => region.startMs == at);
    await _changeRegions(regions);
    if (mounted) await _rename(right.id);
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
            content: Column(
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
            actions: [
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
                      offsetMs: _entry.grid?.offsetMs ?? 0,
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
    return ToolScreenScaffold(
      title: 'Practice regions',
      mainWidget: ListView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        children: [
          _timeline(canEdit),
          const SizedBox(height: MonoPulseSpacing.md),
          Row(
            children: [
              IconButton(
                tooltip: playing ? 'Pause' : 'Play',
                iconSize: 48,
                icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                color: MonoPulseColors.accentOrange,
                onPressed: _loaded && _durationMs > 0 ? _togglePlay : null,
              ),
              Expanded(
                child: Text(
                  _sync
                      ? 'Bar ${syncBar + 1} · click & drums'
                      : '${_time(positionMs)} / ${_time(_durationMs)}',
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: context.mp.textSecondary,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: canEdit && _loaded && _durationMs >= 2 * minRegionMs
                    ? _split
                    : null,
                icon: const Icon(Icons.content_cut),
                label: const Text('Split'),
              ),
            ],
          ),
          for (var i = 0; i < regions.length; i++)
            ListTile(
              key: ValueKey(regions[i].id),
              title: Text(_name(regions[i])),
              subtitle: Text(
                '${_time(regions[i].startMs)}–${_time(regions[i].endMs)}'
                '${grid == null ? '' : ' · bars ${grid.barAt(regions[i].startMs).round() + 1}–${grid.barAt(regions[i].endMs).round() + 1}'}',
              ),
              selected:
                  selection != null && i >= selection.$1 && i <= selection.$2,
              selectedTileColor: MonoPulseColors.accentOrange.withValues(
                alpha: 0.18,
              ),
              onTap: () {
                _flushSession();
                setState(() => _selection = toggleSelection(_selection, i));
                if (_sync) _syncLaunch(startIfStopped: false);
                unawaited(_applyLoop());
              },
              trailing: canEdit
                  ? PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'rename') {
                          unawaited(_rename(regions[i].id));
                        } else {
                          unawaited(
                            _changeRegions(mergeRegion(_entry.regions, i)),
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove boundary'),
                        ),
                      ],
                    )
                  : null,
            ),
          const SizedBox(height: MonoPulseSpacing.md),
          Text(
            'Speed ${(_speed * 100).round()}%',
            style: MonoPulseTypography.titleMedium,
          ),
          Slider(
            value: _speed,
            min: 0.5,
            divisions: 10,
            label: '${(_speed * 100).round()}%',
            // The engine plays stems at their rendered tempo only.
            onChanged: _sync
                ? null
                : (value) {
                    setState(() => _speed = value);
                    unawaited(_player.setSpeed(value));
                  },
          ),
          const Text('Pre-roll'),
          Wrap(
            spacing: MonoPulseSpacing.sm,
            children: [
              for (final value in grid == null ? [0, 2, 4] : [0, 1, 2])
                ChoiceChip(
                  label: Text(grid == null ? '$value s' : '$value bars'),
                  selected: _preRoll == value,
                  onSelected: (_) {
                    setState(() => _preRoll = value);
                    unawaited(_applyLoop());
                  },
                ),
            ],
          ),
          if (selection != null)
            Text(
              'Looping ${_name(regions[selection.$1])}'
              '${selection.$1 == selection.$2 ? '' : ' → ${_name(regions[selection.$2])}'}',
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: MonoPulseColors.accentOrange,
              ),
            ),
          const SizedBox(height: MonoPulseSpacing.md),
          Card(
            color: context.mp.surface,
            child: Padding(
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tempo grid',
                    style: MonoPulseTypography.titleMedium,
                  ),
                  if (grid == null)
                    TextButton(
                      onPressed: canEdit ? _editGrid : null,
                      child: const Text('Set tempo grid'),
                    )
                  else ...[
                    Text('BPM ${grid.bpm} · ${grid.beatsPerBar}/4'),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: canEdit
                              ? () => _setGrid(
                                  grid.copyWith(
                                    offsetMs: (_positionMs % grid.barMs)
                                        .round(),
                                  ),
                                )
                              : null,
                          child: const Text('Downbeat here'),
                        ),
                        TextButton(
                          onPressed: canEdit
                              ? () => _setGrid(
                                  grid.copyWith(offsetMs: grid.offsetMs - 10),
                                )
                              : null,
                          child: const Text('-10 ms'),
                        ),
                        TextButton(
                          onPressed: canEdit
                              ? () => _setGrid(
                                  grid.copyWith(offsetMs: grid.offsetMs + 10),
                                )
                              : null,
                          child: const Text('+10 ms'),
                        ),
                        TextButton(
                          onPressed: canEdit ? _editGrid : null,
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: canEdit ? () => _setGrid(null) : null,
                          child: const Text('Remove grid'),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Play with click & drums'),
                      subtitle: Text(
                        !canSyncToClick(grid)
                            ? 'Needs a whole-number BPM'
                            : _sync
                            ? '100% speed · count-in from metronome settings'
                                  '${_drumsName == null ? '' : ' · drums: $_drumsName'}'
                            : "Song locked to the click, with the song's drum "
                                  'pattern if it has one',
                      ),
                      value: _sync,
                      onChanged:
                          canSyncToClick(grid) && _loaded && !_preparingSync
                          ? (value) => unawaited(_setSync(value))
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Snap to bar'),
                      value: _snap,
                      onChanged: canEdit
                          ? (value) => setState(() => _snap = value)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Clear the scaffold's bottom bar, as the audio note editor does.
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _timeline(bool canEdit) => Padding(
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
                      ? (details) => _seekTo(
                          (details.localPosition.dx / width * _durationMs)
                              .round(),
                        )
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
              if (canEdit && _durationMs > 0)
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
        behavior: HitTestBehavior.opaque,
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
          _beforeDrag = null;
          unawaited(_changeRegions(_entry.regions));
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
      final color = MonoPulseColors.sectionColors[i % 6];
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
