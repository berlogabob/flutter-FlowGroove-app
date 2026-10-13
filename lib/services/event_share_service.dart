import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/event_access.dart';
import '../models/event_kit.dart';
import '../models/event_suggestion.dart';
import '../models/section.dart';
import '../models/setlist.dart';
import '../models/song.dart';

/// The event as a [Setlist], for someone who cannot read the setlist document.
///
/// A guest is deliberately denied a direct read — Firestore reads whole
/// documents, so allowing it would hand them the stage plot, the rider and
/// every roster uid whatever their grant said. Everything they see is rebuilt
/// from the scoped payload instead, which is why the running order is empty
/// unless `runningOrder` was granted, and the roster carries names and roles
/// but never uids.
Setlist setlistFromEventView(
  EventView view,
  String? bandId, {
  String? ownerUid,
}) => Setlist(
  id: view.setlistId,
  bandId: bandId ?? '',
  ownerUid: ownerUid,
  name: view.name,
  description: view.description,
  eventDateTime: view.eventDateTime,
  eventLocation: view.eventLocation,
  items: [
    for (final item in view.items)
      SetlistItem(
        id: item['id'] as String? ?? '',
        songId: item['songId'] as String? ?? '',
        type: item['type'] as String? ?? SetlistItem.itemTypeSong,
        breakType: item['breakType'] as String?,
        breakLabel: item['breakLabel'] as String?,
      ),
  ],
  // Reuse EventKit's own parser rather than rebuilding each area by hand — it
  // already filters stage keys to the known zones. An ungranted area arrives
  // null and stays empty; that is the grant working. A GRANTED one must arrive
  // intact, or an area editor opens the editor onto a blank stage plot and
  // overwrites the real one on their first change.
  eventKit: EventKit.fromJson({
    'stage': view.stage ?? const <String, dynamic>{},
    'rider': view.rider ?? const <Map<String, dynamic>>[],
    'people': view.people,
  }),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

/// A song as it arrived in an [EventView], turned back into a [Song] so the
/// normal setlist widgets can render it.
///
/// Fields the viewer was not granted are simply absent from [map] — the server
/// never sent them — so the resulting Song legitimately has a null key/BPM and
/// no sections. That is a scoped song, not a broken one.
Song songFromEventView(Map<String, dynamic> map) => Song(
  id: map['id'] as String? ?? '',
  title: map['title'] as String? ?? '',
  artist: map['artist'] as String? ?? '',
  // A guest never edits these copies, and the timestamps are not part of the
  // scoped payload, so they only need to be valid.
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  ourKey: map['ourKey'] as String?,
  ourBPM: (map['ourBPM'] as num?)?.toInt(),
  notes: map['notes'] as String?,
  sections: [
    for (final (index, raw) in (map['sections'] as List? ?? []).indexed)
      if (raw is Map)
        Section(
          // Sections written before ids existed still turn up without one.
          id: raw['id'] as String? ?? 'event-section-$index',
          name: raw['name'] as String? ?? '',
          notes: raw['notes'] as String? ?? '',
          duration: (raw['duration'] as num?)?.toInt() ?? 1,
          chordChart: raw['chordChart'] as String?,
        ),
  ],
);

/// One event as the caller is allowed to see it.
///
/// Every optional field here is null because the SERVER left it out, not
/// because the UI chose to hide it. A wedding couple's [EventView] genuinely
/// has no chord charts in it — that is the point of scoping this server-side.
class EventView {
  const EventView({
    required this.setlistId,
    required this.name,
    required this.access,
    required this.canSuggest,
    this.bandId,
    this.ownerUid,
    this.viewerName = '',
    this.eventDateTime,
    this.eventLocation,
    this.description,
    this.items = const [],
    this.songs = const [],
    this.people = const [],
    this.stage,
    this.rider,
    this.mySuggestions = const [],
  });

  factory EventView.fromMap(Map<String, dynamic> map) {
    final viewer = _map(map['viewer']);
    return EventView(
      bandId: map['bandId'] as String?,
      ownerUid: map['ownerUid'] as String?,
      setlistId: map['setlistId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      access: sanitizeAccess({
        for (final e in _map(viewer['access']).entries)
          if (e.value is String) e.key: e.value as String,
      }),
      canSuggest: viewer['canSuggest'] as bool? ?? false,
      viewerName: viewer['name'] as String? ?? '',
      eventDateTime: DateTime.tryParse(map['eventDateTime'] as String? ?? ''),
      eventLocation: map['eventLocation'] as String?,
      description: map['description'] as String?,
      items: _list(map['items']),
      songs: _list(map['songs']),
      people: _list(map['people']),
      stage: map.containsKey('stage') ? _map(map['stage']) : null,
      rider: map.containsKey('rider') ? _list(map['rider']) : null,
      mySuggestions: [
        for (final raw in _list(map['mySuggestions']))
          EventSuggestion.fromJson(raw),
      ],
    );
  }

  final String? bandId;
  final String? ownerUid;
  final String setlistId;
  final String name;

  /// What this viewer may see and change — drives the UI, but the payload is
  /// already trimmed to match, so a bug here leaks nothing.
  final Map<String, String> access;
  final bool canSuggest;
  final String viewerName;

  final DateTime? eventDateTime;
  final String? eventLocation;
  final String? description;

  /// Running order, including break dividers. Empty when not granted.
  final List<Map<String, dynamic>> items;

  /// Titles only, unless `songDetail` was granted — then key/BPM/sections too.
  final List<Map<String, dynamic>> songs;

  /// Names and roles of everyone on the gig. Never uids or grants.
  final List<Map<String, dynamic>> people;

  /// Null means "not shared with you", distinct from an empty stage plot.
  final Map<String, dynamic>? stage;
  final List<Map<String, dynamic>>? rider;

  /// What THIS viewer asked for, and what the band decided.
  ///
  /// Comes back on the payload rather than from the suggestions subcollection:
  /// that collection is members-only, and an anonymous link holder has no uid
  /// for a security rule to match on. Without it "the band decides" is
  /// invisible to the person who asked.
  final List<EventSuggestion> mySuggestions;

  bool canSee(String area) => canViewArea(access, area);
  bool canChange(String area) => canEditArea(access, area);

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<Map<String, dynamic>> _list(Object? v) => v is List
      ? [
          for (final e in v)
            if (e is Map) Map<String, dynamic>.from(e),
        ]
      : const [];
}

