// The first tests this surface has ever had. The audit found EventShareScreen,
// EventShareService, createShare, claimShare and revokeShare at ZERO test
// references while the server side had twelve.
//
// These assert ABSENCES, because that is what the feature actually promises: a
// venue gets titles and no chart data. Asserting only that a performer CAN see
// chords would pass just as well with the scoping removed entirely.

import 'package:flowgroove/models/event_access.dart';
import 'package:flowgroove/services/event_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

EventView _view({
  required Map<String, String> access,
  bool canSuggest = false,
  bool withChart = false,
}) => EventView(
  setlistId: 'sl1',
  name: 'Sputnik Bar',
  access: access,
  canSuggest: canSuggest,
  viewerName: 'Sputnik — Ana',
  eventDateTime: DateTime(2026, 8, 21, 20),
  eventLocation: 'Sputnik Bar, Lisbon',
  items: const [
    {'id': 'i1', 'songId': 's1', 'type': 'song'},
    {'id': 'i2', 'type': 'break', 'breakLabel': 'Roume'},
  ],
  songs: [
    {
      'id': 's1',
      'title': 'visto',
      'artist': 'Flor Damico',
      if (withChart) 'ourKey': 'Bm',
      if (withChart) 'ourBPM': 96,
      if (withChart)
        'sections': const [
          {'name': 'Verse 1', 'chordChart': '[Am]Ya no necesito'},
        ],
    },
  ],
  people: const [
    {'id': 'p1', 'name': 'Flor Damico', 'role': 'vocalist'},
  ],
);

void main() {
  group('EventView scoping — what a viewer must NOT receive', () {
    test('a venue-scoped view carries no chart data at all', () {
      final view = _view(
        access: {
          EventArea.eventInfo: EventAccessLevel.view,
          EventArea.runningOrder: EventAccessLevel.view,
        },
      );

      expect(view.canSee(EventArea.songDetail), isFalse);
      expect(view.canSee(EventArea.stage), isFalse);
      expect(view.canSee(EventArea.rider), isFalse);

      // Absent, not merely hidden — the fields never arrived.
      final song = view.songs.single;
      expect(song.containsKey('ourKey'), isFalse);
      expect(song.containsKey('ourBPM'), isFalse);
      expect(song.containsKey('sections'), isFalse);
      expect(view.stage, isNull);
      expect(view.rider, isNull);
    });

    test('null stage means "not shared", which is not an empty stage', () {
      final hidden = _view(access: {EventArea.eventInfo: EventAccessLevel.view});
      expect(hidden.stage, isNull);

      final shared = EventView.fromMap({
        'setlistId': 'sl1',
        'name': 'Gig',
        'viewer': {
          'access': {EventArea.stage: EventAccessLevel.view},
          'canSuggest': false,
        },
        'stage': <String, dynamic>{},
      });
      expect(shared.stage, isNotNull);
      expect(shared.stage, isEmpty);
    });

    test('a performer does get the chart — the scoping is not blanket', () {
      final view = _view(
        access: {
          EventArea.runningOrder: EventAccessLevel.view,
          EventArea.songDetail: EventAccessLevel.view,
        },
        withChart: true,
      );
      expect(view.canSee(EventArea.songDetail), isTrue);
      expect(view.songs.single['ourKey'], 'Bm');
    });
  });

  group('setlistFromEventView', () {
    test('carries a GRANTED stage plot and rider through intact', () {
      // The bug this test exists for: the mapper originally kept only `people`,
      // so a granted sound engineer opened the editor onto a blank stage plot
      // and overwrote the real one on their first change.
      final view = EventView.fromMap({
        'setlistId': 'sl1',
        'name': 'Gig',
        'viewer': {
          'access': {
            EventArea.stage: EventAccessLevel.edit,
            EventArea.rider: EventAccessLevel.view,
          },
          'canSuggest': false,
        },
        'stage': {
          'back-left': [
            {'kind': 'equipment', 'label': 'Drum kit'},
          ],
        },
        'rider': [
          {'label': 'XLR cables', 'qty': 4, 'done': false},
        ],
        'people': [
          {'id': 'p1', 'name': 'Flor', 'role': 'vocalist'},
        ],
      });

      final setlist = setlistFromEventView(view, 'band-1');
      expect(setlist.eventKit!.stage['back-left']!.single.label, 'Drum kit');
      expect(setlist.eventKit!.rider.single.label, 'XLR cables');
      expect(setlist.eventKit!.rider.single.qty, 4);
      expect(setlist.eventKit!.people.single.name, 'Flor');
      expect(setlist.bandId, 'band-1');
    });

    test('an UNGRANTED area stays empty rather than inventing one', () {
      final setlist = setlistFromEventView(
        _view(access: {EventArea.runningOrder: EventAccessLevel.view}),
        'band-1',
      );
      expect(setlist.eventKit!.stage, isEmpty);
      expect(setlist.eventKit!.rider, isEmpty);
    });

    test('the roster carries names and roles but never uids', () {
      final setlist = setlistFromEventView(
        _view(access: {EventArea.eventInfo: EventAccessLevel.view}),
        'band-1',
      );
      final person = setlist.eventKit!.people.single;
      expect(person.name, 'Flor Damico');
      expect(person.role, 'vocalist');
      expect(person.uid, isNull);
    });

    test('keeps break dividers in the running order', () {
      final setlist = setlistFromEventView(
        _view(access: {EventArea.runningOrder: EventAccessLevel.view}),
        'band-1',
      );
      expect(setlist.items.length, 2);
      expect(setlist.items.last.isBreak, isTrue);
      expect(setlist.items.last.breakLabel, 'Roume');
    });
  });

  group('who is offered what', () {
    // Mirrors the gating in EventShareScreen and the Event kit entry, so a
    // change to either has to change an assertion here too.
    bool needsSignIn({required bool signedIn, required Map<String, String> a}) =>
        !signedIn && EventArea.all.any((area) => canEditArea(a, area));

    test('an edit grant prompts sign-in; a view-only grant never does', () {
      expect(
        needsSignIn(
          signedIn: false,
          a: {EventArea.stage: EventAccessLevel.edit},
        ),
        isTrue,
      );
      expect(
        needsSignIn(
          signedIn: false,
          a: {
            EventArea.eventInfo: EventAccessLevel.view,
            EventArea.runningOrder: EventAccessLevel.view,
          },
        ),
        isFalse,
        reason: 'a venue or a client must never be pushed into a signup',
      );
      expect(
        needsSignIn(
          signedIn: true,
          a: {EventArea.stage: EventAccessLevel.edit},
        ),
        isFalse,
      );
    });

    test('the Event kit door opens for stage or rider, not for a plain guest', () {
      bool canOpen(Map<String, String> a) =>
          canViewArea(a, EventArea.stage) || canViewArea(a, EventArea.rider);

      expect(canOpen({EventArea.stage: EventAccessLevel.edit}), isTrue);
      expect(canOpen({EventArea.rider: EventAccessLevel.view}), isTrue);
      expect(
        canOpen({
          EventArea.eventInfo: EventAccessLevel.view,
          EventArea.runningOrder: EventAccessLevel.view,
          EventArea.songDetail: EventAccessLevel.view,
        }),
        isFalse,
        reason: 'a performing guest has no business in the stage plot',
      );
    });
  });
}
