# RepSync Implementation Plan

**Project:** Flutter RepSync App  
**Version:** v1.0.0+1  
**Plan Date:** February 25, 2026  
**Total Duration:** 8-10 days  
**Status:** Ready to Execute

---

## Executive Summary

This implementation plan covers 6 sprints to enhance RepSync with:
1. **Sprint 1:** Fix song addition bug (loader hang, error handling, timeout)
2. **Sprint 2:** Calendar date picker for setlists
3. **Sprint 3:** User profile baseTags system (role tags)
4. **Sprint 4:** Band/setlist roles with overrides for concerts
5. **Sprint 5:** Song tags with tag cloud
6. **Sprint 6:** Tag integration for setlist export

---

## Current Codebase Analysis Summary

### Architecture Overview

| Layer | Implementation | Status |
|-------|---------------|--------|
| **State Management** | Riverpod 3.2.1 | ✅ Modern |
| **Offline Storage** | Hive 2.2.3 | ✅ Implemented |
| **Backend** | Firestore (cloud_firestore 6.1.2) | ✅ Implemented |
| **Navigation** | GoRouter 17.1.0 | ✅ Implemented |
| **Pattern** | Repository Pattern | ✅ Implemented |

### Model Analysis

| Model | File | Current Fields | Needs Update |
|-------|------|----------------|--------------|
| `Band` | `lib/models/band.dart` | id, name, description, members, memberUids, adminUids, editorUids, inviteCode, createdAt | ✅ memberRoles |
| `Setlist` | `lib/models/setlist.dart` | id, bandId, name, description, eventDate, eventLocation, songIds, totalDuration, createdAt, updatedAt | ✅ date (DateTime), assignments |
| `Song` | `lib/models/song.dart` | id, title, artist, originalKey, originalBPM, ourKey, ourBPM, links, notes, tags, bandId, spotifyUrl, createdAt, updatedAt, ... | ✅ tags (exists!) |
| `AppUser` | `lib/models/user.dart` | uid, displayName, email, photoURL, bandIds, createdAt | ✅ baseTags |

### Key Findings

1. **Song.tags already exists** - Sprint 5 partially complete
2. **Setlist.eventDate exists as String** - Sprint 2 needs type conversion to DateTime
3. **No UserNotifier exists** - Sprint 3 requires new provider
4. **PDF service exists** - Sprint 6 has foundation
5. **Repository pattern in place** - All updates follow existing patterns

### File Structure

```
lib/
├── models/
│   ├── band.dart          # Update: memberRoles
│   ├── setlist.dart       # Update: date (DateTime), assignments
│   ├── song.dart          # tags exists - verify functionality
│   └── user.dart          # Update: baseTags
├── providers/
│   ├── data/
│   │   └── data_providers.dart  # Update: UserNotifier
│   └── auth/
├── repositories/
│   ├── band_repository.dart
│   ├── setlist_repository.dart
│   └── song_repository.dart
├── screens/
│   ├── bands/
│   ├── setlists/
│   ├── songs/
│   └── profile/
├── services/
│   ├── export/
│   │   └── pdf_service.dart     # Update: participants table
│   └── csv/
└── widgets/
```

---

## Sprint Breakdown

### Sprint 1: Fix Song Addition Bug (1 day)

**Goals:**
- Eliminate loader hang on song addition
- Add 10s timeout on Firestore calls
- Implement AsyncValue error handling
- Add Snackbar error UI
- Offline/online logging

**Files to Modify:**
| File | Changes |
|------|---------|
| `lib/repositories/firestore_song_repository.dart` | Add timeout(10s) to Firestore calls |
| `lib/providers/data/data_providers.dart` | Verify AsyncValue handling in CachedSongsNotifier |
| `lib/screens/bands/band_screen.dart` | Add .when() state handling, Snackbar on error |
| `lib/services/firestore_service.dart` | Add timeout helper method |

**New Files to Create:**
- None (bug fix only)

**Dependencies:**
- None (uses existing Riverpod, Firestore)

**Estimated Hours:** 6-8 hours

**Success Criteria:**
- [ ] No loader hangs > 10s
- [ ] Error Snackbar displays on failure
- [ ] Offline mode logs appropriately
- [ ] Unit tests pass for notifier

**Risks:**
- Firestore timeout may be too aggressive for slow networks
- Mitigation: Log timeout events for tuning

---

### Sprint 2: Calendar Date Picker for Setlists (1 day)