/// Callable wrappers for attaching people to ONE event without band membership.
///
/// Reads go through `getEventView` rather than Firestore because security rules
/// cannot express "only the songs in this setlist" — rules can get() a known
/// path but cannot scan a collection, so granting a guest the band's songs
/// collection would hand them the whole pool.
/// How a callable actually gets invoked. The one seam between these wrappers
/// and Firebase, so a test can assert the name and the arguments a wrapper
/// sends without standing up a mock of the whole Functions SDK.
typedef CallableInvoker =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> args,
    );

class EventShareService {
  EventShareService({FirebaseFunctions? functions, CallableInvoker? invoker})
    : _functions = functions,
      _invoker = invoker;

  // Resolved on first use, not in the initializer: touching
  // FirebaseFunctions.instance needs an initialized Firebase app, which a unit
  // test supplying its own invoker has no reason to stand up.
  final FirebaseFunctions? _functions;
  final CallableInvoker? _invoker;

  static final _options = HttpsCallableOptions(
    timeout: const Duration(seconds: 30),
  );

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> args,
  ) async {
    // Nulls are stripped rather than sent: the callables treat a missing key
    // and an explicit null differently (token vs bandId/setlistId identify the
    // caller), so sending `token: null` alongside a bandId is not the same
    // request as sending no token at all.
    final payload = {
      for (final e in args.entries)
        if (e.value != null) e.key: e.value,
    };
    final invoker = _invoker;
    if (invoker != null) return invoker(name, payload);
    final result = await (_functions ?? FirebaseFunctions.instance)
        .httpsCallable(name, options: _options)
        .call<Map<String, dynamic>>(payload);
    return Map<String, dynamic>.from(result.data);
  }

  /// Creates a share link for one person on the roster.
  ///
  /// The raw token is returned ONCE and never stored — only its hash is kept
  /// server-side, so this is the only moment the link can be captured.
  Future<String> createShare({
    String? bandId,
    String? ownerUid,
    required String setlistId,
    required String participantId,
  }) async {
    final out = await _call('createEventShare', {
      'bandId': bandId,
      'ownerUid': ownerUid,
      'setlistId': setlistId,
      'participantId': participantId,
    });
    return out['token'] as String? ?? '';
  }

  Future<void> revokeShare(String tokenId) =>
      _call('revokeEventShare', {'tokenId': tokenId});

  /// The one read path: a share [token], or a signed-in member/guest asking for
  /// [bandId]/[setlistId].
  Future<EventView> getEventView({
    String? token,
    String? bandId,
    String? ownerUid,
    String? setlistId,
  }) async {
    final out = await _call('getEventView', {
      'token': token,
      'bandId': bandId,
      'ownerUid': ownerUid,
      'setlistId': setlistId,
    });
    return EventView.fromMap(out);
  }

  /// Binds a share link to the signed-in account — the link → sign in → edit
  /// path. Afterwards the security rules let them work directly.
  Future<Map<String, dynamic>> claimShare(String token) =>
      _call('claimEventShare', {'token': token});

  Future<void> submitSuggestion({
    String? token,
    String? bandId,
    String? ownerUid,
    String? setlistId,
    required String type,
    String? songId,
    String? text,
  }) => _call('submitSuggestion', {
    'token': token,
    'bandId': bandId,
    'ownerUid': ownerUid,
    'setlistId': setlistId,
    'type': type,
    'songId': songId,
    'text': text,
  });

  Future<void> resolveSuggestion({
    String? bandId,
    String? ownerUid,
    required String setlistId,
    required String suggestionId,
    required bool accept,
  }) => _call('resolveSuggestion', {
    'bandId': bandId,
    'ownerUid': ownerUid,
    'setlistId': setlistId,
    'suggestionId': suggestionId,
    'accept': accept,
  });
}
