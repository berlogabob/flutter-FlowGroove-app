import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/section_span.dart';
import 'package:flowgroove/models/canonical_song.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/repositories/canonical_song_repository.dart';
import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/models/metronome_session.dart';
import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/rehearsal.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/analytics_consent_provider.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/backing_transport_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/drum_practice_provider.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flowgroove/services/audio/midi/drum_player.dart';
import 'package:flowgroove/providers/data/midi_song_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/data/midi_song_practice_provider.dart';
import 'package:flowgroove/providers/haptics_provider.dart';
import 'package:flowgroove/providers/homework_provider.dart';
import 'package:flowgroove/providers/keep_screen_on_provider.dart';
import 'package:flowgroove/providers/practice_stats_provider.dart';
import 'package:flowgroove/providers/theme_mode_provider.dart';
import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/repositories/song_repository.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/services/band_function_service.dart';
import 'package:flowgroove/services/connectivity_service.dart';
import 'package:flowgroove/services/idea_recorder.dart';
import 'package:flowgroove/services/last_practice_context.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';
import '../helpers/mocks.mocks.dart';
import '../helpers/routed_test_harness.dart';

const kFixtureIds = {
  'band': 'band1',
  'song': 'song1',
  'setlist': 'setlist1',
  'rehearsal': 'reh1',
  'invite': 'INVITE1',
};

