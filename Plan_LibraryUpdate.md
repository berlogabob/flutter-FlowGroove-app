# Canonical Song Library + Delta Encoding Plan

## Summary
Implement the Grok recommendation as a backward-compatible linked song library: one global canonical song record for known songs, plus user/band library entries that store only personal or band-specific deltas. Existing `Song` UI, setlists, metronome, CSV, and band flows stay working while the storage layer evolves.

Current repo fit:
- `Song` is still the main UI/read model.
- `CanonicalSong` and `SongArrangement` already exist but are not wired into repository flows.
- `users/{uid}/songs` and `bands/{bandId}/songs` currently store full duplicated `Song` documents.
- `canonical_songs` already exists in Firestore rules as authenticated read-only data.
- New implementation should be additive first, then migrate data safely.

## Target Interfaces And Data Model

### Phase 1: Domain Contracts
Part 1.1: Canonical base
- Step: Extend `CanonicalSong`.
- Microsteps/tasks:
  - Add canonical performance defaults: `baseKey`, `baseBpm`, `baseSections`, `baseAccentBeats`, `baseRegularBeats`, `baseBeatModes`, `baseLinks`.
  - Add catalog metadata: `schemaVersion`, `canonicalRevision`, `source`, `status`, `createdBy`.
  - Keep external IDs: MusicBrainz, ISRC, Spotify, normalized title/artist.

Part 1.2: Delta model
- Step: Add `SongDelta`.
- Microsteps/tasks:
  - Store only owner-specific fields: `ourKey`, `ourBPM`, `notes`, `tags`, `links`, `sections`, metronome settings, optional arrangement name/type.
  - Use a typed domain delta, not generic JSON Patch for v1.
  - Add `computeDelta(canonical, song)` and `applyDelta(canonical, delta)`.

Part 1.3: Library document model
- Step: Add `LibrarySong`.
- Microsteps/tasks:
  - Store raw Firestore v2 docs under existing paths:
    - `users/{uid}/songs/{librarySongId}`
    - `bands/{bandId}/songs/{librarySongId}`
  - Fields: `schemaVersion: 2`, `canonicalSongId`, `ownerType`, `ownerId`, `baseRevision`, `delta`, `materialized`, `latestCommitId`, `createdAt`, `updatedAt`, `deletedAt`.
  - Keep `materialized` as a read fallback and rollback safety layer.
  - Keep legacy docs readable when `schemaVersion` is missing.

Part 1.4: History model
- Step: Add linear commit history.
- Microsteps/tasks:
  - Add `commits/{commitId}` below each v2 library song.
  - Fields: `parentCommitId`, `canonicalSongId`, `baseRevision`, `delta`, `operation`, `authorId`, `message`, `createdAt`, `clientMutationId`.
  - Implement create/update/delete/revert as commits.
  - Defer branching/DAG UI to a later phase.

## Implementation Plan

### Phase 0: Baseline And Safety
Part 0.1: Stabilize current canonical code
- Step: Make existing canonical files compile and export cleanly.
- Microsteps/tasks:
  - Fix repository imports for `CanonicalSongRepository`.
  - Export canonical repositories from `repositories.dart`.
  - Add provider entries for canonical repository and canonical search.
  - Add tests for current `CanonicalSong` serialization.

Part 0.2: Protect current behavior
- Step: Create regression coverage before changing storage.
- Microsteps/tasks:
  - Cover legacy `Song.fromJson`, save/update/delete, band songs, setlists by `songIds`, metronome settings, CSV import/export.
  - Confirm existing full-song docs still render after v2 code lands.

### Phase 2: Merge Engine
Part 2.1: Canonical-to-song mapper
- Step: Build a single merge service.
- Microsteps/tasks:
  - Input: `CanonicalSong?`, `LibrarySong?`, or legacy `Song`.
  - Output: existing `Song`.
  - Rules:
    - Legacy doc returns directly.
    - V2 linked doc returns canonical base plus delta.
    - If canonical is unavailable offline, use `materialized`.
    - Preserve `id` as the library song doc id so setlists remain stable.

