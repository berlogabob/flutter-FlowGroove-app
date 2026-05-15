# Task B: Regression Coverage — Repository Integration Tests

**Goal:** Add comprehensive integration tests for `FirestoreSongRepository` ensuring v1/v2 compatibility, delta handling, and setlist stability.

**File to create:** `test/repositories/firestore_song_repository_integration_test.dart`

**Context:** The repository pattern is implemented in `lib/repositories/firestore_song_repository.dart`. Existing tests use mock repositories; we need real emulator-based tests.

**Use existing test infrastructure:**
- Use `TestHelpers.initializeFirebase()` for emulator setup (see `test/helpers/test_helpers.dart`).
- Use `FirebaseEmulatorHarness` from `test/helpers/firebase_emulator_harness.dart`.
- The repo provides `FirestoreSongRepository` which depends on `FirebaseAuth` and `FirebaseFirestore`.

**Test scenarios to cover:**

1. **Watch songs merges v1 and v2**
   - Seed Firestore with:
     - A legacy song in `users/{uid}/songs/{songId}` (no `schemaVersion` field)
     - A v2 library song in `users/{uid}/songs/{libSongId}` with `schemaVersion: 2`, `canonicalSongId`, `delta`, `materialized`
     - A v2 library song where canonical document is missing (should fallback to materialized)
   - Listen to `repository.watchSongs(uid)` and expect:
     - Both songs emitted as `Song` objects (same UI model).
     - The v2 song fields reflect merged canonical + delta.
     - IDs are preserved (librarySongId, not canonical id).

2. **Save song behavior**
   - When saving a song without `canonicalSongId`: creates legacy full-document under `users/{uid}/songs/{songId}`.
   - When saving a song with `canonicalSongId`: creates/updates v2 library song with delta and commit.
     - Write includes `schemaVersion:2`, `canonicalSongId`, `delta`, `materialized`, `latestCommitId`, `createdAt`, `updatedAt`.
   - Verify by reading back from Firestore.

3. **Update song for v2**
   - Update a v2-linked song with changed fields (e.g., ourBPM, notes). Verify:
     - Delta only contains changed fields.
     - Materialized updated.
     - New commit created with parent = previous latestCommitId.
   - Multiple updates create a linear commit chain.

4. **Band songs with v2**
   - Same behavior for `bands/{bandId}/songs`.
   - Confirm bandId owner handling and permissions (use band admin user in test).

5. **Setlist stability**
   - Create two songs (v1 and v2). Add them to a setlist document via `setlists/{setlistId}/songs` array of song IDs.
   - Perform migration operations on the songs (convert v1 to v2, update v2).
   - Verify setlist document still references the same song IDs (no breakage).

6. **Metronome settings**
   - Songs have metronome-related fields (accent beats, regular beats, beat modes). Ensure these are stored and retrieved correctly, both in v1 legacy and v2 materialized forms.

7. **CSV import round-trip**
   - Use the CSV service to import a set of songs from a CSV string. Then verify they appear in repository (legacy or v2 based on linkage). Also ensure export round-trip preserves data.

**Test structure:**
- Use `setUpAll(() => TestHelpers.initializeFirebase());`
- Use `tearDownAll(() => TestHelpers.cleanup());`
- Write each scenario as a `test('description', () async { ... })`.
- Use real `FirestoreSongRepository` obtained via `FirestoreSongRepository()` (it should obtain FirebaseAuth.instance and FirebaseFirestore.instance).
- Helper to create a test user via `TestHelpers.createTestUser(uid)`.
- Use `await TestHelpers.awaitAsync()` to handle async flakiness if needed (see existing integration tests).

**Constraints:**
- Keep tests deterministic; avoid randomness.
- Use fixed UUIDs or let Firestore generate? Better to set known IDs for reproducibility.
- Clean up documents in `tearDown` or use unique prefixes per test run.

**Deliverable:**
- A complete Dart test file under `test/repositories/` with these scenarios implemented (or as many as feasible in one pass). Include comments for any unimplemented parts.
- After creating, output a summary: number of tests added, any compilation errors, and instructions to run them locally with `flutter test test/repositories/firestore_song_repository_integration_test.dart`.

Proceed.
