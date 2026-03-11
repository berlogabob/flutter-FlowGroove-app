# 🎯 FIRESTORESERVICE DEPRECATION PLAN

**Date:** March 10, 2026  
**Goal:** Remove 985-line FirestoreService duplication  
**Target:** 100% repository pattern adoption

---

## 📊 CURRENT STATE

### FirestoreService Usage
- **Total size:** 985 lines
- **Screens using it:** 8 files
- **Total usages:** 23 occurrences
- **Duplication:** ~90% overlap with repositories

### Files Using FirestoreService Directly

| File | Usage Count | Methods Used | Priority |
|------|-------------|--------------|----------|
| `my_bands_screen.dart` | 3 | saveBandToGlobal, removeUserFromBand | P0 |
| `band_songs_screen.dart` | 2 | deleteBandSong, reorderBandSongs | P0 |
| `create_band_screen.dart` | 2 | saveBandToGlobal, isInviteCodeTaken | P0 |
| `join_band_screen.dart` | 1 | addUserToBand | P1 |
| `band_about_screen.dart` | 1 | removeUserFromBand | P1 |
| `song_picker_screen.dart` | 1 | addSongToBandById | P1 |
| `create_setlist_screen.dart` | 1 | saveSetlist | P1 |
| `setlists_list_screen.dart` | 1 | deleteSetlist | P1 |

---

## ✅ EXISTING REPOSITORIES

### Available Repositories (Ready to Use)
1. ✅ `SongRepository` → `FirestoreSongRepository`
2. ✅ `BandRepository` → `FirestoreBandRepository`
3. ✅ `SetlistRepository` → `FirestoreSetlistRepository`

### Providers (Ready to Inject)
1. ✅ `songRepositoryProvider`
2. ✅ `bandRepositoryProvider`
3. ✅ `setlistRepositoryProvider`

---

## 🔧 MIGRATION STRATEGY

### Pattern: Replace Service with Repository

```dart
// BEFORE - Using FirestoreService
final service = ref.read(firestoreProvider);
await service.saveBandToGlobal(band);

// AFTER - Using Repository
final bandRepo = ref.read(bandRepositoryProvider);
await bandRepo.saveBandToGlobal(band);
```

### Migration Steps

1. **Identify method being called**
2. **Find equivalent repository method**
3. **Replace service call with repository call**
4. **Test functionality**
5. **Remove FirestoreService import**

---

## 📋 MIGRATION CHECKLIST

### P0 - High Impact (3 files)
- [ ] `my_bands_screen.dart` - 3 usages
  - [ ] `saveBandToGlobal` → `bandRepository.saveBandToGlobal()`
  - [ ] `removeUserFromBand` → `bandRepository.removeUserFromBand()`
  
- [ ] `band_songs_screen.dart` - 2 usages
  - [ ] `deleteBandSong` → `songRepository.deleteBandSong()`
  - [ ] `reorderBandSongs` → `songRepository.reorderBandSongs()`
  
- [ ] `create_band_screen.dart` - 2 usages
  - [ ] `saveBandToGlobal` → `bandRepository.saveBandToGlobal()`
  - [ ] `isInviteCodeTaken` → `bandRepository.isInviteCodeTaken()`

### P1 - Medium Impact (5 files)
- [ ] `join_band_screen.dart` - 1 usage
  - [ ] `addUserToBand` → `bandRepository.addUserToBand()`
  
- [ ] `band_about_screen.dart` - 1 usage
  - [ ] `removeUserFromBand` → `bandRepository.removeUserFromBand()`
  
- [ ] `song_picker_screen.dart` - 1 usage
  - [ ] `addSongToBandById` → `songRepository.addSongToBandById()`
  
- [ ] `create_setlist_screen.dart` - 1 usage
  - [ ] `saveSetlist` → `setlistRepository.saveSetlist()`
  
- [ ] `setlists_list_screen.dart` - 1 usage
  - [ ] `deleteSetlist` → `setlistRepository.deleteSetlist()`

---

## 🎯 BENEFITS

### After Migration
1. **Single Source of Truth** - No duplication
2. **Better Testability** - Repositories are mockable
3. **Consistent Patterns** - All data access via repositories
4. **Easier Maintenance** - Changes in one place
5. **Clear Separation** - Service layer removed

### Code Reduction
- **Remove:** 985 lines (FirestoreService)
- **Remove:** 1 provider (firestoreProvider)
- **Simplify:** 8 screens
- **Net gain:** -1000 lines of code

---

## ⚠️ BREAKING CHANGES

### For Developers
```dart
// OLD - Will be removed
final service = ref.read(firestoreProvider);
await service.saveSong(song);

// NEW - Required pattern
final repo = ref.read(songRepositoryProvider);
await repo.saveSong(song);
```

### Deprecation Timeline
1. **Week 1:** Migrate all 8 files
2. **Week 2:** Add @Deprecated annotations
3. **Week 3:** Remove FirestoreService entirely

---

## 📊 SUCCESS METRICS

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| **Files using service** | 8 | 0 | 0 ✅ |
| **Service lines** | 985 | 0 | 0 ✅ |
| **Repository usage** | Partial | 100% | 100% ✅ |
| **Code duplication** | ~90% | 0% | 0% ✅ |

---

**Start Date:** March 10, 2026  
**Target Completion:** March 17, 2026  
**Status:** Ready to begin