Future<void> setupRenderApiKeys() async {
  setupFirebaseCoreMocks();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
    StandardMessageCodec(),
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockDecodedMessageHandler<Object?>(channel, (message) async {
        final arguments =
            (message! as List<Object?>).first as Map<Object?, Object?>;
        if (arguments['functionName'] != 'listApiKeys') {
          throw StateError('Unexpected API key operation');
        }
        return [
          {
            'keys': [
              {
                'id': 'key1',
                'scope': 'read',
                'label': 'Test key',
                'prefix': 'sk_7f3a',
              },
            ],
          },
        ];
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(channel, null),
  );
  await Firebase.initializeApp();
}

Future<void> setupRenderTelegram() async {
  setupFirebaseCoreMocks();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
    StandardMessageCodec(),
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockDecodedMessageHandler<Object?>(channel, (message) async {
        final arguments =
            (message! as List<Object?>).first! as Map<Object?, Object?>;
        if (arguments['functionName'] != 'createTelegramLinkToken') {
          throw StateError('Unexpected Telegram operation');
        }
        return [
          {'token': 'token1'},
        ];
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(channel, null),
  );
  await Firebase.initializeApp();
}

/// The public invite callable answers with the band the spec shows.
Future<void> setupRenderBandInvite() async {
  setupFirebaseCoreMocks();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
    StandardMessageCodec(),
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockDecodedMessageHandler<Object?>(channel, (message) async {
        final arguments =
            (message! as List<Object?>).first! as Map<Object?, Object?>;
        if (arguments['functionName'] != 'getBandInviteInfo') {
          throw StateError('Unexpected invite operation');
        }
        return [
          {'bandId': 'band1', 'name': 'The Midnight Owls', 'memberCount': 4},
        ];
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(channel, null),
  );
  await Firebase.initializeApp();
}

class RenderLabRepository extends Mock implements FirestoreLabRepository {}

class RenderSongRepository extends Mock implements SongRepository {
  @override
  Future<List<Song>> getSongs(String uid) async => [
    MockDataHelper.createMockSong(id: 'song1', title: 'First Song'),
  ];
}

String fillRoute(String route) =>
    route.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (match) {
      return kFixtureIds[match[1]] ??
          (throw ArgumentError('no fixture for ${match[0]}'));
    });

/// Extra provider overrides for one key, applied after the shared ones (the
/// later override of a provider wins): the real screen, populated data.
SongLabEntry _drumEntry(String id, String title, {bool full = false}) =>
    SongLabEntry(
      id: id,
      songId: 'song1',
      type: LabEntryType.midi,
      title: title,
      authorId: 'user',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      midi: MidiPattern(
        name: title,
        bars: 1,
        beatsPerBar: 4,
        stepsPerBeat: 4,
        hits: [
          for (final (note, steps) in [
            (36, [0, 4]),
            (38, [2, 6]),
            (42, [0, 2, 4, 6]),
            if (full) (50, [4]),
            if (full) (49, [0]),
          ])
            for (final step in steps) MidiHit(step: step, note: note, vel: 90),
        ],
      ).toJson(),
    );

final _launchpadSong =
    MockDataHelper.createMockSong(
      id: 'song1',
      title: 'Wonderwall',
      artist: 'Oasis',
      bandId: 'band1',
    ).copyWith(
      sections: [
        Section(id: 'intro', name: 'Intro', duration: 4),
        Section(id: 'verse', name: 'Verse', duration: 16),
        Section(id: 'chorus', name: 'Chorus', duration: 16),
        Section(id: 'bridge', name: 'Bridge', duration: 8),
      ],
    );

final _launchpadEntry = SongLabEntry(
  id: 'midi',
  songId: 'song1',
  bandId: 'band1',
  type: LabEntryType.midi,
  title: 'Backing',
  authorId: 'user',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  midiSong: const MidiSongMeta(
    fileUrl: 'backing.mid',
    ppq: 480,
    initialBpm: 120,
    tracks: [],
  ),
);

class _LaunchpadMetronome extends MetronomeNotifier {
  @override
  MetronomeState build() => MetronomeState.initial().copyWith(
    bpm: 120,
    loadedSong: _launchpadSong,
    sourceBandId: 'band1',
  );
}

/// Section pads without the audio engine: the transport only reports state.
class _LaunchpadTransport extends BackingTransportNotifier {
  @override
  BackingTransportState build() => const BackingTransportState(
    spans: [
      SectionSpan(sectionId: 'intro', startBar: 0, bars: 4),
      SectionSpan(sectionId: 'verse', startBar: 4, bars: 16),
      SectionSpan(sectionId: 'chorus', startBar: 20, bars: 16),
      SectionSpan(sectionId: 'bridge', startBar: 36, bars: 8),
    ],
    playingId: 'chorus',
  );

  @override
  Future<void> attach(SongLabEntry entry, List<Section> sections) async {}
}

SongLabEntry _recording(
  String id,
  String? title,
  DateTime at, {
  String? body,
  List<AudioMarker> notes = const [],
}) => SongLabEntry(
  id: id,
  songId: ideaInboxSongId,
  type: LabEntryType.recording,
  title: title,
  body: body,
  notes: notes,
  attachmentIds: const ['https://example.com/take.aac'],
  authorId: 'test-user-id',
  createdAt: at,
  updatedAt: at,
);

final _weekend = Rehearsal(
  id: 'reh1',
  bandId: 'band1',
  createdBy: 'test-user-id',
  title: 'Weekend rehearsal',
  location: 'The Practice Room',
  notes: 'Bring your ideas for the new setlist.',
  responseDeadline: DateTime(2026, 7, 3, 18),
  requiredMemberUids: const ['test-user-id', 'alex', 'sam'],
  candidateSlots: [
    CandidateSlot(
      id: 's1',
      startTime: DateTime(2026, 7, 4, 19),
      endTime: DateTime(2026, 7, 4, 21),
    ),
    CandidateSlot(
      id: 's2',
      startTime: DateTime(2026, 7, 5, 18),
      endTime: DateTime(2026, 7, 5, 20),
    ),
  ],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

List<Object> _rehearsalOverrides(
  Rehearsal rehearsal,
  List<BandMember> members, {
  Map<String, RehearsalVote> votes = const {},
  List<Setlist> setlists = const [],
}) {
  final user = MockUser();
  when(user.uid).thenReturn('test-user-id');
  final key = ('band1', rehearsal.id);
  return [
    currentUserProvider.overrideWith((ref) => AsyncValue.data(user)),
    bandsProvider.overrideWith(
      (ref) => Stream.value([
        MockDataHelper.createMockBand(
          id: 'band1',
          name: 'Test Band',
        ).copyWith(members: members),
      ]),
    ),
    bandSetlistsProvider('band1').overrideWith((ref) => Stream.value(setlists)),
    rehearsalProvider(key).overrideWith((ref) => Stream.value(rehearsal)),
    rehearsalVotesProvider(key).overrideWith((ref) => Stream.value(votes)),
  ];
}

final _rehearsalMembers = [
  BandMember(
    uid: 'test-user-id',
    role: BandMember.roleAdmin,
    displayName: 'Riley',
  ),
  BandMember(uid: 'alex', role: BandMember.roleEditor, displayName: 'Alex'),
  BandMember(uid: 'sam', role: BandMember.roleEditor, displayName: 'Sam'),
];

/// A drum player that makes no sound and never reaches the audio plugin.
class _SilentDrumPlayer implements DrumPlayer {
  @override
  bool get playing => false;

  @override
  Stream<int> get stepStream => const Stream.empty();

  @override
  Future<void> load(MidiPattern p, double bpm) async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void setLaneGain(DrumLane lane, double gain) {}

  @override
  Future<void> dispose() async {}
}

final kKeyOverrides = <String, List<Object> Function()>{
  'song_page': () => [
    songsProvider.overrideWith(
      (ref) => Stream.value([
        MockDataHelper.createMockSong(
          id: 'song1',
          title: 'Wonderwall',
          artist: 'Oasis',
          originalKey: 'F#m',
          ourKey: 'F#m',
          originalBPM: 87,
          ourBPM: 87,
        ).copyWith(
          sections: [
            Section(
              id: 'verse',
              name: 'Verse 1',
              chordChart:
                  '[F#m]Today is gonna be [A]the day\n'
                  "[E]That they're gonna throw [B]it back to you",
            ),
            Section(
              id: 'chorus',
              name: 'Chorus',
              chordChart:
                  '[D]And all the [F#m]roads we have to [A]walk\n'
                  '[E]are winding',
            ),
          ],
        ),
      ]),
    ),
  ],
  'song_lab': () => [
    songsProvider.overrideWith(
      (ref) => Stream.value([
        MockDataHelper.createMockSong(
          id: 'song1',
          title: 'City Lights – Live at the Harbour',
          artist: 'The Glass Birds',
        ),
      ]),
    ),
    labEntriesProvider(('song1', null)).overrideWith(
      (ref) => Stream.value([
        SongLabEntry(
          id: 'note1',
          songId: 'song1',
          type: LabEntryType.note,
          title: 'Imported notes',
          body:
              'The live version is the reference recording. Build into the '
              'final chorus.',
          authorId: 'test-user-id',
          createdAt: DateTime(2026, 11, 18),
          updatedAt: DateTime(2026, 11, 18),
        ),
      ]),
    ),
  ],
  'song_duplicates': () => [
    songsProvider.overrideWith(
      (ref) => Stream.value([
        for (final (id, title, artist, linked) in [
          ('w1', 'Wonderwall', 'Oasis', false),
          ('w2', 'Wonderwall', 'Oasis', true),
          ('w3', 'Wonder Wall', 'Oasis', false),
          ('v1', 'Valerie', 'Amy Winehouse', false),
          ('v2', 'Valerie', 'Amy Winehouse', true),
          ('s1', 'Seven Nation Army', 'The White Stripes', false),
          ('s2', 'Seven Nation Army', 'White Stripes', false),
        ])
          MockDataHelper.createMockSong(
            id: id,
            title: title,
            artist: artist,
          ).copyWith(canonicalSongId: linked ? 'canon-$id' : null),
      ]),
    ),
  ],
  'rehearsal_detail': () => _rehearsalOverrides(
    _weekend,
    _rehearsalMembers,
    votes: {
      'test-user-id': RehearsalVote(
        uid: 'test-user-id',
        updatedAt: DateTime(2026),
        answers: const {'s1': 'can', 's2': 'maybe'},
      ),
      'alex': RehearsalVote(
        uid: 'alex',
        updatedAt: DateTime(2026),
        answers: const {'s1': 'can', 's2': 'cant'},
        comment: 'Could we start an hour later?',
      ),
    },
  ),
  'rehearsal_edit': () => _rehearsalOverrides(
    Rehearsal(
      id: 'reh1',
      bandId: 'band1',
      createdBy: 'test-user-id',
      title: 'Thursday rehearsal',
      notes: 'Work on transitions between songs.',
      requiredMemberUids: const ['alex'],
      optionalMemberUids: const ['sam'],
      setlistId: 'autumn',
      candidateSlots: [
        CandidateSlot(
          id: 's1',
          startTime: DateTime(2026, 11, 19, 19),
          endTime: DateTime(2026, 11, 19, 21),
        ),
        CandidateSlot(
          id: 's2',
          startTime: DateTime(2026, 11, 21, 14),
          endTime: DateTime(2026, 11, 21, 16),
        ),
      ],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    [
      ..._rehearsalMembers.take(1),
      BandMember(uid: 'alex', role: BandMember.roleEditor, displayName: 'Alex'),
      BandMember(uid: 'sam', role: BandMember.roleEditor, displayName: 'Sam'),
      BandMember(
        uid: 'jordan',
        role: BandMember.roleEditor,
        displayName: 'Jordan',
      ),
    ],
    setlists: [
      MockDataHelper.createMockSetlist(
        id: 'autumn',
        bandId: 'band1',
        name: 'Autumn set',
        songIds: const [],
      ),
    ],
  ),
  'profile': () {
    final user = MockUser();
    when(user.uid).thenReturn('test-user-id');
    when(user.email).thenReturn('riley@example.com');
    return [
      currentUserProvider.overrideWith((ref) => AsyncValue.data(user)),
      appUserProvider.overrideWith(
        () => TestAppUserNotifier(
          MockDataHelper.createMockAppUser(
            displayName: 'Riley Lane',
            email: 'riley@example.com',
            bandIds: ['band1'],
          ).copyWith(musicRoles: const ['guitarist', 'vocalist']),
        ),
      ),
    ];
  },
  'practice': () => [
    lastPracticeContextProvider.overrideWith(
      (ref) async => LastPracticeContext(
        songId: 'w',
        title: 'Wonderwall',
        bpm: 87,
        updatedAt: DateTime(2026, 1, 15),
      ),
    ),
    songsProvider.overrideWith(
      (ref) => Stream.value([
        MockDataHelper.createMockSong(id: 'w', title: 'Wonderwall'),
        MockDataHelper.createMockSong(id: 'v', title: 'Valerie'),
      ]),
    ),
    practiceStatsProvider.overrideWith(
      (ref) async => const PracticeStats(
        totalSecondsThisWeek: 5100,
        sessionCountThisWeek: 5,
        streakDays: 3,
        dailySeconds: [0, 600, 0, 1200, 600, 1500, 1200],
        perSongSeconds: {'w': 2400, 'v': 1680, '': 1020},
      ),
    ),
    practiceSessionsProvider.overrideWith(
      (ref) async => [
        MetronomeSession(
          id: 's1',
          // The screen groups by the real clock, not the pinned render clock.
          startedAt: DateTime.now(),
          startBpm: 87,
          songId: 'w',
          songTitle: 'Wonderwall',
          regionName: 'Chorus',
          elapsedSeconds: 1200,
          loopReps: 4,
        ),
      ],
    ),
    // The spec shows the list while it loads.
    myHomeworkProvider.overrideWith(
      (ref) => Completer<List<HomeworkItem>>().future,
    ),
  ],
  'recorder': () => [
    labEntriesProvider((ideaInboxSongId, null)).overrideWith(
      (ref) => Stream.value([
        _recording(
          'r1',
          'Chorus idea',
          DateTime(2026, 11, 16),
          notes: [
            (ms: 42000, text: 'Good chorus entry'),
            (ms: 75000, text: 'Tempo drops'),
          ],
        ),
        _recording('r2', null, DateTime(2026, 11, 12), body: 'Guitar riff'),
        _recording(
          'r3',
          'Verse melody',
          DateTime(2026, 11, 8),
          notes: [(ms: 1000, text: 'Hum')],
        ),
      ]),
    ),
  ],
  'metronome_launchpad': () {
    final user = MockUser();
    when(user.uid).thenReturn('test-user-id');
    return [
      metronomeProvider.overrideWith(_LaunchpadMetronome.new),
      backingTransportProvider.overrideWith(_LaunchpadTransport.new),
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      labEntriesProvider(('song1', 'band1'))
          .overrideWith((ref) => Stream.value([_launchpadEntry])),
      midiSongProvider(_launchpadEntry).overrideWith(
        (ref) async => const MidiSongData(
          ppq: 480,
          tempos: [],
          timeSigs: [],
          tracks: [
            MidiTrackData(
              index: 0,
              name: 'Drum kit',
              channel: 9,
              program: 0,
              notes: [MidiNote(tick: 0, dur: 480, pitch: 36, vel: 100)],
            ),
            MidiTrackData(
              index: 1,
              name: 'Bass',
              channel: 0,
              program: 33,
              notes: [MidiNote(tick: 0, dur: 30720, pitch: 40, vel: 100)],
            ),
          ],
        ),
      ),
    ];
  },
  'join_band': () {
    final user = MockUser();
    when(user.uid).thenReturn('test-user-id');
    return [currentUserProvider.overrideWith((ref) => AsyncValue.data(user))];
  },
  'home_rehearsals': () => [
    bandsProvider.overrideWith(
      (ref) => Stream.value([
        for (final (i, name) in [
          'FlowGroove',
          'The Neon Skyline',
          'Midnight Canvas',
          'Solar Flare',
          'Paper Planes Quartet',
        ].indexed)
          MockDataHelper.createMockBand(id: 'band$i', name: name),
      ]),
    ),
  ],
  'event_kit_editor_sheet_l181': () => [
    bandsProvider.overrideWith(
      (ref) => Stream.value([
        MockDataHelper.createMockBand(id: 'band1', name: 'Test Band').copyWith(
          members: [
            BandMember(
              uid: 'dana',
              role: BandMember.roleAdmin,
              displayName: 'Dana Rivera',
              musicRoles: const ['guitarist', 'vocalist'],
            ),
            BandMember(
              uid: 'marcus',
              role: BandMember.roleEditor,
              displayName: 'Marcus Lee',
              musicRoles: const ['bassist', 'backing_vocalist'],
            ),
            BandMember(
              uid: 'priya',
              role: BandMember.roleEditor,
              displayName: 'Priya Nair',
              musicRoles: const ['keyboardist', 'backing_vocalist'],
            ),
          ],
        ),
      ]),
    ),
  ],
  'drum_grid_editor': () => [
    drumPlayerProvider.overrideWith((ref) => _SilentDrumPlayer()),
    labEntriesProvider(('song1', null)).overrideWith(
      (ref) => Stream.value([_drumEntry('groove', 'Groove A', full: true)]),
    ),
  ],
  'drum_practice_panel': () => [
    drumPlayerProvider.overrideWith((ref) => _SilentDrumPlayer()),
    labEntriesProvider(('song1', 'band1')).overrideWith(
      (ref) => Stream.value([
        _drumEntry('d1', 'Warmup Riff'),
        _drumEntry('d2', 'Power Ballad'),
      ]),
    ),
  ],
  'create_setlist': () => [
    songsProvider.overrideWith(
      (ref) => Stream.value([
        MockDataHelper.createMockSong(
          id: 'w',
          title: 'Wonderwall',
          artist: 'Oasis',
          originalKey: 'F#m',
          ourKey: 'F#m',
          originalBPM: 87,
          ourBPM: 87,
        ),
        MockDataHelper.createMockSong(
          id: 's',
          title: 'Seven Nation Army',
          artist: 'The White Stripes',
          originalKey: 'Em',
          ourKey: 'Em',
          originalBPM: 124,
          ourBPM: 124,
        ),
        MockDataHelper.createMockSong(
          id: 'v',
          title: 'Valerie',
          artist: 'Amy Winehouse',
          originalKey: 'Eb',
          ourKey: 'Eb',
          originalBPM: 106,
          ourBPM: 106,
        ),
      ]),
    ),
  ],
  'canonical_browse': () => [
    canonicalSongRepositoryProvider.overrideWith(
      (ref) => _RenderCanonicalRepository(),
    ),
  ],
};

List<Object> renderOverrides({String? key}) {
  SharedPreferences.setMockInitialValues({});
  final auth = MockFirebaseAuth();
  when(auth.currentUser).thenReturn(null);
  final user = MockDataHelper.createMockAppUser(bandIds: ['band1']);
  final songs = [
    MockDataHelper.createMockSong(
      id: 'song1',
      title: 'First Song',
      originalKey: 'F#m',
      ourKey: 'F#m',
      originalBPM: 87,
      ourBPM: 87,
      bandId: 'band1',
    ),
    MockDataHelper.createMockSong(
      id: 'song2',
      title: 'Second Song',
      originalKey: 'Em',
      ourKey: 'Em',
      originalBPM: 124,
      ourBPM: 124,
      bandId: 'band1',
    ),
    MockDataHelper.createMockSong(
      id: 'song3',
      title: 'Third Song',
      originalKey: 'Eb',
      ourKey: 'Eb',
      originalBPM: 106,
      ourBPM: 106,
      bandId: 'band1',
    ),
  ];
  final band = MockDataHelper.createMockBand(
    id: 'band1',
    name: 'Test Band',
    description: 'A group of friends playing songs together.',
    inviteCode: 'INVITE1',
    members: [
      BandMember(
        uid: user.uid,
        role: BandMember.roleAdmin,
        displayName: 'Test User',
      ),
      BandMember(
        uid: 'member2',
        role: BandMember.roleEditor,
        displayName: 'Test Member Two',
      ),
      BandMember(
        uid: 'member3',
        role: BandMember.roleViewer,
        displayName: 'Test Member Three',
      ),
    ],
  ).copyWith(tags: const ['rock', 'funk', 'original']);
  final setlist = MockDataHelper.createMockSetlist(
    id: 'setlist1',
    bandId: band.id,
    name: 'Gig Setlist',
    songIds: songs.map((song) => song.id).toList(),
  );
  final rehearsal = Rehearsal(
    id: 'reh1',
    bandId: band.id,
    createdBy: user.uid,
    title: 'Test Rehearsal',
    setlistId: setlist.id,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
  final shared = [
    offlineProvider.overrideWith((ref) => false),
    firebaseAuthProvider.overrideWith((ref) => auth),
    firebaseFirestoreProvider.overrideWith(
      (ref) => throw StateError('Firestore unavailable in renders'),
    ),
    firestoreProvider.overrideWith((ref) => MockFirestoreService()),
    bandFunctionServiceProvider.overrideWith((ref) => _RenderBandFunctions()),
    appUserProvider.overrideWith(() => TestAppUserNotifier(user)),
    songsProvider.overrideWith((ref) => Stream.value(songs)),
    bandsProvider.overrideWith((ref) => Stream.value([band])),
    setlistsProvider.overrideWith((ref) => Stream.value([setlist])),
    guestEventsProvider.overrideWith((ref) => Stream.value([])),
    bandSongsProvider(band.id).overrideWith((ref) => Stream.value(songs)),
    bandSetlistsProvider(band.id)
        .overrideWith((ref) => Stream.value([setlist])),
    bandRehearsalsProvider(band.id)
        .overrideWith((ref) => Stream.value([rehearsal])),
    rehearsalProvider((band.id, rehearsal.id))
        .overrideWith((ref) => Stream.value(rehearsal)),
    rehearsalVotesProvider((band.id, rehearsal.id))
        .overrideWith((ref) => Stream.value({})),
    metronomeProvider.overrideWith(_RenderMetronome.new),
    tunerProvider.overrideWith(_RenderTuner.new),
    midiSongPracticeProvider(kRenderMidiEntry)
        .overrideWith(() => _RenderMidiPractice(kRenderMidiEntry)),
    labEntriesProvider((ideaInboxSongId, null))
        .overrideWith((ref) => Stream.value([])),
    labEntriesProvider(('song1', null)).overrideWith((ref) => Stream.value([])),
    labTasksProvider(('song1', null)).overrideWith((ref) => Stream.value([])),
    practiceStatsProvider.overrideWith((ref) async => PracticeStats.empty),
    practiceSessionsProvider.overrideWith((ref) async => []),
    myHomeworkProvider.overrideWith((ref) async => []),
    keepScreenOnProvider.overrideWith(_RenderKeepScreenOn.new),
    hapticsEnabledProvider.overrideWith(_RenderHapticsEnabled.new),
    analyticsConsentProvider.overrideWith(_RenderAnalyticsConsent.new),
    themeModeProvider.overrideWith(_RenderThemeMode.new),
  ];
  final extra = kKeyOverrides[key]?.call() ?? const <Object>[];
  // A container rejects two overrides of one provider: the key's wins.
  final replaced = {for (final o in extra) (o as dynamic).origin};
  return [
    for (final o in shared)
      if (!replaced.contains((o as dynamic).origin)) o,
    ...extra,
  ];
}

class _RenderCanonicalRepository extends Mock
    implements CanonicalSongRepository {
  @override
  Future<List<CanonicalSong>> search({
    required String query,
    int limit = 20,
  }) async => [
    _canonical('1', 'All You Need Is Love', 'The Beatles', 'G', 103, 5),
    _canonical('2', 'Crazy in Love', 'Beyoncé', 'Dm', 99, 5),
    _canonical('3', 'Love Me Do', 'The Beatles', 'G', 147, 4),
    _canonical('4', 'Whole Lotta Love', 'Led Zeppelin', 'E', 89, 5),
  ];
}

CanonicalSong _canonical(
  String id,
  String title,
  String artist,
  String key,
  int bpm,
  int sections,
) => CanonicalSong(
  id: id,
  title: title,
  artist: artist,
  baseKey: key,
  baseBpm: bpm,
  baseSections: [
    for (var i = 0; i < sections; i++) Section(id: '$id-$i', name: 'Verse'),
  ],
);

class _RenderBandFunctions extends Mock implements BandFunctionService {
  @override
  Future<BandInviteInfo> getBandInviteInfo(String code) async =>
      const BandInviteInfo(
        bandId: 'band1',
        name: 'Test Band',
        memberCount: 3,
        adminName: 'Test User',
      );
}

class _RenderMetronome extends MetronomeNotifier {
  @override
  MetronomeState build() => MetronomeState.initial();
}

class _RenderTuner extends TunerNotifier {
  @override
  TunerState build() => const TunerState();

  @override
  Future<void> stopAll() async {}
}

class _RenderKeepScreenOn extends KeepScreenOn {
  @override
  bool build() => true;
}

class _RenderHapticsEnabled extends HapticsEnabled {
  @override
  bool build() => true;
}

class _RenderAnalyticsConsent extends AnalyticsConsent {
  @override
  bool build() => true;
}

class _RenderThemeMode extends AppThemeMode {
  @override
  ThemeMode build() => ThemeMode.light;
}

const _kMidiTracks = [
  MidiTrackMeta(
    index: 2,
    name: 'Electric bass',
    channel: 0,
    program: 33,
    detectedRole: MidiRole.bass,
    noteCount: 20,
    minPitch: 28,
    maxPitch: 48,
  ),
  MidiTrackMeta(
    index: 4,
    name: 'Piano',
    channel: 1,
    program: 0,
    detectedRole: MidiRole.keys,
    noteCount: 30,
    minPitch: 48,
    maxPitch: 84,
  ),
];

final kRenderRecording = SongLabEntry(
  id: 'recording1',
  songId: ideaInboxSongId,
  type: LabEntryType.recording,
  title: 'Test Recording',
  authorId: 'test-user-id',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

/// MIDI lab entry for the midi_song_panel render.
final kRenderMidiEntry = SongLabEntry(
  id: 'midi',
  songId: 'song1',
  type: LabEntryType.midi,
  title: 'Practice song',
  authorId: 'user',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  midiSong: const MidiSongMeta(ppq: 480, initialBpm: 120, tracks: _kMidiTracks),
);

/// Loaded state with two tracks: no player, no backing engine, no download.
class _RenderMidiPractice extends MidiSongPracticeNotifier {
  _RenderMidiPractice(super.entry);

  @override
  MidiSongPracticeState build() =>
      const MidiSongPracticeState(tracks: _kMidiTracks);

  @override
  Future<void> loadEntry({
    FutureOr<void> Function(SongLabEntry)? onPersist,
  }) async {}
}
