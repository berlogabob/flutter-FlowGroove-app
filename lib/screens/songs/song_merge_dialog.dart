import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../../services/matching/song_merge_resolver.dart';

class SongMergeDialog extends StatefulWidget {
  const SongMergeDialog({required this.first, required this.second, super.key});

  final Song first;
  final Song second;

  @override
  State<SongMergeDialog> createState() => _SongMergeDialogState();
}

class _SongMergeDialogState extends State<SongMergeDialog> {
  final _resolver = const SongMergeResolver();
  late Song _keeper;
  late Song _duplicate;
  SongMergeSide _title = SongMergeSide.keeper;
  SongMergeSide _artist = SongMergeSide.keeper;
  SongMergeSide _notes = SongMergeSide.keeper;
  SongMergeSide _arrangement = SongMergeSide.keeper;

  @override
  void initState() {
    super.initState();
    _keeper = _resolver.preferredKeeper(widget.first, widget.second);
    _duplicate = identical(_keeper, widget.first)
        ? widget.second
        : widget.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Merge songs'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Keep this library record'),
              RadioGroup<String>(
                groupValue: _keeper.id,
                onChanged: (id) {
                  if (id == null || id == _keeper.id) return;
                  setState(() {
                    final oldKeeper = _keeper;
                    _keeper = _duplicate;
                    _duplicate = oldKeeper;
                  });
                },
                child: Column(
                  children: [
                    RadioListTile(
                      value: _keeper.id,
                      title: Text(_label(_keeper)),
                    ),
                    RadioListTile(
                      value: _duplicate.id,
                      title: Text(_label(_duplicate)),
                    ),
                  ],
                ),
              ),
              const Divider(),
              _choice('Song name', _keeper.title, _duplicate.title, _title, (
                v,
              ) {
                setState(() => _title = v);
              }),
              _choice('Artist', _keeper.artist, _duplicate.artist, _artist, (
                v,
              ) {
                setState(() => _artist = v);
              }),
              _choice(
                'Notes',
                _keeper.notes ?? '',
                _duplicate.notes ?? '',
                _notes,
                (v) => setState(() => _notes = v),
              ),
              _choice(
                'Arrangement and metronome',
                '${_keeper.sections.length} sections',
                '${_duplicate.sections.length} sections',
                _arrangement,
                (v) => setState(() => _arrangement = v),
              ),
              const SizedBox(height: 8),
              const Text('Tags and links from both songs will be combined.'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final merged = _resolver.merge(
              _keeper,
              _duplicate,
              choices: SongMergeChoices(
                title: _title,
                artist: _artist,
                notes: _notes,
                arrangement: _arrangement,
              ),
            );
            Navigator.pop(context, (_keeper, _duplicate, merged));
          },
          child: const Text('Merge'),
        ),
      ],
    );
  }

  Widget _choice(
    String label,
    String keeperValue,
    String duplicateValue,
    SongMergeSide value,
    ValueChanged<SongMergeSide> onChanged,
  ) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: SegmentedButton<SongMergeSide>(
        segments: [
          ButtonSegment(
            value: SongMergeSide.keeper,
            label: Text(keeperValue.isEmpty ? 'Blank' : keeperValue),
          ),
          ButtonSegment(
            value: SongMergeSide.duplicate,
            label: Text(duplicateValue.isEmpty ? 'Blank' : duplicateValue),
          ),
        ],
        selected: {value},
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    );
  }

  String _label(Song song) =>
      '${song.title} - ${song.artist.isEmpty ? 'Unknown artist' : song.artist}';
}
