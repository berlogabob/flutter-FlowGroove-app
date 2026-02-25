# Day 1 Task Briefing: Fix 71 Blocked Tests

**Sprint:** Sprint 4 - Polish & Production
**Date:** February 25, 2026
**Assignee:** MrSeniorDeveloper
**Duration:** 8 hours
**Priority:** P0 🔴 Critical

---

## Overview

71 integration tests are blocked by pre-existing code issues identified in Sprint 3. These must be fixed on Day 1 to unblock Sprint 4 progress and achieve the 95%+ test pass rate target.

---

## Task List

### Task 1: Fix `firestoreProvider` Undefined Errors (2 hours)

**Issue:** Tests reference `firestoreProvider` but it may not be properly exported or imported in test context.

**Files Affected:**
- `lib/screens/setlists/setlists_list_screen.dart` (line 90, 113)
- `lib/screens/setlists/create_setlist_screen.dart` (line 118)
- `lib/screens/bands/song_picker_screen.dart` (line 75, 223)
- `lib/screens/bands/create_band_screen.dart` (line 57, 94)
- `lib/screens/bands/my_bands_screen.dart` (line 132, 392, 396)
- `lib/screens/bands/band_songs_screen.dart` (line 285, 323)
- `lib/screens/bands/join_band_screen.dart` (line 39)

**Provider Definition:**
```dart
// lib/providers/data/data_providers.dart (line 18)
final firestoreProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});
```

**Action Required:**
1. Verify `firestoreProvider` is exported from `lib/providers/providers.dart`
2. Ensure all screens import from correct path: `import 'package:flutter_repsync_app/providers/data/data_providers.dart';`
3. Check test files import the provider correctly

**Test Files Blocked:**
- `test/integration/setlist_management_test.dart` (35 tests)
- `test/integration/song_management_test.dart` (36 tests - partial)

---

### Task 2: Fix Auth Mock Configuration (1 hour)

**Issue:** 14 auth tests failing due to mock setup issues in integration tests.

**Files Affected:**
- `test/integration/auth_flow_test.dart`
- `test/helpers/mocks.dart`
- `test/helpers/mocks.mocks.dart`

**Current Mock Setup:**
```dart
setUp(() {
  mockAuth = MockFirebaseAuth();
  mockUser = MockUser();
  when(mockUser.uid).thenReturn('test-user-id');
  when(mockUser.email).thenReturn('test@example.com');
  when(mockAuth.currentUser).thenReturn(mockUser);
});
```

**Action Required:**
1. Review `MockFirebaseAuth` implementation in `test/helpers/mocks.dart`
2. Ensure `MockUser` properly implements `User` interface
3. Add missing mock methods: `authStateChanges()`, `signInWithEmailAndPassword()`, `createUserWithEmailAndPassword()`
4. Consider using `mocktail` for better type safety

**Expected Outcome:** 14 auth tests passing

---

### Task 3: Fix API Signature Mismatches - saveSong/deleteSong (1 hour)

**Issue:** Repository API uses named parameter `{String? uid}` but some calls may use positional parameter.

**Repository Signature (Correct):**
```dart
// lib/repositories/firestore_song_repository.dart
Future<void> saveSong(Song song, {String? uid}) async { ... }
Future<void> deleteSong(String songId, {String? uid}) async { ... }
Future<void> updateSong(Song song, {String? uid}) async { ... }
```

**Files to Check:**
- `lib/screens/songs/add_song_screen.dart` (line 166) - Already correct: `saveSong(song, uid: user.uid)`
- `lib/screens/songs/songs_list_screen.dart` (line 766) - Already correct: `deleteSong(song.id, uid: user.uid)`
- Test files calling these methods

**Action Required:**
1. Search for all `saveSong(` and `deleteSong(` calls in test files
2. Ensure all use named parameter syntax: `saveSong(song, uid: uid)`
3. Update any positional parameter calls

---

### Task 4: Fix CreateSetlistScreen Constructor (1 hour)

**Issue:** `CreateSetlistScreen` constructor API changed - `bandId` parameter removed, uses `setlist` object.

