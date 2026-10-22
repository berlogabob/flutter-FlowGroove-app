import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/midi_song.dart';
import '../../models/section_span.dart';
import '../../models/song_lab.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/midi_song_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../services/audio/midi/midi_song_facts.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/split_bars.dart';

class ArrangementSheet extends ConsumerStatefulWidget {
  ArrangementSheet({required this.entry, this.bandId, super.key})
    : assert(entry.midiSong != null, 'A MIDI song is required');

  final SongLabEntry entry;
  final String? bandId;

  @override
  ConsumerState<ArrangementSheet> createState() => _ArrangementSheetState();
}

class _ArrangementSheetState extends ConsumerState<ArrangementSheet> {
  late int _startBar;
  late bool _useFileTempo;
  late String _endBehavior;
  List<int>? _bars;
  bool _saving = false;
  String? _error;

  String? get _bandId => widget.bandId ?? widget.entry.bandId;

  @override
  void initState() {
    super.initState();
    final meta = widget.entry.midiSong!;
    _startBar = meta.startBar;
    _useFileTempo = meta.useFileTempo;
    _endBehavior = meta.endBehavior;
  }

  Future<void> _save(List<SectionSpan> spans) async {
    final canEdit = _bandId == null
        ? ref.read(canEditProvider)
        : ref.read(canEditBandProvider(_bandId!));
    if (!canEdit || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final updated = widget.entry.copyWith(
      midiSong: widget.entry.midiSong!.copyWith(
        startBar: _startBar,
        sectionMap: spans,
        useFileTempo: _useFileTempo,
        endBehavior: _endBehavior,
      ),
    );
    try {
      await ref.read(labRepositoryProvider).saveEntry(updated, bandId: _bandId);
      if (mounted) Navigator.of(context).pop(updated);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  Widget _stepper(String label, int value, ValueChanged<int>? onChanged) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        tooltip: 'Decrease $label',
        onPressed: onChanged != null && value > 0
            ? () => onChanged(value - 1)
            : null,
        icon: const Icon(Icons.remove),
      ),
      Text('$value'),
      IconButton(
        tooltip: 'Increase $label',
        onPressed: onChanged == null ? null : () => onChanged(value + 1),
        icon: const Icon(Icons.add),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final canEdit = _bandId == null
        ? ref.watch(canEditProvider)
        : ref.watch(canEditBandProvider(_bandId!));
    final songs = ref.watch(
      _bandId == null ? songsProvider : bandSongsProvider(_bandId!),
    );
    final midi = ref.watch(midiSongProvider(widget.entry));
    if (songs.hasError || midi.hasError) {
      return SafeArea(child: Text('${songs.error ?? midi.error}'));
    }
    if (songs.isLoading || midi.isLoading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    final song = songs.value
        ?.where((song) => song.id == widget.entry.songId)
        .firstOrNull;
    final data = midi.value;
    if (song == null || data == null) {
      return const SafeArea(child: Text('Song or MIDI file unavailable'));
    }
    final facts = factsOf(data, beatsPerBar: song.accentBeats);
    final sections = song.sections;
    final songBpm = song.ourBPM ?? song.originalBPM;
    final prefill = splitBars(facts.bars, sections.length);
    _bars ??= [
      for (var i = 0; i < sections.length; i++)
        widget.entry.midiSong!.sectionMap
                .where((span) => span.sectionId == sections[i].id)
                .firstOrNull
                ?.bars ??
            (prefill.isEmpty ? 0 : prefill[i]),
    ];
    final editable = canEdit && !_saving;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => SafeArea(
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          children: [
            const Text(
              'MIDI arrangement',
              style: MonoPulseTypography.titleLarge,
            ),
            Text(
              '${facts.bars} bars · ${data.tracks.length} instruments · '
              '${facts.leadInBars} lead-in bars',
              style: MonoPulseTypography.bodySmall,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Use ${facts.bpm.round()} BPM?'),
              subtitle: Text(
                'Otherwise keep song BPM'
                '${songBpm == null ? '' : ' ($songBpm)'}',
              ),
              value: _useFileTempo,
              onChanged: editable
                  ? (value) => setState(() => _useFileTempo = value)
                  : null,
            ),
            _stepper(
              'File starts at bar $_startBar',
              _startBar,
              editable ? (value) => setState(() => _startBar = value) : null,
            ),
            for (var i = 0; i < sections.length; i++)
              _stepper(
                '${sections[i].name} bars',
                _bars![i],
                editable ? (value) => setState(() => _bars![i] = value) : null,
              ),
            DropdownButtonFormField<String>(
              initialValue: _endBehavior,
              decoration: const InputDecoration(labelText: 'At end of file'),
              items: [
                for (final behavior in LoopBehavior.values)
                  DropdownMenuItem(
                    value: behavior.name,
                    child: Text(behavior.name),
                  ),
              ],
              onChanged: editable
                  ? (value) => setState(() => _endBehavior = value!)
                  : null,
            ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: MonoPulseSpacing.md),
            if (canEdit)
              FilledButton(
                onPressed: editable && sections.isNotEmpty
                    ? () {
                        var start = 0;
                        final spans = <SectionSpan>[];
                        for (var i = 0; i < sections.length; i++) {
                          spans.add(
                            SectionSpan(
                              sectionId: sections[i].id,
                              startBar: start,
                              bars: _bars![i],
                            ),
                          );
                          start += _bars![i];
                        }
                        _save(spans);
                      }
                    : null,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
          ],
        ),
      ),
    );
  }
}