Part 2.2: Delta builder
- Step: Build save-time delta conversion.
- Microsteps/tasks:
  - When a linked song is saved, compare form output to canonical base.
  - Store only changed owner fields in `delta`.
  - Update `materialized` with the full merged song.
  - Preserve old full-song writes for standalone/private songs.

Part 2.3: Commit writer
- Step: Use Firestore transactions for linked song updates.
- Microsteps/tasks:
  - Read current library song.
  - Create commit with `parentCommitId = latestCommitId`.
  - Update library song `delta`, `materialized`, `latestCommitId`, `updatedAt`.
  - Reject stale writes by checking latest commit/base revision inside the transaction.

### Phase 3: Repository Rewrite
Part 3.1: Personal songs
- Step: Update `FirestoreSongRepository`.
- Microsteps/tasks:
  - `watchSongs(uid)` reads legacy and v2 docs.
  - Batch-fetch needed canonical docs.
  - Merge and emit `List<Song>` to keep UI unchanged.
  - `saveSong` creates legacy standalone doc unless a canonical link exists.
  - `updateSong` updates v2 delta when `canonicalSongId` exists; otherwise legacy update.

Part 3.2: Band songs
- Step: Apply the same v2 logic to `bands/{bandId}/songs`.
- Microsteps/tasks:
  - Keep band song ids stable.
  - Use band permissions already present in rules.
  - Preserve contributor fields in `materialized`.
  - Keep setlists referencing library song ids, not canonical ids.

Part 3.3: Remove direct Firestore bypasses
- Step: Route app writes through repositories.
- Microsteps/tasks:
  - Replace direct `FirestoreService.saveSong/updateSong/saveBandSong/updateBandSong` call sites in screens/widgets with `SongRepository`.
  - Keep `FirestoreService` as a compatibility wrapper or deprecate it after call sites move.
  - Update CSV import to use repository save flow so imported songs can be canonical-linked later.

### Phase 4: Canonical Creation And Search
Part 4.1: Canonical search
- Step: Wire canonical suggestions into autocomplete.
- Microsteps/tasks:
  - Extend `SongSuggestionService` to search `canonical_songs`.
  - Merge sources in priority order: personal, band, canonical, MusicBrainz.
  - Deduplicate by external ID first, then normalized title/artist.
  - Show source badges using existing `SongSuggestion`.

Part 4.2: Canonical ensure function
- Step: Add Firebase callable function `ensureCanonicalSong`.
- Microsteps/tasks:
  - Auth required; demo users rejected.
  - Input accepts MusicBrainz/ISRC/Spotify/manual metadata.
  - First search exact external IDs.
  - Then search normalized title/artist.
  - Create canonical song only through Admin SDK.
  - Return canonical id and revision.

Part 4.3: Add-song flow
- Step: Link from suggestions.
- Microsteps/tasks:
  - Canonical suggestion selected: create v2 library song.
  - MusicBrainz suggestion selected: call `ensureCanonicalSong`, then create v2 library song.
  - Manual unknown/private song: keep standalone legacy-compatible song with `canonicalSongId = null`.
  - Existing personal/band suggestion: fork/copy by creating a new v2 library song when canonical id exists; otherwise copy legacy as today.

### Phase 5: Firestore Rules, Indexes, And Functions
Part 5.1: Rules
- Step: Keep canonical catalog server-owned.
- Microsteps/tasks:
  - `canonical_songs`: authenticated read, client write denied.
  - `users/{uid}/songs/{songId}`: owner writes v2 library docs and commits.
  - `bands/{bandId}/songs/{songId}`: band editor/admin writes v2 docs and commits; members read.
  - Validate required v2 keys where rules can safely do it.

Part 5.2: Indexes
- Step: Add indexes for canonical search and linked docs.
- Microsteps/tasks:
  - `canonical_songs.normalizedTitle`.
  - `canonical_songs.normalizedArtist`.
  - `canonical_songs.musicBrainzId`, `isrc`, `spotifyId`.
  - Collection group `songs` indexes for `canonicalSongId`, `schemaVersion`, `updatedAt`.

