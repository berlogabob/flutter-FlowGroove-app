# Dead-Code Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove confirmed dead code (unused files, an orphaned fuzzy matcher, an unused cache-notifier layer, dead feature flags) without changing any runtime behavior.

**Architecture:** Pure deletion. Each task removes code with zero live references, then proves the app still analyzes and tests still pass. No new code, no refactors. Tasks are ordered safest-first; each is an independent commit so any single one can be reverted.

**Tech Stack:** Flutter 3.44.2 (stable), Dart, Riverpod, Firebase, Mockito-generated test mocks.

## Global Constraints

- **Verification gate (run after every task, must pass before commit):**
  - `flutter analyze lib test integration_test --no-fatal-infos --no-fatal-warnings`
  - `flutter test --exclude-tags firebase-emulator`
  - These are exactly the commands CI runs (`.github/workflows/checks.yml`).
- **No behavior change.** Every item removed is verified to have zero live (non-self, non-test-of-itself) references. If `flutter analyze` reports a NEW reference you did not expect, STOP and re-scope — do not "fix" by editing unrelated code.
- **Do NOT touch** the repository interfaces (`lib/repositories/{song,band,setlist,canonical_song}_repository.dart`) or the barrel `lib/repositories/repositories.dart`. They are mocked in tests and used as parameter types — they are load-bearing.
- **Commit hook:** the pre-commit hook blocks `google-services.json`/`AIzaSy`. None of these commits touch those, so `--no-verify` is NOT needed. If the hook fires unexpectedly, stop and inspect rather than bypassing.
- **One commit per task.** Conventional `chore:`/`test:` prefixes.

---

### Task 1: Delete orphaned `utils/fuzzy_matcher.dart`

The app uses `lib/services/matching/fuzzy_matcher.dart` (classes `Levenshtein`, `JaroWinkler`, `FuzzyMatcher`). The older `lib/utils/fuzzy_matcher.dart` (321 lines, separate `FuzzyMatcher`/`MatchResult`) has **zero importers** in `lib`, `test`, or `integration_test`.

**Files:**
- Delete: `lib/utils/fuzzy_matcher.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Re-confirm zero references (guard against drift since plan was written)**

Run: `grep -rn "utils/fuzzy_matcher" lib test integration_test`
Expected: no output (exit 1).

- [ ] **Step 2: Delete the file**

```bash
git rm lib/utils/fuzzy_matcher.dart
```

- [ ] **Step 3: Run the verification gate**

Run:
```bash
flutter analyze lib test integration_test --no-fatal-infos --no-fatal-warnings
flutter test --exclude-tags firebase-emulator
```
Expected: analyze reports no new errors; tests pass.

- [ ] **Step 4: Commit**

`git rm` already staged the deletion. Commit ONLY that (the working tree has unrelated `site/` edits from the auto-deploy loop — do NOT `git add -A`):

```bash
git commit -m "chore: delete orphaned utils/fuzzy_matcher (superseded by services/matching)"
```

---

### Task 2: Delete example/template scaffolding and the disabled Isar service

Three "example/template" files and one `.dart.disabled` file (Dart never compiles `.disabled`, and nothing imports any of them). Confirmed zero references in `lib`, `test`, `integration_test`.

**Files:**
- Delete: `lib/models/song_sharing_example.dart` (74)
- Delete: `lib/providers/data/song_sharing_provider_example.dart` (193)
- Delete: `lib/screens/tools/new_tool_template.dart` (174)
- Delete: `lib/services/database/isar_service.dart.disabled` (91)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Re-confirm zero references**

Run:
```bash
grep -rn "song_sharing_example\|song_sharing_provider_example\|SongSharing\|new_tool_template\|NewToolTemplate\|isar_service\|IsarService" lib test integration_test | grep -vE "song_sharing_example.dart|song_sharing_provider_example.dart|new_tool_template.dart|isar_service.dart.disabled"
```
Expected: no output. (Matches limited to the files being deleted are fine; any other file means STOP.)

- [ ] **Step 2: Delete the files**

```bash
git rm lib/models/song_sharing_example.dart \
       lib/providers/data/song_sharing_provider_example.dart \
       lib/screens/tools/new_tool_template.dart \
       lib/services/database/isar_service.dart.disabled
```

- [ ] **Step 3: Run the verification gate**

Run:
```bash
flutter analyze lib test integration_test --no-fatal-infos --no-fatal-warnings
flutter test --exclude-tags firebase-emulator
```
Expected: no new errors; tests pass.

- [ ] **Step 4: Commit**

`git rm` already staged the deletions. Commit ONLY those (do NOT `git add -A` — the working tree has unrelated `site/` edits):

```bash
git commit -m "chore: delete unused example/template files and disabled Isar service"
```

---

### Task 3: Delete the unused `matching/matching.dart` barrel

`lib/services/matching/matching.dart` re-exports four files but has **zero importers** — every consumer imports the concrete files directly (e.g. `song_form_provider.dart` imports `../services/matching/fuzzy_matcher.dart`).

**Files:**
- Delete: `lib/services/matching/matching.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Re-confirm zero importers**

