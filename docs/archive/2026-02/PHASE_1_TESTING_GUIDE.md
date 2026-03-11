# 🧪 Phase 1 Testing Guide - Song Deduplication

**Status:** Ready for Testing  
**Duration:** 2-3 days  
**Goal:** Validate fuzzy matching works correctly with real data

---

## 📋 Pre-Testing Checklist

### Prerequisites:
- [ ] Phase 1 code deployed to test environment
- [ ] Test database with sample songs (at least 50 songs)
- [ ] Test user account created
- [ ] Testing device/emulator ready

### Sample Data Setup:

Create these test songs in your database:

```dart
// Core test songs (add these first)
[
  Song(title: 'Bohemian Rhapsody', artist: 'Queen', durationMs: 354000),
  Song(title: 'Hey Jude', artist: 'The Beatles', durationMs: 431000),
  Song(title: 'Imagine', artist: 'John Lennon', durationMs: 183000),
  Song(title: 'Stairway to Heaven', artist: 'Led Zeppelin', durationMs: 482000),
  Song(title: 'Hotel California', artist: 'Eagles', durationMs: 391000),
  Song(title: 'Sweet Child O Mine', artist: "Guns N' Roses", durationMs: 356000),
  Song(title: 'Smells Like Teen Spirit', artist: 'Nirvana', durationMs: 301000),
  Song(title: 'Like a Rolling Stone', artist: 'Bob Dylan', durationMs: 369000),
  Song(title: 'Purple Haze', artist: 'Jimi Hendrix', durationMs: 170000),
  Song(title: 'Paint It Black', artist: 'The Rolling Stones', durationMs: 222000),
]
```

---

## 🎯 Test Scenarios

### Scenario 1: Typo Tolerance

**Test Case 1.1:** Single character typo
```
Input:  "Bohemian Rapsody" by Queen
Expected: Match found with 94%+ confidence
Action: Show "Did you mean?" dialog
```

**Test Case 1.2:** Double character typo
```
Input:  "Bohemian Rhapsdy" by Queen
Expected: Match found with 88%+ confidence
Action: Show "Did you mean?" dialog
```

**Test Case 1.3:** Missing space
```
Input:  "HeyJude" by The Beatles
Expected: Match found with 85%+ confidence
Action: Show "Did you mean?" dialog
```

**Test Case 1.4:** Extra space
```
Input:  "Imagine"  by  John Lennon
Expected: Match found with 98%+ confidence
Action: Show "Did you mean?" dialog
```

---

### Scenario 2: Artist Name Variations

**Test Case 2.1:** "The" prefix
```
Input:  "Hey Jude" by Beatles
Expected: Match found with 98% confidence (The Beatles)
Action: Show "Did you mean?" dialog
```

**Test Case 2.2:** Abbreviation
```
Input:  "Like a Rolling Stone" by Bob Dylan
Expected: Match found with 100% confidence
Action: Show "Did you mean?" dialog
```

**Test Case 2.3:** Special characters
```
Input:  "Sweet Child O Mine" by Guns and Roses
Expected: Match found with 90%+ confidence (Guns N' Roses)
Action: Show "Did you mean?" dialog
```

---

### Scenario 3: Version Suffixes

**Test Case 3.1:** Live version
```
Input:  "Imagine (Live)" by John Lennon
Expected: Match found with 92% confidence (studio version)
Action: Show "Did you mean?" dialog with note "Live version detected"
```

**Test Case 3.2:** Remastered
```
Input:  "Bohemian Rhapsody (Remastered 2011)" by Queen
Expected: Match found with 95% confidence
Action: Show "Did you mean?" dialog
```

**Test Case 3.3:** Acoustic version
```
Input:  "Hotel California (Acoustic)" by Eagles
Expected: Match found with 92% confidence
Action: Show "Did you mean?" dialog with note "Acoustic version detected"
```

---

### Scenario 4: No Match (Different Song)

