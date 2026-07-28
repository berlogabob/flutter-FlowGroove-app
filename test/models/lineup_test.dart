import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/event_kit.dart';
import 'package:flowgroove/models/lineup.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lineupFor', () {
    test('offers band members alongside guests', () {
      const kit = EventKit(
        people: [EventPerson(id: 'g1', name: 'Lena', role: 'Violin')],
      );
      final lineup = lineupFor(kit, [
        BandMember(uid: 'u1', role: 'editor', displayName: 'Ivan',
            musicRoles: const ['pianist']),
      ]);

      expect(lineup.map((p) => p.name), ['Lena', 'Ivan']);
      expect(lineup.last.id, 'u1', reason: 'member id is their uid');
      expect(lineup.last.role, 'Pianist');
    });

    test('a linked guest is not offered twice', () {
      const kit = EventKit(
        people: [
          EventPerson(id: 'g1', name: 'Lena', role: 'Violin', uid: 'u1'),
        ],
      );
      final lineup = lineupFor(kit, [
        BandMember(uid: 'u1', role: 'editor', displayName: 'Lena K.'),
      ]);

      expect(lineup, hasLength(1));
      expect(lineup.single.id, 'g1', reason: 'linking must not change the id');
    });
  });

  test('performerLabel skips ids no longer on the roster', () {
    final byId = peopleById(const [
      EventPerson(id: 'a', name: 'Ivan', role: 'Piano'),
      EventPerson(id: 'b', name: 'Anna', role: ''),
    ]);

    expect(performerLabel(['a', 'b', 'gone'], byId), 'Ivan (Piano) · Anna');
    expect(performerLabel(const [], byId), '');
  });

  test('songNumbersByPerformer restarts numbering after a break', () {
    final items = [
      const SetlistItem(id: '1', songId: 's1', performerIds: ['ivan']),
      const SetlistItem(id: '2', songId: 's2', performerIds: ['ivan', 'anna']),
      SetlistItem.breakItem(id: 'b', breakType: 'encore'),
      const SetlistItem(id: '3', songId: 's3', performerIds: ['ivan']),
    ];

    final numbers = songNumbersByPerformer(items);
    expect(numbers['ivan'], [1, 2, 1]);
    expect(numbers['anna'], [2]);
    expect(hasAssignments(items), isTrue);
    expect(hasAssignments([items[2]]), isFalse);
  });
}