Run: `grep -rn "matching/matching.dart" lib test integration_test`
Expected: no output (exit 1).

- [ ] **Step 2: Delete the file**

```bash
git rm lib/services/matching/matching.dart
```

- [ ] **Step 3: Run the verification gate**

Run:
```bash
flutter analyze lib test integration_test --no-fatal-infos --no-fatal-warnings
flutter test --exclude-tags firebase-emulator
```
Expected: no new errors; tests pass.

- [ ] **Step 4: Commit**

`git rm` already staged the deletion. Commit ONLY that (do NOT `git add -A`):

```bash
git commit -m "chore: delete unused matching barrel file"
```

---

### Task 4: Remove the unused cache-first notifier layer + its self-tests

`CachedSongsNotifier` / `CachedBandsNotifier` / `CachedSetlistsNotifier` and their providers (`cachedSongsProvider`, `cachedBandsProvider`, `cachedSetlistsProvider`) in `lib/providers/data/data_providers.dart` are **never read anywhere in the app** — the live UI uses `songsProvider` / `bandsProvider` / `setlistsProvider` (the `StreamProvider`s). The only thing referencing them is `test/providers/data_providers_test.dart`, which tests the dead notifiers in isolation (~50 assertions). Removing dead production code means removing the tests that exist only to test it.

> **This is the heaviest task** — the dead-notifier tests are interleaved with live-provider tests inside shared `group(...)` blocks. Do NOT delete whole groups blindly. Use the analyzer as the guide: delete the production symbols first, then the analyzer/compiler will flag every now-undefined reference in the test file; remove exactly those `test(...)` blocks (and any `group(...)` that becomes empty). Keep every test that reads `songsProvider`, `bandsProvider`, `setlistsProvider`, `songCountProvider`, `bandCountProvider`, `setlistCountProvider`, `bandSongsProvider`, `bandSetlistsProvider`, `selectedBandProvider`.
>
> **Test-scope guardrails (verified):** This is the ONLY test file that references any deletion target across the whole plan — no other `test/` or `integration_test/` file needs editing.
> - **Do NOT touch the shared `setUp(...)` block or the `@GenerateMocks([...])` annotation.** The mocked types (`SongRepository`, `BandRepository`, `SetlistRepository`, `CacheService`) are all being kept, and the surviving cache-first providers (`songsProvider`, `bandsProvider`, `bandSongsProvider`) still consume `mockCacheService`. Removing the mock setup would break the live-provider tests.
> - **Do NOT run `build_runner` / regenerate `data_providers_test.mocks.dart`.** No mocked type changes, so the generated file is unaffected.
> - Only `test(...)` blocks and now-empty `group(...)` wrappers are removed — nothing else.

**Files:**
- Modify: `lib/providers/data/data_providers.dart` (remove three notifier classes + three providers)
- Modify: `test/providers/data_providers_test.dart` (remove only the `Cached*` test blocks)

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing (removal only). The live providers `songsProvider`, `bandsProvider`, `setlistsProvider` and their `*CountProvider`s remain unchanged and keep their signatures.

- [ ] **Step 1: Re-confirm the notifiers are unused by the app (lib only)**

Run:
```bash
grep -rn "CachedSongsNotifier\|CachedBandsNotifier\|CachedSetlistsNotifier\|cachedSongsProvider\|cachedBandsProvider\|cachedSetlistsProvider" lib | grep -v "data_providers.dart"
```
Expected: no output. (Only references are inside `data_providers.dart` itself; the app does not consume them.)

- [ ] **Step 2: Remove the three notifier classes and their providers from `data_providers.dart`**

In `lib/providers/data/data_providers.dart`, delete these declarations in full (class body + the `final cached*Provider = NotifierProvider...` that follows each):
- `class CachedSongsNotifier extends Notifier<AsyncValue<List<Song>>> { ... }` and `final cachedSongsProvider = ...`
- `class CachedBandsNotifier extends Notifier<AsyncValue<List<Band>>> { ... }` and `final cachedBandsProvider = ...`
- `class CachedSetlistsNotifier extends Notifier<AsyncValue<List<Setlist>>> { ... }` and `final cachedSetlistsProvider = ...`

**Do NOT remove** `SelectedBandNotifier` / `selectedBandProvider` (sits between them), nor any `StreamProvider` (`songsProvider`, `bandsProvider`, `setlistsProvider`, `bandSongsProvider`, `bandSetlistsProvider`), nor the `*CountProvider`s.

If `dart:async`'s `StreamSubscription` import becomes unused after removal, leave the import — analyzer will flag it as an info (non-fatal) and a later lint pass can drop it; removing it is fine too if analyzer flags it.

- [ ] **Step 3: Run analyze to surface every dead test reference**