**Test Case 4.1:** Completely different song
```
Input:  "Stairway to Heaven" by Led Zeppelin
Expected: No match found (if not in database yet)
Action: Allow creating new song
```

**Test Case 4.2:** Similar title, different artist
```
Input:  "Imagine" by Madonna
Expected: Low confidence match (< 70%)
Action: Allow creating new song with warning
```

---

### Scenario 5: Confidence Thresholds

**Test Case 5.1:** High confidence (98%+)
```
Expected: Auto-suggest with prominent dialog
UI: Green highlight, "Use this song" button
```

**Test Case 5.2:** Medium confidence (85-97%)
```
Expected: Show "Did you mean?" dialog
UI: Yellow highlight, "Use this" / "Create new" buttons
```

**Test Case 5.3:** Low confidence (70-84%)
```
Expected: Show in "Possible matches" list
UI: Gray highlight, expandable list
```

**Test Case 5.4:** Very low confidence (< 70%)
```
Expected: No suggestion shown
UI: Allow creating new song without interruption
```

---

### Scenario 6: Performance

**Test Case 6.1:** Match calculation speed
```
Action: Time the match calculation
Expected: < 100ms per match
Pass Criteria: 95% of matches < 100ms
```

**Test Case 6.2:** UI responsiveness
```
Action: Type song title and observe UI
Expected: No lag or freezing
Pass Criteria: UI remains responsive during matching
```

**Test Case 6.3:** Large database
```
Action: Test with 1000+ songs in database
Expected: Match calculation still < 200ms
Pass Criteria: Performance degradation < 50%
```

---

### Scenario 7: Edge Cases

**Test Case 7.1:** Empty title
```
Input:  "" by Queen
Expected: Graceful handling, no crash
Action: Show validation error "Title required"
```

**Test Case 7.2:** Empty artist
```
Input:  "Bohemian Rhapsody" by ""
Expected: Match based on title only
Action: Show matches with lower confidence
```

**Test Case 7.3:** Very long title (100+ chars)
```
Input:  "This is a very long song title that exceeds normal length expectations by a significant margin and should still be handled correctly by the matching algorithm" by Queen
Expected: No crash, matching works
Action: Truncate display but match on full title
```

**Test Case 7.4:** Unicode characters
```
Input:  "Bohemian Rhapsody 🎵" by Queen
Expected: Unicode handled gracefully
Action: Strip emojis for matching
```

**Test Case 7.5:** All caps
```
Input:  "BOHEMIAN RHAPSODY" by QUEEN
Expected: Match found with 98%+ confidence
Action: Case-insensitive matching works
```

**Test Case 7.6:** Punctuation variations
```
Input:  "Bohemian Rhapsody!!!" by Queen???
Expected: Match found with 98%+ confidence
Action: Punctuation stripped for matching
```

---

### Scenario 8: Integration Tests

**Test Case 8.1:** AddSongScreen integration
```
Action: Open AddSongScreen, type song title
Expected: Match dialog appears when typing
Pass Criteria: Dialog shows within 1 second of typing
```

**Test Case 8.2:** EditSongScreen integration
```
Action: Edit existing song, change title
Expected: Match dialog appears for other songs
Pass Criteria: Doesn't suggest the song being edited
```

**Test Case 8.3:** CSV Import integration
```
Action: Import CSV with 10 songs (5 duplicates, 5 new)
Expected: Dialog shows for each duplicate
Pass Criteria: User can choose for each song individually
```

**Test Case 8.4:** Firestore indexes
```
Action: Check Firestore indexes exist
Expected: Indexes on normalized_title, normalized_artist
Pass Criteria: Query performance < 50ms
```

---

## 📊 Test Results Template

### Test Execution Log:

