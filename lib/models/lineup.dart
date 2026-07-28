/// Who plays what: the event roster ([EventKit.people]) plus the per-song
/// assignments on [SetlistItem.performerIds]. Pure functions so the sheet, the
/// setlist rows and the PDF all render the same strings.
library;

import '../utils/music_role_icon.dart';
import 'band.dart';
import 'event_kit.dart';
import 'setlist.dart';

/// The roster to offer when assigning: everyone already on the kit, plus band
/// members who aren't on it yet. A band member is only written into
/// `kit.people` once actually assigned — [EventPerson.id] is then their uid.
List<EventPerson> lineupFor(EventKit? kit, List<BandMember> members) {
  final people = [...?kit?.people];
  final known = {
    for (final p in people) ...[p.id, if (p.uid != null) p.uid!],
  };
  for (final m in members) {
    if (m.uid.isEmpty || known.contains(m.uid)) continue;
    people.add(personForMember(m));
  }
  return people;
}

/// A roster entry for a band member: id == uid, so linking never rewrites ids.
EventPerson personForMember(BandMember member) => EventPerson(
  id: member.uid,
  name: member.displayName ?? member.email ?? 'Member',
  role: member.musicRoles.isEmpty
      ? ''
      : MusicRoleIcon.getDisplayName(member.musicRoles.first),
  uid: member.uid,
);

Map<String, EventPerson> peopleById(Iterable<EventPerson> people) => {
  for (final p in people) p.id: p,
};

/// `Ivan (piano) · Anna` — roles omitted when unknown. Unknown ids are skipped
/// (a person removed from the roster shouldn't print as a stray id).
String performerLabel(
  Iterable<String> ids,
  Map<String, EventPerson> byId,
) {
  final parts = <String>[];
  for (final id in ids) {
    final person = byId[id];
    if (person == null) continue;
    parts.add(
      person.role.isEmpty ? person.name : '${person.name} (${person.role})',
    );
  }
  return parts.join(' · ');
}

/// performerId → the song numbers they play, using the same per-section
/// numbering as the UI and the PDF (a break resets the count).
Map<String, List<int>> songNumbersByPerformer(List<SetlistItem> items) {
  final result = <String, List<int>>{};
  var n = 0;
  for (final item in items) {
    if (item.isBreak) {
      n = 0;
      continue;
    }
    n++;
    for (final id in item.performerIds) {
      (result[id] ??= <int>[]).add(n);
    }
  }
  return result;
}

/// True when anyone is assigned anywhere — gates the lineup PDF sections.
bool hasAssignments(List<SetlistItem> items) =>
    items.any((item) => item.performerIds.isNotEmpty);
