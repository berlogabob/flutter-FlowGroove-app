import 'package:flowgroove/models/event_access.dart';
import 'package:flowgroove/services/event_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('songFromEventView', () {
    test('keeps the chart when songDetail was granted', () {
      final song = songFromEventView({
        'id': 's1',
        'title': 'visto',
        'artist': 'Flor Damico',
        'ourKey': 'Bm',
        'ourBPM': 96,
        'sections': [
          {'id': 'sec1', 'name': 'Verse 1', 'chordChart': '[Am]Ya no necesito'},
        ],
      });
      expect(song.ourKey, 'Bm');
      expect(song.ourBPM, 96);
      expect(song.sections.single.chordChart, '[Am]Ya no necesito');
    });

    test('a title-only song is scoped, not broken', () {
      // What a wedding couple receives: the server sent no key, BPM or
      // sections at all, so the Song legitimately has none.
      final song = songFromEventView({
        'id': 's1',
        'title': 'visto',
        'artist': 'Flor Damico',
      });
      expect(song.title, 'visto');
      expect(song.ourKey, isNull);
      expect(song.ourBPM, isNull);
      expect(song.sections, isEmpty);
    });

    test('survives a section saved before ids existed', () {
      final song = songFromEventView({
        'id': 's1',
        'title': 'x',
        'artist': 'y',
        'sections': [
          {'name': 'Chorus', 'chordChart': '[C]la'},
        ],
      });
      expect(song.sections.single.id, isNotEmpty);
      expect(song.sections.single.name, 'Chorus');
    });
  });

  group('EventView', () {
    test('distinguishes "not shared with you" from empty', () {
      final hidden = EventView.fromMap({
        'setlistId': 'sl1',
        'name': 'Gig',
        'viewer': {'access': <String, dynamic>{}, 'canSuggest': false},
      });
      // Null means the server never sent the area — the UI must not render an
      // empty stage plot as though the plot were simply blank.
      expect(hidden.stage, isNull);
      expect(hidden.rider, isNull);
      expect(hidden.canSee(EventArea.stage), isFalse);

      final empty = EventView.fromMap({
        'setlistId': 'sl1',
        'name': 'Gig',
        'viewer': {
          'access': {EventArea.stage: 'view'},
          'canSuggest': false,
        },
        'stage': <String, dynamic>{},
      });
      expect(empty.stage, isNotNull);
      expect(empty.stage, isEmpty);
      expect(empty.canSee(EventArea.stage), isTrue);
    });

    test('drops an access level the server should never have sent', () {
      final view = EventView.fromMap({
        'setlistId': 'sl1',
        'name': 'Gig',
        'viewer': {
          'access': {EventArea.songDetail: 'owner', 'wholeBand': 'edit'},
          'canSuggest': false,
        },
      });
      expect(view.access, isEmpty);
      expect(view.canSee(EventArea.songDetail), isFalse);
    });
  });
}