| Test ID | Test Name | Result | Confidence | Notes |
|---------|-----------|--------|------------|-------|
| 1.1 | Single char typo | PASS/FAIL | 94% | |
| 1.2 | Double char typo | PASS/FAIL | 88% | |
| 1.3 | Missing space | PASS/FAIL | 85% | |
| 2.1 | "The" prefix | PASS/FAIL | 98% | |
| 2.2 | Abbreviation | PASS/FAIL | 100% | |
| 2.3 | Special chars | PASS/FAIL | 90% | |
| 3.1 | Live version | PASS/FAIL | 92% | |
| 3.2 | Remastered | PASS/FAIL | 95% | |
| 3.3 | Acoustic | PASS/FAIL | 92% | |
| 4.1 | Different song | PASS/FAIL | 0% | |
| 4.2 | Similar title | PASS/FAIL | 65% | |
| 5.1 | High confidence | PASS/FAIL | 98% | |
| 5.2 | Medium confidence | PASS/FAIL | 90% | |
| 5.3 | Low confidence | PASS/FAIL | 75% | |
| 5.4 | Very low | PASS/FAIL | 50% | |
| 6.1 | Speed < 100ms | PASS/FAIL | - | Actual: ___ms |
| 6.2 | UI responsive | PASS/FAIL | - | |
| 6.3 | Large DB | PASS/FAIL | - | Actual: ___ms |
| 7.1 | Empty title | PASS/FAIL | - | |
| 7.2 | Empty artist | PASS/FAIL | - | |
| 7.3 | Long title | PASS/FAIL | - | |
| 7.4 | Unicode | PASS/FAIL | - | |
| 7.5 | All caps | PASS/FAIL | - | |
| 7.6 | Punctuation | PASS/FAIL | - | |
| 8.1 | AddSongScreen | PASS/FAIL | - | |
| 8.2 | EditSongScreen | PASS/FAIL | - | |
| 8.3 | CSV Import | PASS/FAIL | - | |
| 8.4 | Indexes | PASS/FAIL | - | |

---

## 🐛 Bug Report Template

If you find issues, document them:

```markdown
### Bug #___: [Short description]

**Severity:** Critical / High / Medium / Low

**Test Case:** [Test ID from above]

**Steps to Reproduce:**
1. Open AddSongScreen
2. Type "Bohemian Rapsody"
3. ...

**Expected Behavior:**
Match found with 94% confidence

**Actual Behavior:**
[What actually happened]

**Screenshots:**
[If applicable]

**Environment:**
- Device: [iPhone 14 / Samsung Galaxy S23 / Emulator]
- OS Version: [iOS 16.4 / Android 13]
- App Version: [0.11.2+105]

**Frequency:**
Always / Sometimes / Rarely

**Workaround:**
[If any]
```

---

## ✅ Exit Criteria (Phase 1 Complete)

Phase 1 is ready for production when:

- [ ] All 26 test scenarios executed
- [ ] >= 90% test pass rate (23/26 tests passing)
- [ ] No Critical or High severity bugs
- [ ] Performance tests pass (< 100ms match calculation)
- [ ] UI/UX approved by product owner
- [ ] At least 3 team members have tested independently

---

## 🚀 How to Run Tests

### Manual Testing:
1. Open app on test device
2. Navigate to Songs → Add Song
3. Follow test scenarios above
4. Record results in Test Results Template

### Automated Testing:
```bash
# Run unit tests (already passing)
flutter test test/services/matching/

# Run integration tests (if available)
flutter test test/integration/song_matching_test.dart

# Run with coverage
flutter test --coverage test/services/matching/
```

---

## 📞 Support

If you encounter issues during testing:

1. **Check logs:**
   ```bash
   flutter logs | grep -i "matching\|song"
   ```

2. **Verify database:**
   ```dart
   // In Flutter DevTools, check Firestore
   // Verify normalized_title and normalized_artist fields exist
   ```

3. **Review implementation:**
   - `/lib/services/matching/song_matching_service.dart`
   - `/lib/widgets/matching/song_match_dialog.dart`

---

**Testing Duration:** 2-3 days  
**Expected Completion:** [Date]  
**Test Lead:** [Name]  
**Status:** Ready to Start
