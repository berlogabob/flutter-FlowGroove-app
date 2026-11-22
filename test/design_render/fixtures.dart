import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/rehearsal.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/services/connectivity_service.dart';
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
  final user = MockDataHelper.createMockAppUser(bandIds: ['band1']);
  final songs = [
    MockDataHelper.createMockSong(
      id: 'song1',
      title: 'First Song',
      bandId: 'band1',
    ),
    MockDataHelper.createMockSong(
      id: 'song2',
      title: 'Second Song',
      bandId: 'band1',
    ),
    MockDataHelper.createMockSong(
      id: 'song3',
      title: 'Third Song',
      bandId: 'band1',
    ),
  ];
  final band = MockDataHelper.createMockBand(
    id: 'band1',
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
  );
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
    firebaseAuthProvider.overrideWith(
      (ref) => throw StateError('Firebase Auth unavailable in renders'),
    ),
    firebaseFirestoreProvider.overrideWith(
      (ref) => throw StateError('Firestore unavailable in renders'),
    ),
    firestoreProvider.overrideWith((ref) => MockFirestoreService()),
    appUserProvider.overrideWith(() => TestAppUserNotifier(user)),
    songsProvider.overrideWith((ref) => Stream.value(songs)),
    bandsProvider.overrideWith((ref) => Stream.value([band])),
    setlistsProvider.overrideWith((ref) => Stream.value([setlist])),
    bandSongsProvider(band.id).overrideWith((ref) => Stream.value(songs)),
    bandRehearsalsProvider(band.id)
        .overrideWith((ref) => Stream.value([rehearsal])),
    rehearsalProvider((band.id, rehearsal.id))
        .overrideWith((ref) => Stream.value(rehearsal)),
    rehearsalVotesProvider((band.id, rehearsal.id))
        .overrideWith((ref) => Stream.value({})),
  ];
}