**Goals:**
- Replace manual date input with showDatePicker
- Store date as DateTime (Hive) ↔ Timestamp (Firestore)
- Update Setlist model with proper DateTime field
- Default to DateTime.now()

**Files to Modify:**
| File | Changes |
|------|---------|
| `lib/models/setlist.dart` | Add `DateTime? date` field, update adapters |
| `lib/repositories/firestore_setlist_repository.dart` | Convert DateTime ↔ Timestamp |
| `lib/screens/setlists/setlist_edit_screen.dart` | Integrate showDatePicker |
| `lib/providers/data/data_providers.dart` | Add updateDate method to SetlistNotifier |

**New Files to Create:**
- None

**Dependencies:**
- Flutter built-in showDatePicker

**Estimated Hours:** 6-8 hours

**Success Criteria:**
- [ ] Date selectable only via picker
- [ ] No null dates allowed
- [ ] Default date = today
- [ ] Hive/Firestore sync works

**Risks:**
- Timestamp timezone issues
- Mitigation: Use UTC consistently

---

### Sprint 3: User Profile Base Tags System (2 days)

**Goals:**
- Add `List<String> baseTags` to user profile
- Create UserNotifier with addTag/removeTag methods
- UI: FilterChip display + AlertDialog for add
- Auto-fill baseTags when adding band members

**Files to Modify:**
| File | Changes |
|------|---------|
| `lib/models/user.dart` | Add `List<String> baseTags` field |
| `lib/repositories/firestore_user_repository.dart` | CRUD for baseTags |
| `lib/screens/profile/profile_screen.dart` | FilterChip + AlertDialog UI |
| `lib/screens/bands/band_edit_screen.dart` | Auto-fill from baseTags |

**New Files to Create:**
| File | Purpose |
|------|---------|
| `lib/repositories/user_repository.dart` | Abstract repository interface |
| `lib/repositories/firestore_user_repository.dart` | Firestore implementation |
| `lib/providers/user_provider.dart` | UserNotifier with state management |

**Dependencies:**
- Optional: `textfield_tags: ^3.0` (if built-in chips insufficient)

**Estimated Hours:** 12-16 hours

**Success Criteria:**
- [ ] Tags display as FilterChip
- [ ] Add/remove tags works offline
- [ ] Auto-fill in band member addition
- [ ] Unit tests for UserNotifier

**Risks:**
- Tag sync conflicts between devices
- Mitigation: Use lastUpdated timestamp

---

### Sprint 4: Band/Setlist Roles with Overrides (2 days)

**Goals:**
- Add `Map<String, List<String>> memberRoles` to Band
- Add `Map<String, Map<String, String>> assignments` to Setlist
- Implement `getParticipants()` method
- UI: Multi-select FilterChip, dropdowns for overrides

**Files to Modify:**
| File | Changes |
|------|---------|
| `lib/models/band.dart` | Add `memberRoles` field |
| `lib/models/setlist.dart` | Add `assignments` field, `getParticipants()` method |
| `lib/repositories/firestore_band_repository.dart` | Save/load memberRoles |
| `lib/repositories/firestore_setlist_repository.dart` | Save/load assignments |
| `lib/screens/bands/band_edit_screen.dart` | Role assignment UI |
| `lib/screens/setlists/setlist_edit_screen.dart` | Override UI (role + key) |

**New Files to Create:**
- None (extends existing models)

**Dependencies:**
- Sprint 3 (baseTags) for role suggestions

**Estimated Hours:** 12-16 hours

**Success Criteria:**
- [ ] Roles saved per band member
- [ ] Setlist overrides work for guests
- [ ] getParticipants() returns unique list
- [ ] UI displays roles correctly

**Risks:**
- Complex nested Map serialization
- Mitigation: Test with json_serializable

---

### Sprint 5: Song Tags + Tag Cloud (2 days)

**Goals:**
- Verify/enhance Song.tags functionality
- Add TextFieldTags package for tag input
- Create `getTagCloud()` in song service
- UI: Search filter by tags, tag cloud display

**Files to Modify:**
| File | Changes |
|------|---------|
| `lib/models/song.dart` | Verify tags field (exists) |
| `lib/repositories/firestore_song_repository.dart` | Ensure tags sync |
| `lib/screens/songs/song_edit_screen.dart` | TextFieldTags integration |
| `lib/screens/songs/song_list_screen.dart` | Search filter by tags |
| `lib/screens/profile/profile_screen.dart` | Tag cloud display |

