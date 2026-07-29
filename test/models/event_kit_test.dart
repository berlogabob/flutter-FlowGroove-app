import 'package:flowgroove/models/event_kit.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EventKit (#52)', () {
    test('round-trips through JSON', () {
      const kit = EventKit(
        stage: {
          'back-left': [
            StagePlacement(kind: 'member', label: 'Alex (drums)', uid: 'u1'),
            StagePlacement(kind: 'equipment', label: 'Amp'),
          ],
        },
        people: [
          EventPerson(
            id: 'p1',
            name: 'Vera',
            role: 'Photographer',
            notes: 'arrives 19h',
          ),
        ],
        rider: [
          RiderItem(label: 'XLR cables', qty: 4),
          RiderItem(label: 'Monitor wedge', done: true),
        ],
      );

      final back = EventKit.fromJson(kit.toJson());
      expect(back.stage['back-left'], hasLength(2));
      expect(back.stage['back-left']!.first.uid, 'u1');
      expect(back.people.single.role, 'Photographer');
      expect(back.rider.first.qty, 4);
      expect(back.rider.last.done, isTrue);
      expect(back.isEmpty, isFalse);
    });

    test('a person saved before ids existed falls back to their name', () {
      final back = EventKit.fromJson({
        'people': [
          {'name': 'Vera', 'role': 'Photographer'},
        ],
      });
      expect(back.people.single.id, 'Vera');
      expect(back.people.single.uid, isNull);
    });

    test('linking keeps the id so assignments still resolve', () {
      const guest = EventPerson(id: 'g1', name: 'Lena', role: 'Violin');
      final linked = guest.copyWith(uid: 'u1');
      expect(linked.id, 'g1');
      expect(linked.uid, 'u1');
      expect(linked.name, 'Lena');
    });

    test('unknown zone ids are dropped on parse', () {
      final back = EventKit.fromJson({
        'stage': {
          'balcony': [
            {'kind': 'equipment', 'label': 'Disco ball'},
          ],
          'front-center': [
            {'kind': 'member', 'label': 'Vera (vocals)'},
          ],
        },
      });
      expect(back.stage.containsKey('balcony'), isFalse);
      expect(back.stage['front-center'], hasLength(1));
    });

    test('Setlist carries eventKit and legacy docs stay null', () {
      final legacy = Setlist.fromJson({
        'id': 's1',
        'bandId': 'b1',
        'name': 'Gig',
        'createdAt': '2026-07-16T12:00:00.000',
        'updatedAt': '2026-07-16T12:00:00.000',
      });
      expect(legacy.eventKit, isNull);

      final withKit = legacy.copyWith(
        eventKit: const EventKit(rider: [RiderItem(label: 'Water')]),
      );
      final json = withKit.toJson();
      final back = Setlist.fromJson(json);
      expect(back.eventKit!.rider.single.label, 'Water');

      // Sentinel copyWith: omitting keeps, explicit null clears.
      expect(back.copyWith(name: 'X').eventKit, isNotNull);
      expect(back.copyWith(eventKit: null).eventKit, isNull);
    });
  });
}
