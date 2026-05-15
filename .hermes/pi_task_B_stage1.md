# Task B (Stage 1): Create Repository Integration Test File

**Goal:** Write a comprehensive Dart integration test file for `FirestoreSongRepository` covering v1/v2 compatibility, delta writes, setlist stability, metronome settings, and CSV import.

**File:** `test/repositories/firestore_song_repository_integration_test.dart`

**Instructions:**
- Do NOT run tests now. Just create the file with all test cases.
- The test should follow Flutter integration test patterns and use the test helpers already in the project.
- Use real Firestore emulator setup via `TestHelpers.initializeFirebase()`.

**Test content to include (as separate test() blocks):**

1. `watchSongs merges legacy and v2 songs`
2. `saveSong creates legacy document when canonicalSongId is null`
3. `saveSong creates v2 library song with delta when canonicalSongId provided`
4. `updateSong updates v2 song delta and creates commit`
5. `band songs follow same v2 logic`
6. `setlist song IDs remain stable after migration`
7. `metronome settings persist in materialized song`
8. `CSV import round-trip preserves data and links to canonical when possible`

**Skeleton template:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/canonical_song.dart';
import 'package:flowgroove/models/song_delta.dart';
import 'package:flowgroove/models/library_song.dart';
import 'package:flowgroove/repositories/firestore_song_repository.dart';
import 'package:flowgroove/helpers/test_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

void main() {
  const String testUid = 'test-user-integration';
  const String testBandId = 'test-band-integration';

  setUpAll(() async {
    await TestHelpers.initializeFirebase();
  });

  tearDownAll(() async {
    await TestHelpers.cleanup();
  });

  group('FirestoreSongRepository Integration', () {
    late FirestoreSongRepository repository;

    setUp(() {
      repository = FirestoreSongRepository();
      // Clear data? Use TestHelpers to purge test collections
    });

    test('watchSongs merges legacy and v2 songs', () async {
      // Arrange: create legacy song
      final legacySong = Song(id: 'legacy1', title: 'Legacy', artist: 'Artist', createdAt: DateTime.now(), updatedAt: DateTime.now());
      await TestHelpers.seedUserSong(testUid, legacySong); // helper to write raw doc without schemaVersion

      // Arrange: create canonical and v2 library song
      final canonical = CanonicalSong(...);
      // seed canonical_songs and then create v2 LibrarySong with delta
      // ...

      // Act: listen to repository.watchSongs(testUid).first
      final songs = await repository.watchSongs(testUid).first;

      // Assert: songs length = 2, IDs preserved, v2 merged fields correct
    });

    // ... other tests
  });
}
```

**Key points:**
- Use helper methods from `TestHelpers` to seed Firestore directly (bypass repository).
- For v2 library songs, construct `LibrarySong` with fields: `schemaVersion: 2`, `canonicalSongId`, `ownerType: 'user'`, `ownerId: testUid`, `delta`, `materialized`, `latestCommitId`, `createdAt`, `updatedAt`.
- For delta, create a `SongDelta` object; its serialization to JSON must match repository expectations.
- Use `await repository.saveSong(...)` etc.
- After each test, clean up data using Firestore direct deletes or `TestHelpers.cleanup()`.
- Use `TestHelpers.awaitAsync()` to wait for emulator propagation if needed.

**Do NOT write comments like "// TODO". Provide working code where possible. If uncertain about helper availability, either define minimal helper within test file or note assumption.**

**After writing the file:**
- Use `write_file` tool to create/overwrite the file.
- Then use `read_file` to read back the first 30 lines and confirm they match your expectation.
- Finally, output a short confirmation message: "Task B stage1 done: file created with X lines."

Proceed.