**New Files to Create:**
| File | Purpose |
|------|---------|
| `lib/services/tag_service.dart` | getTagCloud(), tag frequency aggregation |

**Dependencies:**
- `textfield_tags: ^3.0` (add to pubspec.yaml)

**Estimated Hours:** 12-16 hours

**Success Criteria:**
- [ ] Tags addable via TextFieldTags
- [ ] Tag cloud shows frequency
- [ ] Search filters by tag
- [ ] CSV import parses tags column

**Risks:**
- Tag cloud performance with 1000+ songs
- Mitigation: Limit scan to 100 most recent songs

---

### Sprint 6: Export Integration (1 day)

**Goals:**
- Update pdf_service to include participants table
- Add export button with "Include participants" option
- Test PDF generation with full participant list

**Files to Modify:**
| File | Changes |
|------|---------|
| `lib/services/export/pdf_service.dart` | Add participants table section |
| `lib/screens/setlists/setlist_screen.dart` | Export button with options |
| `lib/providers/data/data_providers.dart` | Integrate getParticipants |

**New Files to Create:**
- None

**Dependencies:**
- Sprint 4 (assignments, getParticipants)
- Existing pdf package

**Estimated Hours:** 6-8 hours

**Success Criteria:**
- [ ] PDF includes participants table
- [ ] Export option toggle works
- [ ] Full concert list generates correctly

**Risks:**
- PDF layout overflow with many participants
- Mitigation: Test with 20+ participants

---

## Dependencies Summary

### Pubspec.yaml Additions

```yaml
dependencies:
  textfield_tags: ^3.0.0  # Sprint 5
```

### Internal Dependencies

| Sprint | Depends On |
|--------|-----------|
| Sprint 1 | None |
| Sprint 2 | None |
| Sprint 3 | None |
| Sprint 4 | Sprint 3 (baseTags) |
| Sprint 5 | None |
| Sprint 6 | Sprint 4 (assignments) |

---

## Test Strategy

### Unit Tests (Riverpod Notifiers)
- Test all Notifier methods with mockito
- Mock repositories and services
- Target: 90% notifier coverage

### Integration Tests (Hive/Firestore Sync)
- Test offline → online sync
- Test conflict resolution
- Target: All critical paths covered

### Manual UI Testing
- Test on Android emulator (API 34)
- Test on iOS simulator (iOS 17)
- Test responsive layouts

---

## Risk Mitigation Matrix

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Firestore timeout too aggressive | Medium | Low | Log events, tune timeout |
| Timestamp timezone issues | Medium | Medium | Use UTC consistently |
| Tag sync conflicts | High | Medium | lastUpdated timestamp |
| Nested Map serialization | Medium | Low | Test with json_serializable |
| Tag cloud performance | Low | Medium | Limit to 100 songs |
| PDF layout overflow | Low | Low | Test with 20+ participants |

---

## Timeline Confirmation

| Sprint | Duration | Start | End | Deliverable |
|--------|----------|-------|-----|-------------|
| Sprint 1 | 1 day | Day 1 | Day 1 | Bug fix committed |
| Sprint 2 | 1 day | Day 2 | Day 2 | Date picker merged |
| Sprint 3 | 2 days | Day 3 | Day 4 | baseTags system |
| Sprint 4 | 2 days | Day 5 | Day 6 | Roles + overrides |
| Sprint 5 | 2 days | Day 7 | Day 8 | Tag cloud |
| Sprint 6 | 1 day | Day 9 | Day 9 | Export integration |
| Buffer/Testing | 1-2 days | Day 10 | Day 11 | Full regression |

**Total:** 8-10 working days

---

## Deliverables Checklist

- [x] IMPLEMENTATION_PLAN.md (this document)
- [ ] SPRINT_CHECKLISTS.md (one-line TODOs)
- [ ] TECH_SPECS.md (technical specifications)
- [ ] RISK_LOG.md (risks and mitigation)

---

## Ready-to-Execute Plan Status

| Criterion | Status |
|-----------|--------|
| Codebase analyzed | ✅ Complete |
| File paths identified | ✅ Complete |
| Dependencies listed | ✅ Complete |
| Timeline confirmed | ✅ 8-10 days |
| Risk assessment done | ✅ Matrix created |
| Test strategy defined | ✅ 3-tier approach |

**Status: READY TO EXECUTE** 🚀

---

**Document Version:** 1.0  
**Last Updated:** February 25, 2026  
**Author:** MrPlanner
