# Risk Log

**Project:** Flutter RepSync App  
**Version:** v1.0.0+1  
**Date:** February 25, 2026  
**Last Updated:** February 25, 2026

---

## Risk Matrix Overview

| ID | Risk | Impact | Probability | Severity | Owner | Status |
|----|------|--------|-------------|----------|-------|--------|
| R01 | Firestore timeout too aggressive | Medium | Low | **Low** | MrPlanner | Open |
| R02 | Timestamp timezone issues | Medium | Medium | **Medium** | MrPlanner | Open |
| R03 | Tag sync conflicts | High | Medium | **High** | MrPlanner | Open |
| R04 | Nested Map serialization | Medium | Low | **Low** | MrPlanner | Open |
| R05 | Tag cloud performance | Low | Medium | **Low** | MrPlanner | Open |
| R06 | PDF layout overflow | Low | Low | **Low** | MrPlanner | Open |
| R07 | Hive/Firestore sync conflicts | High | Low | **Medium** | MrPlanner | Open |
| R08 | TextFieldTags package compatibility | Medium | Low | **Low** | MrPlanner | Open |

---

## Detailed Risk Analysis

### R01: Firestore Timeout Too Aggressive

**Description:** 10-second timeout may be too short for slow networks, causing false failures.

**Impact:** Medium - Users on slow connections may experience failed saves.

**Probability:** Low - Most Firestore operations complete in <5s.

**Severity:** **Low**

**Mitigation:**
- Log all timeout events with `debugPrint`
- Include network quality info in logs
- Tune timeout based on production data (consider 15s if >5% timeout rate)

**Contingency:**
- Add retry logic (3 attempts with exponential backoff)
- Show user-friendly message: "Slow connection, retrying..."

**Trigger:**
- Timeout rate >5% in first week

**Owner:** MrPlanner

**Status:** Open - Monitor during Sprint 1

---

### R02: Timestamp Timezone Issues

**Description:** DateTime conversion between Hive (local) and Firestore (UTC) may cause date mismatches.

**Impact:** Medium - Users may see wrong dates in different timezones.

**Probability:** Medium - Common issue in Flutter/Firestore apps.

**Severity:** **Medium**

**Mitigation:**
- Store all dates as UTC in Firestore
- Convert to local time only for display
- Use `DateTime.toUtc()` before saving
- Use `DateTime.toLocal()` before displaying

**Code Pattern:**
```dart
// Save as UTC
final utcDate = pickedDate.toUtc();
data['date'] = Timestamp.fromDate(utcDate);

// Display as local
final localDate = (data['date'] as Timestamp).toDate().toLocal();
```

**Contingency:**
- Add timezone field to model if issues persist
- Show timezone indicator in UI

**Trigger:**
- User reports of wrong dates

**Owner:** MrPlanner

**Status:** Open - Implement UTC pattern in Sprint 2

---

### R03: Tag Sync Conflicts

**Description:** Multiple devices editing baseTags simultaneously may cause data loss.

**Impact:** High - User data loss is critical.

**Probability:** Medium - Users may edit profile from multiple devices.

**Severity:** **High**

**Mitigation:**
- Add `lastUpdated` timestamp to user profile
- Use Firestore transactions for updates
- Implement last-write-wins strategy with timestamp check

**Code Pattern:**
```dart
Future<void> updateBaseTags(String uid, List<String> tags) async {
  await _firestore.runTransaction((transaction) async {
    final doc = await transaction.get(_firestore.collection('users').doc(uid));
    final existing = AppUser.fromJson(doc.data()!);
    
    // Only update if our timestamp is newer
    if (existing.lastUpdated != null && 
        existing.lastUpdated!.isAfter(localLastUpdated)) {
      throw ConcurrentModificationException('Server has newer update');
    }
    
    transaction.update(_firestore.collection('users').doc(uid), {
      'baseTags': tags,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  });
}
```

**Contingency:**
- Show conflict resolution UI if needed
- Manual merge option for advanced users

**Trigger:**
- ConcurrentModificationException thrown

**Owner:** MrPlanner

**Status:** Open - Implement in Sprint 3

---

### R04: Nested Map Serialization

**Description:** `Map<String, Map<String, String>>` in Setlist.assignments may not serialize correctly.

**Impact:** Medium - Data corruption or save failures.

**Probability:** Low - json_serializable handles nested maps well.

**Severity:** **Low**

**Mitigation:**
- Test serialization with json_serializable build_runner
- Write unit tests for edge cases (empty maps, null values)
- Use `@JsonKey` annotations explicitly

**Code Pattern:**
```dart
@JsonSerializable()
class Setlist {
  @JsonKey(
    defaultValue: {},
    fromJson: _assignmentsFromJson,
    toJson: _assignmentsToJson,
  )
  final Map<String, Map<String, String>> assignments;
}

Map<String, Map<String, String>> _assignmentsFromJson(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, Map<String, String>>) return value;
  
  return (value as Map).map((key, value) {
    return MapEntry(
      key.toString(),
      (value as Map).cast<String, String>(),
    );
  });
}
```

**Contingency:**
- Flatten to single-level Map with composite keys if needed
- Example: `"songId-userId": "role"`

**Trigger:**
- Serialization errors in testing

