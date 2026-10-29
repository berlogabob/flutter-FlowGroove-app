import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/midi_pattern.dart';
import '../../../models/song_lab.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/data/data_providers.dart';
import '../../../providers/data/drum_practice_provider.dart';
import '../../../providers/permissions_provider.dart';
import '../../../services/analytics_service.dart';
import '../../../services/audio/midi/drum_map.dart';

const _lanes = <DrumLane, int>{
  DrumLane.kick: 36,
  DrumLane.snare: 38,
  DrumLane.hatClosed: 42,
  DrumLane.hatOpen: 46,
  DrumLane.tomHigh: 50,
  DrumLane.tomMid: 47,
  DrumLane.tomFloor: 43,
  DrumLane.crash: 49,
  DrumLane.ride: 51,
};

class DrumGridEditor extends ConsumerStatefulWidget {
  const DrumGridEditor({
    required this.songId,
    this.bandId,
    this.entry,
    this.dirty,
    super.key,
  });

  final String songId;
  final String? bandId;
  final SongLabEntry? entry;
  final ValueNotifier<bool>? dirty;

  @override
  ConsumerState<DrumGridEditor> createState() => _DrumGridEditorState();
}

class _DrumGridEditorState extends ConsumerState<DrumGridEditor> {
  late final TextEditingController _name;
  late final DrumPracticeNotifier _practice;
  late final String _entryId;
  late int _bars;
  late List<MidiHit> _hits;
  bool _busy = false;
  int _page = 0;

