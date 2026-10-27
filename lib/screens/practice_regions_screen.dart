import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audio_region.dart';
import '../models/section.dart';
import '../models/song_lab.dart';
import '../providers/data/data_providers.dart';
import '../providers/permissions_provider.dart';
import '../services/audio/audio_note_edit.dart';
import '../theme/mono_pulse_theme.dart';
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
    unawaited(_load());
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
          if (mounted) setState(() => _position = position);
        }),
        _player.playerStateStream.listen((state) {
          if (mounted) setState(() => _playing = state.playing);
        }),
      ]);
      await _applyLoop();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, "Couldn't load audio: $e", error: true);
      }
    }
  }

  @override
  void dispose() {
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
      _entry = _entry.copyWith(regions: regions);
      _clampSelection();
    });
    final loop = _applyLoop();
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
        setState(() {
          _clipStart = start;
          _clipEnd = end;
          _position = Duration.zero;
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

  Future<void> _togglePlay() async {
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
                tooltip: _playing ? 'Pause' : 'Play',
                iconSize: 48,
                icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
                color: MonoPulseColors.accentOrange,
                onPressed: _loaded && _durationMs > 0 ? _togglePlay : null,
              ),
              Expanded(
                child: Text(
                  '${_time(_positionMs)} / ${_time(_durationMs)}',
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
                setState(() => _selection = toggleSelection(_selection, i));
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
            onChanged: (value) {
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
                      positionMs: _positionMs,
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