**Owner:** MrPlanner

**Status:** Open - Test in Sprint 4

---

### R05: Tag Cloud Performance

**Description:** Scanning 1000+ songs for tag frequency may be slow.

**Impact:** Low - UI may lag during tag cloud generation.

**Probability:** Medium - Bands with large song libraries.

**Severity:** **Low**

**Mitigation:**
- Limit scan to 100 most recent songs
- Cache tag cloud results in memory
- Use compute isolate for heavy calculations

**Code Pattern:**
```dart
Future<Map<String, int>> getTagCloud(String bandId) async {
  // Limit to 100 songs
  final songs = await _songRepo.getBandSongs(bandId)
    .take(100)
    .toList();
  
  // Use compute for heavy lifting
  return compute(_calculateTagFrequency, songs);
}

Map<String, int> _calculateTagFrequency(List<Song> songs) {
  final tagFrequency = <String, int>{};
  for (final song in songs) {
    for (final tag in song.tags) {
      tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
    }
  }
  return tagFrequency;
}
```

**Contingency:**
- Paginate tag cloud (show top 20, load more)
- Background refresh with loading indicator

**Trigger:**
- Tag cloud generation >2s

**Owner:** MrPlanner

**Status:** Open - Monitor in Sprint 5

---

### R06: PDF Layout Overflow

**Description:** PDF may overflow with 20+ participants or long song lists.

**Impact:** Low - PDF still usable, just needs scrolling.

**Probability:** Low - Most bands have <10 members.

**Severity:** **Low**

**Mitigation:**
- Use pw.MultiPage for automatic pagination
- Test with 20+ participants
- Adjust font sizes and margins

**Code Pattern:**
```dart
pdf.addPage(
  pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(20),
    build: (context) => [
      // Content automatically flows to new pages
    ],
  ),
);
```

**Contingency:**
- Offer "compact mode" option
- Split into multiple PDFs (participants + songs)

**Trigger:**
- User reports of cut-off content

**Owner:** MrPlanner

**Status:** Open - Test in Sprint 6

---

### R07: Hive/Firestore Sync Conflicts

**Description:** Offline edits may conflict with Firestore updates when reconnecting.

**Impact:** High - Data loss or corruption.

**Probability:** Low - Hive-first strategy handles most cases.

**Severity:** **Medium**

**Mitigation:**
- Always save to Hive first
- Sync to Firestore in background
- Use lastUpdated timestamp for conflict resolution
- Show sync status indicator to user

**Code Pattern:**
```dart
Future<void> addTag(String tag) async {
  // Step 1: Save to Hive immediately
  final user = state.value;
  final newTags = [...user.baseTags, tag];
  await _hiveBox.put(user.uid, user.copyWith(baseTags: newTags));
  
  // Update UI immediately
  state = AsyncValue.data(user.copyWith(baseTags: newTags));
  
  // Step 2: Sync to Firestore in background
  try {
    await _repo.updateBaseTags(user.uid, newTags);
  } catch (e) {
    // Mark as pending sync
    _pendingSync.add(user.uid);
  }
}
```

**Contingency:**
- Manual sync button
- Conflict resolution dialog

**Trigger:**
- Sync error logged

**Owner:** MrPlanner

**Status:** Open - Implement in Sprint 3

---

### R08: TextFieldTags Package Compatibility

**Description:** textfield_tags package may not be compatible with Flutter 3.10+.

**Impact:** Medium - May need alternative implementation.

**Probability:** Low - Package is actively maintained.

**Severity:** **Low**

**Mitigation:**
- Check package compatibility before Sprint 5
- Have fallback: built-in Wrap + TextField implementation
- Consider alternative: `flutter_tags` package

**Contingency:**
- Custom tag input widget using Wrap + TextField
- More code but no external dependency

**Trigger:**
- `flutter pub get` fails or runtime errors

**Owner:** MrPlanner

**Status:** Open - Verify in Sprint 5

---

## Risk Review Schedule

| Review | Date | Focus |
|--------|------|-------|
| Sprint 1 Review | Day 1 | R01 (timeout) |
| Sprint 2 Review | Day 2 | R02 (timezone) |
| Sprint 3 Review | Day 4 | R03, R07 (sync) |
| Sprint 4 Review | Day 6 | R04 (serialization) |
| Sprint 5 Review | Day 8 | R05, R08 (performance, package) |
| Sprint 6 Review | Day 9 | R06 (PDF) |
| Final Review | Day 11 | All risks |

---

## Risk Closure Criteria

| Risk | Closure Criteria |
|------|------------------|
| R01 | Timeout rate <1% in production |
| R02 | No timezone bug reports |
| R03 | No data loss incidents |
| R04 | All serialization tests pass |
| R05 | Tag cloud <1s generation |
| R06 | PDF renders correctly with 20+ participants |
| R07 | No sync conflict reports |
| R08 | Package integrates without issues |

---

## Escalation Path

1. **MrPlanner** - Initial risk owner, implements mitigation
2. **Tech Lead** - If mitigation fails, review technical approach
3. **Project Lead** - If timeline impacted, approve scope adjustment

---

**Document Version:** 1.0  
**Last Updated:** February 25, 2026  
**Next Review:** Day 1 (Sprint 1)
