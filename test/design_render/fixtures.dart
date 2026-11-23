import 'dart:async';

import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/rehearsal.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/analytics_consent_provider.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/data/midi_song_practice_provider.dart';
import 'package:flowgroove/providers/haptics_provider.dart';
import 'package:flowgroove/providers/homework_provider.dart';
import 'package:flowgroove/providers/keep_screen_on_provider.dart';
import 'package:flowgroove/providers/practice_stats_provider.dart';
import 'package:flowgroove/providers/theme_mode_provider.dart';
import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/services/band_function_service.dart';
import 'package:flowgroove/services/connectivity_service.dart';
import 'package:flowgroove/services/idea_recorder.dart';
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

String fillRoute(String route) =>
    route.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (match) {
      return kFixtureIds[match[1]] ??
          (throw ArgumentError('no fixture for ${match[0]}'));
    });

List<Object> renderOverrides() {
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
  return [
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
}

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
