// Guarding the three-way answer to "is this person a guest on this band?".
//
// It used to be a bool, and "the band list has not loaded yet" collapsed into
// "member". For a guest that window handed them every area at `edit`: the Event
// kit door opened onto controls whose writes the rules then refused. Nothing
// leaked — the payload was already scoped — but the doors were wrong, and the
// comment justifying it only reasoned about members.

import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/event_access.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Band _band(String id) => Band(
  id: id,
  name: id,
  createdBy: 'u1',
  createdAt: DateTime(2026),
  memberUids: const ['member'],
);

void main() {
  group('isEventGuestOf', () {
    test('null while the band list is loading — not "member"', () {
      expect(isEventGuestOf(null, 'band-1'), isNull);
    });

    test('false for a band you are in', () {
      expect(isEventGuestOf([_band('band-1')], 'band-1'), isFalse);
    });

    test('true for a band you are not in', () {
      expect(isEventGuestOf([_band('other')], 'band-1'), isTrue);
    });

    test('an empty band list is a definite answer, not unknown', () {
      // Loaded-and-empty must not read as loading: a guest with no bands of
      // their own is the ordinary case for this feature.
      expect(isEventGuestOf(const [], 'band-1'), isTrue);
    });
  });

  group('what unknown must offer', () {
    // Mirrors eventPermissionsProvider's contract without spinning up Riverpod:
    // unknown offers nothing, so no door appears that cannot be walked through.
    ({bool isMember, Map<String, String> access}) perms(bool? isGuest) {
      if (isGuest == null) {
        return (isMember: false, access: const <String, String>{});
      }
      if (!isGuest) {
        return (
          isMember: true,
          access: {for (final a in EventArea.all) a: EventAccessLevel.edit},
        );
      }
      return (
        isMember: false,
        access: {EventArea.stage: EventAccessLevel.edit},
      );
    }

    bool canOpenEventKit(Map<String, String> a, bool isMember) =>
        isMember ||
        canViewArea(a, EventArea.stage) ||
        canViewArea(a, EventArea.rider);

    test('offers no Event kit door while the answer is unknown', () {
      final p = perms(null);
      expect(p.isMember, isFalse);
      expect(p.access, isEmpty);
      expect(canOpenEventKit(p.access, p.isMember), isFalse);
    });

    test('a member gets every area once known', () {
      final p = perms(false);
      expect(p.isMember, isTrue);
      for (final area in EventArea.all) {
        expect(canEditArea(p.access, area), isTrue, reason: area);
      }
    });

    test('a stage editor gets the door but is not a member', () {
      final p = perms(true);
      expect(p.isMember, isFalse);
      expect(canOpenEventKit(p.access, p.isMember), isTrue);
      // isMember gates the roster — the grants are derived from it, and the
      // rules refuse an area editor's write to it.
      expect(p.isMember, isFalse);
    });
  });
}