  bool get _canEdit =>
      widget.bandId == null || ref.read(canEditBandProvider(widget.bandId!));

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    assert(
      entry == null || entry.type == LabEntryType.midi,
      'Expected MIDI entry',
    );
    assert(
      entry == null || entry.songId == widget.songId,
      'Song scope mismatch',
    );
    assert(
      entry == null || entry.bandId == widget.bandId,
      'Band scope mismatch',
    );
    final pattern = entry?.pattern;
    _name = TextEditingController(
      text: widget.entry?.title ?? pattern?.name ?? 'New drum pattern',
    );
    _entryId = widget.entry?.id ?? const Uuid().v4();
    _bars = (pattern?.bars ?? 1).clamp(1, 4);
    // Imported meters use the same bar duration, quantized to sixteen cells.
    final stepsPerBar =
        (pattern?.beatsPerBar ?? 4) * (pattern?.stepsPerBeat ?? 4);
    _hits = [
      if (pattern != null && stepsPerBar > 0)
        for (final hit in pattern.hits)
          if (hit.step >= 0 && hit.step * 16 / stepsPerBar < _bars * 16)
            MidiHit(
              step: (hit.step * 16 / stepsPerBar).floor(),
              note: hit.note,
              vel: hit.vel,
            ),
    ];
    _practice = ref.read(drumPracticeProvider.notifier);
  }

  @override
  void dispose() {
    // Riverpod updates must run after the widget tree finishes unmounting.
    scheduleMicrotask(() => unawaited(_practice.stop()));
    _name.dispose();
    super.dispose();
  }

  MidiPattern _pattern() => MidiPattern(
    name: _name.text.trim(),
    bars: _bars,
    beatsPerBar: 4,
    stepsPerBeat: 4,
    hits: List.of(_hits)
      ..sort((a, b) {
        final step = a.step.compareTo(b.step);
        return step != 0 ? step : a.note.compareTo(b.note);
      }),
  );

  int _velocity(DrumLane lane, int step) {
    for (final hit in _hits) {
      if (hit.step == step && laneForNote(hit.note) == lane) return hit.vel;
    }
    return 0;
  }

  void _toggle(DrumLane lane, int step) {
    if (!_canEdit || _busy) return;
    final velocity = switch (_velocity(lane, step)) {
      0 => 90,
      <= 40 => 0,
      <= 90 => 120,
      _ => 40,
    };
    setState(() {
      _hits.removeWhere(
        (hit) => hit.step == step && laneForNote(hit.note) == lane,
      );
      widget.dirty?.value = true;
      if (velocity > 0) {
        _hits.add(MidiHit(step: step, note: _lanes[lane]!, vel: velocity));
      }
    });
    unawaited(_practice.stop());
  }

  Future<void> _play() async {
    setState(() => _busy = true);
    try {
      if (ref.read(drumPracticeProvider).playing) {
        await _practice.stop();
      } else {
        await _practice.loadPattern(_entryId, _pattern());
        if (mounted) await _practice.start();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_canEdit || _busy || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final pattern = _pattern();
      final now = DateTime.now();
      final entry =
          widget.entry?.copyWith(title: pattern.name, midi: pattern.toJson()) ??
          SongLabEntry(
            id: _entryId,
            songId: widget.songId,
            bandId: widget.bandId,
            type: LabEntryType.midi,
            title: pattern.name,
            authorId: ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
            createdAt: now,
            updatedAt: now,
            midi: pattern.toJson(),
          );
      await ref
          .read(labRepositoryProvider)
          .saveEntry(entry, bandId: widget.bandId);
      unawaited(
        AnalyticsService.logDrumPatternSaved(hitCount: pattern.hits.length),
      );
      if (mounted) Navigator.of(context).pop(entry);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save drum pattern: $error'),
            behavior: SnackBarBehavior.floating,
            // Float above the pinned Play/Save row instead of covering it.
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit =
        widget.bandId == null || ref.watch(canEditBandProvider(widget.bandId!));
    final playing = ref.watch(drumPracticeProvider.select((s) => s.playing));
    final currentStep = ref.watch(
      drumPracticeProvider.select((s) => s.currentStep),
    );
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              8,
              16,
              8,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  enabled: canEdit && !_busy,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (_) {
                    setState(() {});
                    widget.dirty?.value = true;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final bars in [1, 2, 3, 4])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$bars ${bars == 1 ? 'bar' : 'bars'}',
                              ),
                            ),
                            showCheckmark: false,
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            selected: _bars == bars,
                            onSelected: canEdit && !_busy
                                ? (_) {
                                    setState(() {
                                      _bars = bars;
                                      _page = 0;
                                      _hits.removeWhere(
                                        (hit) => hit.step >= bars * 16,
                                      );
                                      widget.dirty?.value = true;
                                    });
                                    unawaited(_practice.stop());
                                  }
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tap: Off → Normal (90) → Accent (120) → Ghost (40) → Off',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var page = 0; page < _bars * 2; page++)
                      ChoiceChip(
                        key: ValueKey('drum-page-$page'),
                        label: Text('${page * 8 + 1}-${page * 8 + 8}'),
                        showCheckmark: false,
                        selected: _page == page,
                        onSelected: (_) => setState(() => _page = page),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          for (final lane in DrumLane.values)
                            SizedBox(
                              height: 48,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(laneLabel(lane)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          for (var column = 0; column < 8; column++)
                            Expanded(
                              child: _stepColumn(
                                _page * 8 + column,
                                canEdit && !_busy,
                                colors,
                                playing && currentStep == _page * 8 + column,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _play,
                  icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                  label: Text(playing ? 'Stop' : 'Play'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: canEdit && !_busy && _name.text.trim().isNotEmpty
                      ? _save
                      : null,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepColumn(
    int step,
    bool enabled,
    ColorScheme colors,
    bool highlighted,
  ) {
    return Container(
      key: ValueKey('drum-step-$step'),
      color: highlighted ? colors.secondaryContainer : null,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 24,
            child: Center(
              child: Text(
                '${step + 1}',
                style: TextStyle(
                  fontWeight: step % 4 == 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: step % 4 == 0 ? colors.primary : null,
                ),
              ),
            ),
          ),
          for (final lane in DrumLane.values)
            _cell(lane, step, enabled, colors),
        ],
      ),
    );
  }

  Widget _cell(DrumLane lane, int step, bool enabled, ColorScheme colors) {
    final velocity = _velocity(lane, step);
    final label = switch (velocity) {
      0 => 'Off',
      <= 40 => 'Ghost',
      <= 90 => 'Normal',
      _ => 'Accent',
    };
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Semantics(
        label: '${laneLabel(lane)} step ${step + 1}',
        value: '$label ($velocity)',
        selected: velocity > 0,
        child: InkWell(
          key: ValueKey('drum-cell-${lane.name}-$step'),
          onTap: enabled ? () => _toggle(lane, step) : null,
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: velocity == 0
                  ? (step % 4 == 0 ? colors.surfaceContainerHigh : null)
                  : colors.primary.withValues(alpha: velocity / 127),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outline),
            ),
            alignment: Alignment.center,
            child: velocity == 0 ? null : Text('$velocity'),
          ),
        ),
      ),
    );
  }
}