**Current Constructor:**
```dart
// lib/screens/setlists/create_setlist_screen.dart
class CreateSetlistScreen extends ConsumerStatefulWidget {
  final Setlist? setlist;
  const CreateSetlistScreen({super.key, this.setlist});
}
```

**Action Required:**
1. Check test files for old constructor usage: `CreateSetlistScreen(bandId: 'id')`
2. Update to new API: `CreateSetlistScreen(setlist: existingSetlist)` or `CreateSetlistScreen()`
3. Update `setlist_management_test.dart` to use correct constructor

---

### Task 5: Fix FirebaseException Plugin Parameter (1 hour)

**Issue:** New Firebase SDK requires `plugin` named parameter in `FirebaseException` constructor.

**Old Code:**
```dart
throw FirebaseException(code: 'permission-denied', message: 'Error');
```

**New Code Required:**
```dart
throw FirebaseException(
  plugin: 'firestore',
  code: 'permission-denied',
  message: 'Error',
);
```

**Files Affected (36 occurrences):**
- `lib/repositories/firestore_band_repository.dart` (8 occurrences)
- `lib/services/firestore_service.dart` (22 occurrences)
- `lib/repositories/firestore_song_repository.dart` (8 occurrences)
- `lib/repositories/firestore_setlist_repository.dart` (2 occurrences)

**Action Required:**
1. Add `plugin` parameter to all `FirebaseException` throws
2. Use appropriate plugin names: `'firestore'`, `'auth'`, `'storage'`

**Note:** This may only affect test mocks, not production code. Verify by running tests first.

---

### Task 6: Re-run Blocked Tests (2 hours)

**After all fixes are complete:**

**Command:**
```bash
flutter test test/integration/song_management_test.dart
flutter test test/integration/setlist_management_test.dart
flutter test test/integration/auth_flow_test.dart
```

**Expected Results:**
| Test File | Tests | Target Pass Rate |
|-----------|-------|------------------|
| song_management_test.dart | 36 | 95%+ |
| setlist_management_test.dart | 35 | 95%+ |
| auth_flow_test.dart | 23 | 95%+ |
| **Total** | **94** | **95%+** |

**Action Required:**
1. Run all three test files
2. Document any remaining failures
3. Fix remaining issues or escalate to MrSync
4. Update SPRINT_4_PROGRESS.md with results

---

## Success Criteria

- [ ] All 5 code fixes completed
- [ ] 71 previously blocked tests now running
- [ ] 95%+ pass rate on integration tests
- [ ] No compilation errors
- [ ] Code formatted (`dart format .`)
- [ ] SPRINT_4_PROGRESS.md updated

---

## Dependencies

- **Blocks:** MrTester coverage gap closure (Day 2)
- **Blocked By:** None
- **Support Available:** MrSync for coordination, MrTester for test verification

---

## Escalation Path

If issues cannot be resolved within timebox:
1. **Hour 4:** Report progress to MrSync
2. **Hour 6:** Escalate any blockers
3. **Hour 8:** Hand off to MrTester for test re-run

---

## Files Reference

### Source Files to Fix
```
lib/providers/data/data_providers.dart
lib/screens/setlists/setlists_list_screen.dart
lib/screens/setlists/create_setlist_screen.dart
lib/screens/songs/add_song_screen.dart
lib/screens/songs/songs_list_screen.dart
lib/repositories/firestore_song_repository.dart
lib/repositories/firestore_band_repository.dart
lib/repositories/firestore_setlist_repository.dart
lib/services/firestore_service.dart
```

### Test Files to Verify
```
test/integration/song_management_test.dart
test/integration/setlist_management_test.dart
test/integration/auth_flow_test.dart
test/helpers/mocks.dart
test/helpers/mocks.mocks.dart
test/helpers/integration_test_helpers.dart
```

---

**Assigned by:** MrSync
**Status:** ⬜ Pending → 🟢 In Progress → ✅ Complete
**Start Time:** _________
**End Time:** _________
**Actual Hours:** _________
