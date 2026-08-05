import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/repositories/repositories.dart';
import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../helpers/metronome_test_runtime.dart';
import '../helpers/mocks.mocks.dart';

@GenerateMocks([SongRepository])
import 'metronome_tempo_autosave_test.mocks.dart';

/// Fixed-identity AppUser so `canEditBandProvider` can resolve without a
/// live auth stream — mirrors `_HomeTestAppUserNotifier` in
/// home_quick_actions_test.dart.
class _TestAppUserNotifier extends AppUserNotifier {
  _TestAppUserNotifier(this.user);

  final AppUser? user;

  @override
  AsyncValue<AppUser?> build() => AsyncValue.data(user);
}

void main() {
  group('Metronome tempo auto-save', () {
    const uid = 'user-1';

    late MetronomeTestRuntime runtime;
    late MockFirebaseAuth mockAuth;
    late MockUser mockFirebaseUser;
    late MockSongRepository mockSongRepository;
    late ProviderContainer container;

    Song buildSong({int? ourBPM = 120, int? originalBPM}) => Song(
      id: 'song-1',
      title: 'Loaded Song',
      artist: 'Artist',
      ourBPM: ourBPM,
      originalBPM: originalBPM,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    setUp(() {
      runtime = MetronomeTestRuntime();
      mockAuth = MockFirebaseAuth();
      mockFirebaseUser = MockUser();
      when(mockAuth.currentUser).thenReturn(mockFirebaseUser);
      when(mockFirebaseUser.uid).thenReturn(uid);

      mockSongRepository = MockSongRepository();
      when(
        mockSongRepository.updateSong(any, uid: anyNamed('uid')),
      ).thenAnswer((_) async {});
      when(
        mockSongRepository.updateBandSong(any, any),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      container.dispose();
      await runtime.dispose();
    });

    /// Builds the screen with the given [extraOverrides] (auth + permission
    /// wiring varies per scenario) and loads [song] into the metronome
    /// before the first pump, matching the pattern used by the existing
    /// "edit song menu" widget test.
    Future<void> pumpLoadedScreen(
      WidgetTester tester, {
      required Song song,
      required List<Override> extraOverrides,
      String? sourceBandId,
    }) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      container = ProviderContainer(
        overrides: [
          ...runtime.overrides,
          firebaseAuthProvider.overrideWithValue(mockAuth),
          songRepositoryProvider.overrideWithValue(mockSongRepository),
          ...extraOverrides,
        ],
      );

      container
          .read(metronomeProvider.notifier)
          .loadSongTempo(song, sourceBandId: sourceBandId);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(400, 800)),
              child: MetronomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'personal song: debounced tempo change saves via updateSong',
      (tester) async {
        final song = buildSong();

        await pumpLoadedScreen(
          tester,
          song: song,
          extraOverrides: const [],
        );

        container.read(metronomeProvider.notifier).setBpm(140);
        await tester.pump(const Duration(seconds: 3));

        final captured = verify(
          mockSongRepository.updateSong(captureAny, uid: uid),
        ).captured;
        expect(captured, hasLength(1));
        expect((captured.single as Song).ourBPM, 140);

        verifyNever(mockSongRepository.updateBandSong(any, any));
      },
    );

    testWidgets(
      'band song with edit rights: debounced tempo change saves via updateBandSong',
      (tester) async {
        final song = buildSong();
        final band = Band(
          id: 'b1',
          name: 'Test Band',
          createdBy: uid,
          createdAt: DateTime(2024),
          editorUids: [uid],
        );
        final appUser = AppUser(uid: uid, createdAt: DateTime(2024));

        await pumpLoadedScreen(
          tester,
          song: song,
          sourceBandId: 'b1',
          extraOverrides: [
            appUserProvider.overrideWith(() => _TestAppUserNotifier(appUser)),
            bandsProvider.overrideWith((ref) => Stream.value([band])),
          ],
        );

        container.read(metronomeProvider.notifier).setBpm(140);
        await tester.pump(const Duration(seconds: 3));

        final captured = verify(
          mockSongRepository.updateBandSong(captureAny, 'b1'),
        ).captured;
        expect(captured, hasLength(1));
        expect((captured.single as Song).ourBPM, 140);

        verifyNever(mockSongRepository.updateSong(any, uid: anyNamed('uid')));
      },
    );

    testWidgets(
      'band song without edit rights: tempo change never saves',
      (tester) async {
        final song = buildSong();
        // Band exists, but the signed-in user is neither admin nor editor.
        final band = Band(
          id: 'b1',
          name: 'Test Band',
          createdBy: 'someone-else',
          createdAt: DateTime(2024),
        );
        final appUser = AppUser(uid: uid, createdAt: DateTime(2024));

        await pumpLoadedScreen(
          tester,
          song: song,
          sourceBandId: 'b1',
          extraOverrides: [
            appUserProvider.overrideWith(() => _TestAppUserNotifier(appUser)),
            bandsProvider.overrideWith((ref) => Stream.value([band])),
          ],
        );

        container.read(metronomeProvider.notifier).setBpm(140);
        await tester.pump(const Duration(seconds: 3));

        verifyNever(mockSongRepository.updateBandSong(any, any));
        verifyNever(mockSongRepository.updateSong(any, uid: anyNamed('uid')));
      },
    );

    testWidgets(
      'coalesces rapid tempo changes into a single write',
      (tester) async {
        final song = buildSong();

        await pumpLoadedScreen(
          tester,
          song: song,
          extraOverrides: const [],
        );

        container.read(metronomeProvider.notifier).setBpm(130);
        await tester.pump(const Duration(milliseconds: 500));
        container.read(metronomeProvider.notifier).setBpm(140);
        await tester.pump(const Duration(seconds: 3));

        final captured = verify(
          mockSongRepository.updateSong(captureAny, uid: uid),
        ).captured;
        expect(captured, hasLength(1));
        expect((captured.single as Song).ourBPM, 140);
      },
    );

    testWidgets(
      "no write when BPM settles back on the song's existing ourBPM",
      (tester) async {
        final song = buildSong();

        await pumpLoadedScreen(
          tester,
          song: song,
          extraOverrides: const [],
        );

        // Change away, then back — the listener fires both times (the
        // selected bpm value changes twice), but the debounced save that
        // ultimately fires must see the tempo back where the song already
        // has it and skip the write.
        container.read(metronomeProvider.notifier).setBpm(135);
        await tester.pump(const Duration(milliseconds: 200));
        container.read(metronomeProvider.notifier).setBpm(120);
        await tester.pump(const Duration(seconds: 3));

        verifyNever(mockSongRepository.updateSong(any, uid: anyNamed('uid')));
        verifyNever(mockSongRepository.updateBandSong(any, any));
      },
    );
  });
}
