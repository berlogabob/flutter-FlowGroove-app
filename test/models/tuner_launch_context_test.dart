import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/tuner_launch_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 6, 13);
  final song = Song(
    id: 'song-1',
    title: 'Song',
    artist: 'Artist',
    bandId: 'song-band',
    defaultTuningPresetId: 'guitar:drop_d',
    createdAt: now,
    updatedAt: now,
  );

  test('setlist item preset overrides the song preset', () {
    final setlist = Setlist(
      id: 'setlist-1',
      bandId: 'setlist-band',
      name: 'Show',
      items: const [
        SetlistItem(
          id: 'item-1',
          songId: 'song-1',
          tuningPresetId: 'custom-live',
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final context = TunerLaunchContext(
      song: song,
      setlist: setlist,
      setlistItemId: 'item-1',
    );

    expect(context.initialPresetId, 'custom-live');
    expect(context.effectiveBandId, 'setlist-band');
  });

  test('explicit band and song defaults are used as fallbacks', () {
    final context = TunerLaunchContext(song: song, bandId: 'explicit-band');

    expect(context.initialPresetId, 'guitar:drop_d');
    expect(context.effectiveBandId, 'explicit-band');
  });
}