Part 5.3: Functions
- Step: Add admin-only catalog mutations.
- Microsteps/tasks:
  - `ensureCanonicalSong`.
  - Optional `mergeCanonicalSongs` for admin cleanup.
  - Optional `backfillCanonicalLinks` batch job after app read path is stable.

### Phase 6: Migration
Part 6.1: Read compatibility first
- Step: Deploy code that reads both schemas before rewriting data.
- Microsteps/tasks:
  - Legacy docs continue to load.
  - V2 docs load through merge engine.
  - Standalone songs remain valid.

Part 6.2: Backfill dry run
- Step: Build migration script/function with dry-run output.
- Microsteps/tasks:
  - For each legacy song, try external IDs first.
  - If no external ID, use normalized fuzzy match.
  - Only auto-link high-confidence matches.
  - Mark uncertain matches for review, do not mutate them.
  - Produce counts: linked, standalone, needs review, failed.

Part 6.3: Backfill write run
- Step: Convert safe matches.
- Microsteps/tasks:
  - Preserve document ids.
  - Write `schemaVersion: 2`, `canonicalSongId`, `delta`, `materialized`.
  - Create initial commit.
  - Keep every user-visible field recoverable.
  - Do not delete original data until monitoring passes.

Part 6.4: Rollout switch
- Step: Enable linked writes behind a feature flag.
- Microsteps/tasks:
  - Flag off: read both, write legacy.
  - Flag on for testers: read both, write v2 for linked songs.
  - Flag on globally after tests and migration metrics are clean.

## Test Plan

### Unit Tests
- `CanonicalSong` serialization with new base fields.
- `SongDelta.computeDelta` only stores changed fields.
- `SongDelta.applyDelta` produces expected merged `Song`.
- Legacy song docs still parse.
- Missing canonical falls back to `materialized`.
- Commit chain preserves parent ids.

### Repository Tests
- `watchSongs` emits merged v2 songs and legacy songs together.
- `saveSong` creates standalone doc when no canonical id exists.
- `updateSong` writes delta + commit for linked song.
- Band linked songs preserve contributor/band metadata.
- Delete uses soft delete for v2 and no longer breaks commit history.

### Widget Tests
- Add song from canonical suggestion.
- Add song from MusicBrainz suggestion through ensured canonical id.
- Edit linked song and verify only personal fields change.
- Songs list/search/filter works with merged songs.
- Band songs and setlists still use library song ids.

### Emulator/Rules Tests
- Users cannot write `canonical_songs` directly.
- Callable function can create canonical records.
- Owner can write own v2 song and commits.
- Non-owner cannot write another user’s song.
- Band member can read, editor/admin can write, viewer cannot write.
- Demo user cannot mutate linked library docs.

### Deployment Checks
- `flutter test`
- targeted repository/model tests
- `firebase emulators:exec` for Firestore rules
- `npm --prefix functions test` or function smoke tests
- `flutter analyze` after known lint backlog is separated from new errors

## Deployment And Rollback

### Release Order
1. Deploy read-compatible Flutter code with linked writes disabled.
2. Deploy Firestore rules and indexes.
3. Deploy `ensureCanonicalSong`.
4. Run migration dry run.
5. Enable linked writes for internal/test users.
6. Run safe backfill batches.
7. Enable linked writes globally.
8. Monitor errors, duplicate creation rate, canonical miss rate, and write failures.

### Rollback
- Disable linked write flag.
- Keep reading v2 docs through `materialized`.
- Do not delete legacy-compatible fields during v1.
- If a migration batch fails, retry only failed ids using `clientMutationId`/batch metadata.
- Standalone songs remain unaffected.

## Assumptions And Defaults
- V1 uses typed domain deltas, not generic JSON Patch.
- V1 supports linear history, not full DAG branching.
- Known public songs use `canonical_songs`; private originals can stay standalone.
- Existing UI keeps using `Song` as the read model.
- Existing setlists keep storing library song ids.
- Canonical writes happen only through Firebase Functions/Admin SDK.
- Migration is additive and reversible; no destructive cleanup in the first deployment.

