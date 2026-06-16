@Tags(['firebase-emulator'])
library;

import 'package:flowgroove/models/api_error.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/repositories/setlist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/firebase_emulator_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Setlist Management Flow Integration Tests - INT-SETLIST-01', () {
    late FirebaseEmulatorHarness harness;
    late ProviderContainer container;
    late SetlistRepository repository;

    setUp(() async {
      harness = await FirebaseEmulatorHarness.bootstrap();
      await harness.signOut();
      container = ProviderContainer(
        overrides: harness.providerOverrides().cast(),
      );
      repository = container.read(setlistRepositoryProvider);
    });

    tearDown(() {
      container.dispose();
    });

    Setlist buildSetlist({
      required String id,
      required String bandId,
      required String name,
      List<String> songIds = const [],
    }) {
      final now = DateTime.now();
      return Setlist(
        id: id,
        bandId: bandId,
        name: name,
        songIds: songIds,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('creates a setlist for the signed-in user', () async {
      final credential = await harness.createAndSeedUser();
      addTearDown(() async {
        await harness.clearUserData(credential.user!.uid);
      });

      final setlist = buildSetlist(
        id: harness.uniqueId('setlist'),
        bandId: harness.uniqueId('band'),
        name: 'Friday Set',
      );

      await repository.saveSetlist(setlist);

      final doc = await harness.firestore
          .collection('users')
          .doc(credential.user!.uid)
          .collection('setlists')
          .doc(setlist.id)
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['name'], 'Friday Set');
    });

    test('watchSetlists emits the created record', () async {
      final credential = await harness.createAndSeedUser();
      addTearDown(() async {
        await harness.clearUserData(credential.user!.uid);
      });

      final setlist = buildSetlist(
        id: harness.uniqueId('watch'),
        bandId: harness.uniqueId('band'),
        name: 'Watch Me',
      );

      final emittedSetlists = repository
          .watchSetlists(credential.user!.uid)
          .firstWhere((items) => items.any((item) => item.id == setlist.id));

      await repository.saveSetlist(setlist, uid: credential.user!.uid);

      final result = await emittedSetlists.timeout(const Duration(seconds: 5));
      expect(result.any((item) => item.name == 'Watch Me'), isTrue);
    });

    test('saving an existing setlist persists updated song order', () async {
      final credential = await harness.createAndSeedUser();
      addTearDown(() async {
        await harness.clearUserData(credential.user!.uid);
      });

      final setlistId = harness.uniqueId('update');
      final initial = buildSetlist(
        id: setlistId,
        bandId: harness.uniqueId('band'),
        name: 'Order Test',
        songIds: const ['song-a', 'song-b'],
      );
      final updated = initial.copyWith(songIds: const ['song-b', 'song-a']);

      await repository.saveSetlist(initial);
      await repository.saveSetlist(updated);

      final doc = await harness.firestore
          .collection('users')
          .doc(credential.user!.uid)
          .collection('setlists')
          .doc(setlistId)
          .get();

      expect(doc.data()?['songIds'], ['song-b', 'song-a']);
    });

    test('deleteSetlist removes only the setlist document', () async {
      final credential = await harness.createAndSeedUser();
      final uid = credential.user!.uid;
      addTearDown(() async {
        await harness.clearUserData(uid);
      });

      final setlist = buildSetlist(
        id: harness.uniqueId('delete'),
        bandId: harness.uniqueId('band'),
        name: 'Delete Me',
        songIds: const ['song-1'],
      );

      await harness.firestore
          .collection('users')
          .doc(uid)
          .collection('songs')
          .doc('song-1')
          .set({
            'id': 'song-1',
            'title': 'Keep Song',
            'artist': 'FlowGroove',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });

      await repository.saveSetlist(setlist);
      await repository.deleteSetlist(setlist.id);

      final setlistDoc = await harness.firestore
          .collection('users')
          .doc(uid)
          .collection('setlists')
          .doc(setlist.id)
          .get();
      final songDoc = await harness.firestore
          .collection('users')
          .doc(uid)
          .collection('songs')
          .doc('song-1')
          .get();

      expect(setlistDoc.exists, isFalse);
      expect(songDoc.exists, isTrue);
    });

    test('unauthenticated writes fail with an auth error', () async {
      await harness.signOut();

      final setlist = buildSetlist(
        id: harness.uniqueId('unauth'),
        bandId: harness.uniqueId('band'),
        name: 'Denied',
      );

      await expectLater(
        repository.saveSetlist(setlist),
        throwsA(
          isA<ApiError>().having((error) => error.type, 'type', ErrorType.auth),
        ),
      );
    });
  });
}