Run: `flutter analyze test/providers/data_providers_test.dart`
Expected: a list of `undefined_identifier` / `undefined_method` errors pointing at each `cached*Provider` / `Cached*Notifier` usage in the test file. These line numbers are your removal checklist.

- [ ] **Step 4: Remove only the flagged `Cached*` test blocks**

For each error location, remove the enclosing `test('...Cached...', () { ... });` block. Remove any `group('...', () { ... })` that is left with no `test(...)` inside (these groups become empty: `Dispose Verification`, `State Updates`, `Timeout Error Handling` are entirely `Cached*` — confirm each is empty before deleting the group). Leave all live-provider tests intact.

- [ ] **Step 5: Run analyze until clean**

Run: `flutter analyze lib test integration_test --no-fatal-infos --no-fatal-warnings`
Expected: no errors. Repeat Step 4 if any `Cached*` reference remains.

- [ ] **Step 6: Run the test gate**

Run: `flutter test --exclude-tags firebase-emulator`
Expected: all tests pass; the remaining `data_providers_test.dart` tests (live providers) still run green.

- [ ] **Step 7: Commit**

Stage ONLY the two touched files (do NOT `git add -A` — the working tree has unrelated `site/` edits):

```bash
git add lib/providers/data/data_providers.dart test/providers/data_providers_test.dart
git commit -m "chore: remove unused cache-first notifier layer and its self-tests"
```

---

### Task 5: Remove dead metronome feature flags

In `lib/config/metronome_feature_flags.dart`, five flags are **never read anywhere** (the gated features are always-on regardless of the flag, so removal changes nothing): `enableToneMatrix`, `enable2DBeatModes`, `enableAudioFocus`, `enableSubdivisionPitch`, `enableMonoPulseTheme`. Also remove their entries from the `featureStatus` debug map.

**Keep:** `enableUnifiedEngine` and `enablePcmTimelineEngine` (real branches in `metronome_runtime_providers.dart`) and `enableOptimizedAudio` (read by `metronome_analytics.dart` for tagging).

**Files:**
- Modify: `lib/config/metronome_feature_flags.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Re-confirm the five flags are unread outside the flags file**

Run:
```bash
grep -rn "enableToneMatrix\|enable2DBeatModes\|enableAudioFocus\|enableSubdivisionPitch\|enableMonoPulseTheme" lib test integration_test | grep -v "metronome_feature_flags.dart"
```
Expected: no output. (If anything appears, exclude that flag from this task and keep it.)

- [ ] **Step 2: Remove the five flag declarations and their doc comments**

Delete the `static const bool enableToneMatrix = ...;`, `enable2DBeatModes`, `enableAudioFocus`, `enableSubdivisionPitch`, `enableMonoPulseTheme` lines (and the `///` doc comment block immediately above each).

- [ ] **Step 3: Remove the five matching keys from the `featureStatus` map**

In `static Map<String, bool> get featureStatus => { ... }`, delete the `'enableToneMatrix': ...,` `'enableMonoPulseTheme': ...,` `'enable2DBeatModes': ...,` `'enableAudioFocus': ...,` `'enableSubdivisionPitch': ...,` entries. The map keeps `enableUnifiedEngine`, `enableOptimizedAudio`, `enablePcmTimelineEngine`.

- [ ] **Step 4: Run the verification gate**

Run:
```bash
flutter analyze lib test integration_test --no-fatal-infos --no-fatal-warnings
flutter test --exclude-tags firebase-emulator
```
Expected: no new errors; tests pass.

- [ ] **Step 5: Commit**

Stage ONLY the touched file (do NOT `git add -A`):

```bash
git add lib/config/metronome_feature_flags.dart
git commit -m "chore: remove dead metronome feature flags"
```

---

## Self-Review

**Spec coverage:** Five audit findings carried into tasks (orphaned fuzzy matcher → T1; example/template/disabled files → T2; matching barrel → T3; cache-notifier layer → T4; dead feature flags → T5). Two audit findings were intentionally dropped after the double-check and are NOT in this plan: (a) abstract repository interfaces — kept, because tests mock them and they're typed seams; (b) `debugPrint`/logging noise — out of scope (it's a behavior-adjacent polish item, not dead code; do it separately if desired). The `repositories.dart` barrel is kept (it has real importers).

**Placeholder scan:** No TBD/TODO/"handle edge cases". Task 4's test removal is intentionally analyzer-driven rather than hardcoded line numbers, because the test blocks are interleaved and line numbers drift as edits are made — the analyzer is the precise, non-brittle guide. Every other task lists exact files and exact commands.

**Type consistency:** No new types introduced. Live provider names referenced in Task 4 (`songsProvider`, `bandsProvider`, `setlistsProvider`, `*CountProvider`, `selectedBandProvider`) match the symbols defined in `data_providers.dart`. Flag names in Task 5 match the source file verbatim.

**Net effect:** ~900–1000 lines removed across `lib` + dead tests, zero runtime behavior change, each task independently revertable.
