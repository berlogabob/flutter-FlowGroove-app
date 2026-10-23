import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/midi_song.dart';
import '../../services/audio/midi/drum_map.dart';
import '../../services/audio/midi/note_edit.dart';
import '../../theme/mono_pulse_theme.dart';

class NoteEditorSheet extends StatefulWidget {
  const NoteEditorSheet({
    required this.track,
    required this.notes,
    required this.ppq,
    required this.beatsPerBar,
    required this.sections,
    required this.onApply,
    super.key,
  });

  final MidiTrackMeta track;
  final List<MidiNote> notes;
  final int ppq;
  final int beatsPerBar;
  final List<({String name, int startBar, int bars})> sections;
  final void Function(List<int>? flat) onApply;

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late List<MidiNote> _working;
  late final int _barCount;
  late final int _minPitch;
  late final int _maxPitch;
  int _bar = 0;

  bool get _isDrums => widget.track.effectiveRole == MidiRole.drums;
  int get _stepsPerBar => widget.beatsPerBar * 4;
  int get _cellTicks => widget.ppq ~/ 4;
  int get _ticksPerBar => widget.ppq * widget.beatsPerBar;

  @override
  void initState() {
    super.initState();
    _working = List.of(widget.notes);
    final lastNoteEnd = widget.notes.fold<int>(
      0,
      (end, note) => math.max(end, note.tick + note.dur),
    );
    _barCount = math.max(1, (lastNoteEnd / _ticksPerBar).ceil());
    _minPitch = widget.notes.isEmpty
        ? 48
        : (widget.notes.map((note) => note.pitch).reduce(math.min) - 2).clamp(
            0,
            127,
          );
    _maxPitch = widget.notes.isEmpty
        ? 72
        : (widget.notes.map((note) => note.pitch).reduce(math.max) + 2).clamp(
            0,
            127,
          );
  }

  void _apply() {
    final flat = flatFromNotes(_working);
    if (flat.length > 40000) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Too many notes to save')));
      return;
    }
    widget.onApply(flat);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const pitchNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final section = widget.sections
        .where((s) => _bar >= s.startBar && _bar < s.startBar + s.bars)
        .firstOrNull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.track.name, style: MonoPulseTypography.titleMedium),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous bar',
                  onPressed: _bar > 0 ? () => setState(() => _bar--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Bar ${_bar + 1} of $_barCount',
                    style: MonoPulseTypography.bodyMedium,
                  ),
                ),
                if (section != null)
                  Flexible(
                    child: Text(
                      section.name,
                      overflow: TextOverflow.ellipsis,
                      style: MonoPulseTypography.labelMedium,
                    ),
                  ),
                IconButton(
                  tooltip: 'Next bar',
                  onPressed: _bar < _barCount - 1
                      ? () => setState(() => _bar++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (_isDrums)
                    for (final lane in DrumLane.values)
                      _buildRow(
                        label: laneLabel(lane),
                        matches: (pitch) => laneForNote(pitch) == lane,
                        addPitch: switch (lane) {
                          DrumLane.kick => 36,
                          DrumLane.snare => 38,
                          DrumLane.hatClosed => 42,
                          DrumLane.hatOpen => 46,
                          DrumLane.tomHigh => 50,
                          DrumLane.tomMid => 47,
                          DrumLane.tomFloor => 43,
                          DrumLane.crash => 49,
                          DrumLane.ride => 51,
                        },
                      )
                  else
                    for (var pitch = _maxPitch; pitch >= _minPitch; pitch--)
                      _buildRow(
                        label: '${pitchNames[pitch % 12]}${pitch ~/ 12 - 1}',
                        matches: (p) => p == pitch,
                        addPitch: pitch,
                      ),
                ],
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onApply(null);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Reset to file'),
                ),
                const SizedBox(width: MonoPulseSpacing.sm),
                FilledButton(onPressed: _apply, child: const Text('Apply')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required bool Function(int pitch) matches,
    required int addPitch,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: MonoPulseTypography.labelMedium),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var step = 0; step < _stepsPerBar; step++)
                  Builder(
                    builder: (context) {
                      final cellStart = _bar * _ticksPerBar + step * _cellTicks;
                      final active = cellActive(
                        _working,
                        cellStart: cellStart,
                        cellTicks: _cellTicks,
                        matches: matches,
                      );
                      return Semantics(
                        label: '$label step $step',
                        selected: active,
                        button: true,
                        child: InkWell(
                          onTap: () => setState(() {
                            _working = toggleCell(
                              _working,
                              cellStart: cellStart,
                              cellTicks: _cellTicks,
                              matches: matches,
                              addPitch: addPitch,
                            );
                          }),
                          child: Container(
                            width: 40,
                            height: 36,
                            decoration: BoxDecoration(
                              color: active ? colors.primary : colors.surface,
                              border: Border(
                                left: BorderSide(
                                  color: colors.outline,
                                  width: step % 4 == 0 ? 2 : 1,
                                ),
                                bottom: BorderSide(color: colors.outline),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
