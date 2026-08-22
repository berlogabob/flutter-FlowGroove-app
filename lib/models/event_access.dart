/// Who may see (and change) which part of one event.
///
/// A band member is not the unit of access here — an *area of one event, for one
/// named person* is. A club's art director needs the running order and nothing
/// else; a sound engineer needs the stage plot and no lyrics; a wedding couple
/// needs song titles and would be baffled (and over-informed) by keys and BPMs.
///
/// Stored on [EventPerson.access] as `area -> level`. An ABSENT key means hidden,
/// so the default for anything unrecognised is "shows nothing" rather than
/// "shows everything".
library;

import '../utils/music_role_icon.dart';

/// The independently shareable parts of an event.
abstract final class EventArea {
  /// Date, venue, call time.
  static const String eventInfo = 'eventInfo';

  /// Song titles and their order — titles only, no chart content.
  static const String runningOrder = 'runningOrder';

  /// Lyrics, chords, key, BPM.
  static const String songDetail = 'songDetail';

  /// The stage plot (`EventKit.stage`).
  static const String stage = 'stage';

  /// Equipment / bill of materials (`EventKit.rider`).
  static const String rider = 'rider';

  static const List<String> all = [
    eventInfo,
    runningOrder,
    songDetail,
    stage,
    rider,
  ];

  /// Human label for the share sheet's "they will see…" preview.
  static String label(String area) => switch (area) {
    eventInfo => 'Event info (date, venue, call time)',
    runningOrder => 'Running order (song titles)',
    songDetail => 'Lyrics, chords, key & BPM',
    stage => 'Stage plot',
    rider => 'Equipment / rider',
    _ => area,
  };
}

/// Levels are ordered: absent < view < edit.
abstract final class EventAccessLevel {
  static const String view = 'view';
  static const String edit = 'edit';
}

/// Event-specific roles that aren't musical roles, so they have no entry in
/// [MusicRoleIcon]'s instrument vocabulary.
abstract final class EventRole {
  /// The customer — a wedding couple, a corporate booker.
  static const String client = 'client';

  /// Venue side — art director, programmer, promoter.
  static const String venue = 'venue';

  /// Plays some of the set without being in the band (a dep, a guest).
  static const String performingGuest = 'performing_guest';
}

/// A role's default grant. Manual ticks layer on top of this and persist, so
/// escalating one manager on one event never redefines "manager" elsewhere.
typedef EventAccessPreset = ({Map<String, String> access, bool canSuggest});

const EventAccessPreset _readOnlyEvent = (
  access: {
    EventArea.eventInfo: EventAccessLevel.view,
    EventArea.runningOrder: EventAccessLevel.view,
  },
  canSuggest: false,
);

/// Default access for [role], by the same normalised key [MusicRoleIcon] uses
/// ("Sound Engineer", "sound-engineer" and "sound_engineer" all match).
///
/// Unknown roles fall back to event info + running order, never to song detail:
/// an unrecognised guest should under-see, not over-see.
EventAccessPreset presetForRole(String role) {
  final key = MusicRoleIcon.normalizeKeys([role]).firstOrNull ?? '';
  return switch (key) {
    EventRole.client => (
      access: {
        EventArea.eventInfo: EventAccessLevel.view,
        EventArea.runningOrder: EventAccessLevel.view,
      },
      canSuggest: true,
    ),
    EventRole.venue || 'promoter' => (
      access: {
        EventArea.eventInfo: EventAccessLevel.view,
        EventArea.runningOrder: EventAccessLevel.view,
        EventArea.stage: EventAccessLevel.view,
        EventArea.rider: EventAccessLevel.view,
      },
      canSuggest: true,
    ),
    'sound_engineer' || 'audio_engineer' || 'lighting_engineer' => (
      access: {
        EventArea.eventInfo: EventAccessLevel.view,
        EventArea.runningOrder: EventAccessLevel.view,
        EventArea.stage: EventAccessLevel.edit,
        EventArea.rider: EventAccessLevel.view,
      },
      canSuggest: false,
    ),
    'videographer' || 'photographer' => (
      access: {
        EventArea.eventInfo: EventAccessLevel.view,
        EventArea.runningOrder: EventAccessLevel.view,
        EventArea.stage: EventAccessLevel.view,
        EventArea.rider: EventAccessLevel.edit,
      },
      canSuggest: false,
    ),
    'roadie' || 'stage_manager' => (
      access: {
        EventArea.eventInfo: EventAccessLevel.view,
        EventArea.runningOrder: EventAccessLevel.view,
        EventArea.stage: EventAccessLevel.edit,
        EventArea.rider: EventAccessLevel.edit,
      },
      canSuggest: false,
    ),
    'manager' => (
      access: {
        for (final area in EventArea.all) area: EventAccessLevel.view,
      },
      canSuggest: true,
    ),
    // Anyone who actually plays needs the charts.
    EventRole.performingGuest ||
    'vocalist' ||
    'lead_vocalist' ||
    'backing_vocalist' ||
    'backup_singer' ||
    'guitarist' ||
    'bassist' ||
    'drummer' ||
    'percussionist' ||
    'keyboardist' ||
    'pianist' ||
    'saxophonist' ||
    'violinist' ||
    'cellist' ||
    'trumpet' ||
    'trombone' ||
    'flute' ||
    'harpist' ||
    'rapper' ||
    'mc' ||
    'dj' ||
    'conductor' ||
    'choir' => (
      access: {
        EventArea.eventInfo: EventAccessLevel.view,
        EventArea.runningOrder: EventAccessLevel.view,
        EventArea.songDetail: EventAccessLevel.view,
      },
      canSuggest: false,
    ),
    _ => _readOnlyEvent,
  };
}

/// True when [access] permits reading [area] at all.
bool canViewArea(Map<String, String> access, String area) =>
    access[area] == EventAccessLevel.view ||
    access[area] == EventAccessLevel.edit;

/// True when [access] permits changing [area].
bool canEditArea(Map<String, String> access, String area) =>
    access[area] == EventAccessLevel.edit;

/// Drop anything that isn't a known area/level, so a hand-edited or
/// forward-incompatible document can never widen a grant.
Map<String, String> sanitizeAccess(Map<String, String> access) => {
  for (final entry in access.entries)
    if (EventArea.all.contains(entry.key) &&
        (entry.value == EventAccessLevel.view ||
            entry.value == EventAccessLevel.edit))
      entry.key: entry.value,
};
