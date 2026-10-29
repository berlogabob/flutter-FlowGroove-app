import 'package:flowgroove/models/event_access.dart';
import 'package:flowgroove/models/event_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('role presets', () {
    test('a client sees titles and may suggest, never the charts', () {
      final p = presetForRole(EventRole.client);
      expect(canViewArea(p.access, EventArea.runningOrder), isTrue);
      expect(canViewArea(p.access, EventArea.songDetail), isFalse);
      expect(canViewArea(p.access, EventArea.stage), isFalse);
      expect(p.canSuggest, isTrue);
    });

    test('a sound engineer edits the stage and never sees lyrics', () {
      final p = presetForRole('sound_engineer');
      expect(canEditArea(p.access, EventArea.stage), isTrue);
      expect(canEditArea(p.access, EventArea.rider), isFalse);
      expect(canViewArea(p.access, EventArea.rider), isTrue);
      expect(canViewArea(p.access, EventArea.songDetail), isFalse);
    });

    test('a videographer edits the rider, not the stage', () {
      final p = presetForRole('videographer');
      expect(canEditArea(p.access, EventArea.rider), isTrue);
      expect(canEditArea(p.access, EventArea.stage), isFalse);
      expect(canViewArea(p.access, EventArea.songDetail), isFalse);
    });

    test('someone who plays gets the charts', () {
      for (final role in [EventRole.performingGuest, 'pianist', 'guitarist']) {
        expect(
          canViewArea(presetForRole(role).access, EventArea.songDetail),
          isTrue,
          reason: role,
        );
      }
    });

    test('a manager sees everything but edits nothing by default', () {
      final p = presetForRole('manager');
      for (final area in EventArea.all) {
        expect(canViewArea(p.access, area), isTrue, reason: area);
        expect(canEditArea(p.access, area), isFalse, reason: area);
      }
    });

    test('role keys are matched the way MusicRoleIcon normalises them', () {
      for (final spelling in [
        'Sound Engineer',
        'sound-engineer',
        'SOUND_ENGINEER',
      ]) {
        expect(
          canEditArea(presetForRole(spelling).access, EventArea.stage),
          isTrue,
          reason: spelling,
        );
      }
    });

    test('an unknown role under-sees rather than over-sees', () {
      final p = presetForRole('interpretive dancer');
      expect(canViewArea(p.access, EventArea.eventInfo), isTrue);
      expect(canViewArea(p.access, EventArea.songDetail), isFalse);
      expect(canViewArea(p.access, EventArea.stage), isFalse);
      expect(canViewArea(p.access, EventArea.rider), isFalse);
    });
  });

  group('EventPerson', () {
    test('an empty grant shows nothing — absent area means hidden', () {
      const p = EventPerson(id: 'p1', name: 'Nobody', role: 'x');
      for (final area in EventArea.all) {
        expect(p.canView(area), isFalse, reason: area);
      }
    });

    test('access and canSuggest survive a JSON round trip', () {
      final before = EventPerson.withRolePreset(
        id: 'p1',
        name: 'Ana',
        role: EventRole.venue,
        uid: 'u1',
      );
      final after = EventPerson.fromJson(before.toJson());
      expect(after.access, before.access);
      expect(after.canSuggest, isTrue);
      expect(after.uid, 'u1');
      expect(after.canView(EventArea.stage), isTrue);
      expect(after.canView(EventArea.songDetail), isFalse);
    });

    test('a hand-edited document cannot widen a grant', () {
      final p = EventPerson.fromJson({
        'id': 'p1',
        'name': 'Sneaky',
        'role': 'client',
        'access': {
          EventArea.songDetail: 'owner', // not a real level
          'wholeBand': 'edit', // not a real area
          EventArea.eventInfo: 'view', // the only survivor
        },
      });
      expect(p.access, {EventArea.eventInfo: 'view'});
      expect(p.canView(EventArea.songDetail), isFalse);
    });

    test('ticks layer on top of the preset and persist', () {
      final base = EventPerson.withRolePreset(
        id: 'p1',
        name: 'Mo',
        role: 'manager',
      );
      // Escalating one manager on one event must not need a new role.
      final escalated = base.copyWith(
        access: {...base.access, EventArea.stage: EventAccessLevel.edit},
      );
      expect(escalated.canEdit(EventArea.stage), isTrue);
      expect(
        EventPerson.fromJson(escalated.toJson()).canEdit(EventArea.stage),
        isTrue,
      );
      // The preset itself is untouched for the next event.
      expect(presetForRole('manager').access[EventArea.stage], 'view');
    });
  });
}
