# Sprint Checklists

**Project:** Flutter RepSync App  
**Version:** v1.0.0+1  
**Date:** February 25, 2026

---

## Sprint 1: Fix Song Addition Bug (Day 1)

- [ ] Add timeout(10s) to Firestore song save calls
- [ ] Implement AsyncValue error handling in CachedSongsNotifier
- [ ] Add Snackbar error UI in band_screen.dart
- [ ] Add debugPrint logs for offline/online states
- [ ] Write unit test for notifier error handling
- [ ] Manual test: Add song offline → verify no hang
- [ ] Manual test: Add song online → verify success
- [ ] Commit fix with message: "fix: song addition timeout + error handling"

---

## Sprint 2: Calendar Date Picker (Day 2)

- [ ] Add `DateTime? date` field to Setlist model
- [ ] Update setlist.g.dart with json_serializable
- [ ] Add DateTime ↔ Timestamp conversion in FirestoreSetlistRepository
- [ ] Integrate showDatePicker in setlist_edit_screen.dart
- [ ] Set default date to DateTime.now()
- [ ] Add updateDate method to SetlistNotifier
- [ ] Write unit test for date validation (no null)
- [ ] Manual test: Pick date → verify save/load
- [ ] Commit with message: "feat: calendar date picker for setlists"

---

## Sprint 3: User Base Tags (Days 3-4)

- [ ] Add `List<String> baseTags` to AppUser model
- [ ] Update user.g.dart with json_serializable
- [ ] Create `lib/repositories/user_repository.dart` (abstract)
- [ ] Create `lib/repositories/firestore_user_repository.dart`
- [ ] Create `lib/providers/user_provider.dart` with UserNotifier
- [ ] Implement loadProfile method in UserNotifier
- [ ] Implement addTag method in UserNotifier
- [ ] Implement removeTag method in UserNotifier
- [ ] Add FilterChip display in profile_screen.dart
- [ ] Add AlertDialog for tag input in profile_screen.dart
- [ ] Auto-fill baseTags in band member addition
- [ ] Write unit tests for UserNotifier (add/remove)
- [ ] Manual test: Add tag → verify display
- [ ] Manual test: Remove tag → verify removal
- [ ] Manual test: Add band member → verify auto-fill
- [ ] Commit with message: "feat: user profile baseTags system"

---

## Sprint 4: Band/Setlist Roles (Days 5-6)

- [ ] Add `Map<String, List<String>> memberRoles` to Band model
- [ ] Update band.g.dart with json_serializable
- [ ] Add `Map<String, Map<String, String>> assignments` to Setlist model
- [ ] Update setlist.g.dart with json_serializable
- [ ] Add `getParticipants()` method to Setlist model
- [ ] Implement updateRole in BandNotifier
- [ ] Implement addAssignment in SetlistNotifier
- [ ] Add FilterChip multi-select for roles in band_edit_screen.dart
- [ ] Add ExpansionTile with overrides UI in setlist_edit_screen.dart
- [ ] Add dropdown for role override
- [ ] Add dropdown for key override
- [ ] Write unit test for getParticipants()
- [ ] Manual test: Assign role → verify save
- [ ] Manual test: Add guest override → verify display
- [ ] Manual test: Generate participants list
- [ ] Commit with message: "feat: band/setlist roles with overrides"

---

## Sprint 5: Song Tags + Tag Cloud (Days 7-8)

- [ ] Verify Song.tags field functionality
- [ ] Add `textfield_tags: ^3.0.0` to pubspec.yaml
- [ ] Run `flutter pub get`
- [ ] Integrate TextFieldTags in song_edit_screen.dart
- [ ] Create `lib/services/tag_service.dart`
- [ ] Implement getTagCloud() method (scan 100 songs)
- [ ] Add tag frequency aggregation logic
- [ ] Add SearchBar filter by tags in song_list_screen.dart
- [ ] Add tag cloud display (Wrap + ChoiceChip) in profile_screen.dart
- [ ] Update csv_service to parse 'tags' column
- [ ] Write unit test for getTagCloud()
- [ ] Manual test: Add tag via TextFieldTags
- [ ] Manual test: Search by tag → verify filter
- [ ] Manual test: Tag cloud displays frequency
- [ ] Manual test: Import CSV with tags column
- [ ] Commit with message: "feat: song tags + tag cloud"

---

## Sprint 6: Export Integration (Day 9)

- [ ] Integrate getParticipants() in pdf_service.dart
- [ ] Add participants table section to PDF
- [ ] Add "Include participants" checkbox option
- [ ] Add export button in setlist_screen.dart
- [ ] Wire export button to pdf_service
- [ ] Test PDF generation with 5 participants
- [ ] Test PDF generation with 20+ participants
- [ ] Verify layout no overflow
- [ ] Manual test: Export with participants
- [ ] Manual test: Export without participants
- [ ] Commit with message: "feat: export integration with participants"

---

## Buffer/Testing (Days 10-11)

- [ ] Run all unit tests
- [ ] Fix any failing tests
- [ ] Run integration tests
- [ ] Manual regression test all features
- [ ] Test offline mode for all features
- [ ] Test online sync for all features
- [ ] Update CHANGELOG.md
- [ ] Create PR with all changes
- [ ] Code review
- [ ] Merge to main

---

## Post-Sprint Checklist

- [ ] Update README.md with new features
- [ ] Update docs/ with feature guides
- [ ] Create GitHub release notes
- [ ] Deploy to test device
- [ ] Collect user feedback
- [ ] Plan Sprint 7+ based on feedback

---

**Total Checkboxes:** 87  
**Estimated Completion:** 8-10 days

**Status:** Ready to Execute 🚀
