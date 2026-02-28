# Band Members Gray Screen Issue - Comprehensive Test Scenarios

**Issue Reference:** Band A → Members expanded → Gray screen | Band B → Members expanded → Works
**Affected Component:** `/lib/screens/bands/band_songs_screen.dart` - `_buildMemberTile()` method
**Related Files:** 
- `/lib/models/band.dart` (BandMember model)
- `/lib/widgets/band_card.dart` (BandCard widget)
- `/lib/screens/bands/band_songs_screen.dart` (Main screen with expand/collapse)

---

## Test Scenario Summary

| Category | Test Count | Priority |
|----------|------------|----------|
| Data-Driven Tests | 6 | P0 |
| UI Layout Tests | 6 | P1 |
| State Management Tests | 5 | P0 |
| Edge Cases | 5 | P1 |
| **Total** | **22** | |

---

## 1. DATA-DRIVEN TESTS

### Test 1.1: Band with Zero Members
| Field | Value |
|-------|-------|
| **Test Name** | DD-01: Empty Members Array Rendering |
| **Test ID** | BAND-MEM-001 |
| **Precondition** | Band with `members: []` (empty array) |
| **Band Data** | `{id: 'band-empty', name: 'Empty Band', members: [], memberUids: []}` |
| **Action** | Navigate to band songs screen → Members section is expanded by default |
| **Expected Result** | Members section shows "No members found" or empty state, no gray screen |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Empty state displayed without crash or gray screen. FAIL: Gray screen or exception |
| **Priority** | P0 |

---

### Test 1.2: Band with Single Member
| Field | Value |
|-------|-------|
| **Test Name** | DD-02: Single Member Rendering |
| **Test ID** | BAND-MEM-002 |
| **Precondition** | Band with exactly 1 member |
| **Band Data** | `{id: 'band-solo', name: 'Solo Act', members: [{uid: 'user-1', role: 'admin', displayName: 'John'}]}` |
| **Action** | Navigate to band songs screen → Toggle expand/collapse 3 times |
| **Expected Result** | Single member tile renders correctly with avatar, name, and role badge |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Member tile visible with correct data. FAIL: Gray screen, missing data, or crash |
| **Priority** | P0 |

---

### Test 1.3: Band with Multiple Members (5+)
| Field | Value |
|-------|-------|
| **Test Name** | DD-03: Multiple Members Rendering |
| **Test ID** | BAND-MEM-003 |
| **Precondition** | Band with 5+ members with varying roles |
| **Band Data** | ```{id: 'band-full', name: 'Full Band', members: [{uid: 'u1', role: 'admin', displayName: 'Alice'}, {uid: 'u2', role: 'editor', displayName: 'Bob'}, {uid: 'u3', role: 'viewer', displayName: 'Carol'}, {uid: 'u4', role: 'viewer', displayName: 'Dave'}, {uid: 'u5', role: 'editor', displayName: 'Eve'}]}``` |
| **Action** | Navigate to band songs screen → Expand members → Scroll through list |
| **Expected Result** | All 5 members render correctly with proper avatars, names, and role badges |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: All members visible, scrollable, no gray screen. FAIL: Missing members, gray screen, or layout issues |
| **Priority** | P0 |

---

### Test 1.4: Band with Null Members Array
| Field | Value |
|-------|-------|
| **Test Name** | DD-04: Null Members Array Handling |
| **Test ID** | BAND-MEM-004 |
| **Precondition** | Band data where members field is explicitly null |
| **Band Data** | `{id: 'band-null', name: 'Null Band', members: null}` (raw JSON from Firestore) |
| **Action** | Navigate to band songs screen → Members section attempts to render |
| **Expected Result** | Graceful handling - shows empty state or 0 members, no crash |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: No exception, empty state shown. FAIL: Exception thrown, gray screen, or app crash |
| **Priority** | P0 |
| **Notes** | Check `Band._membersFromJson` handles null correctly |

---

### Test 1.5: Band with Empty Members Array vs Missing Array
| Field | Value |
|-------|-------|
| **Test Name** | DD-05: Empty vs Missing Members Array |
| **Test ID** | BAND-MEM-005 |
| **Precondition** | Two bands: one with `members: []`, one with no members field |
| **Band Data** | Band A: `{members: []}`, Band B: `{}` (no members key) |
| **Action** | Switch between Band A and Band B → Expand members on both |
| **Expected Result** | Both bands handle gracefully with empty state |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Both render empty state. FAIL: Either causes gray screen |
| **Priority** | P1 |

---

### Test 1.6: Band with Members Having Null Fields
| Field | Value |
|-------|-------|
| **Test Name** | DD-06: Member with Null Fields |
| **Test ID** | BAND-MEM-006 |
| **Precondition** | Band with members having various null fields |
| **Band Data** | ```members: [{uid: null, role: 'admin', displayName: 'NoUID'}, {uid: 'u2', role: null, displayName: 'NoRole'}, {uid: 'u3', role: 'viewer', displayName: null, email: null}]``` |
| **Action** | Expand members section → Observe each member tile |
| **Expected Result** | Each member shows fallback values ('Unknown', default role 'viewer') |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Fallback values displayed, no crash. FAIL: Gray screen or exception on null access |
| **Priority** | P0 |
| **Notes** | Critical: Check `(member.displayName ?? member.email ?? '?')[0]` for null safety |

---

## 2. UI LAYOUT TESTS

### Test 2.1: Expanded vs Collapsed State Rendering
| Field | Value |
|-------|-------|
| **Test Name** | UI-01: Expand/Collapse Visual State |
| **Test ID** | BAND-MEM-007 |
| **Precondition** | Band with 3+ members |
| **Band Data** | Standard band with 3 members |
| **Action** | Toggle expand/collapse 5 times rapidly |
| **Expected Result** | Smooth animation, arrow rotates 180°, content shows/hides correctly |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Animation smooth, no visual glitches. FAIL: Stuck state, gray screen, or animation freeze |
| **Priority** | P1 |

---

### Test 2.2: Different Screen Sizes (Responsive Layout)
| Field | Value |
|-------|-------|
| **Test Name** | UI-02: Responsive Layout Testing |
| **Test ID** | BAND-MEM-008 |
| **Precondition** | Band with 3+ members |
| **Band Data** | Standard band with members having long names |
| **Action** | Test on: Phone (320px), Tablet (768px), Desktop (1200px) |
| **Expected Result** | Members list adapts to screen width, text wraps appropriately |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Layout adapts without overflow or gray screen. FAIL: Layout broken on any size |
| **Priority** | P1 |

---

### Test 2.3: Portrait vs Landscape Orientation
| Field | Value |
|-------|-------|
| **Test Name** | UI-03: Orientation Change Handling |
| **Test ID** | BAND-MEM-009 |
| **Precondition** | Band with members expanded |
| **Band Data** | Band with 4+ members |
| **Action** | Expand members → Rotate device portrait ↔ landscape 3 times |
| **Expected Result** | Members list reflows correctly, no state loss |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: State preserved, layout adapts. FAIL: Gray screen or state loss |
| **Priority** | P2 |

---

### Test 2.4: Long Member Names (Text Overflow)
| Field | Value |
|-------|-------|
| **Test Name** | UI-04: Long Name Overflow Handling |
| **Test ID** | BAND-MEM-010 |
| **Precondition** | Member with 50+ character display name |
| **Band Data** | `{displayName: 'Christopher Alexander Montgomery-Smithington III', email: '...'}` |
| **Action** | Expand members → Observe long name rendering |
| **Expected Result** | Name truncates with ellipsis, no layout break |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Text ellipsis applied, layout intact. FAIL: Text overflow, gray screen, or layout break |
| **Priority** | P1 |

---

### Test 2.5: Empty Role Display
| Field | Value |
|-------|-------|
| **Test Name** | UI-05: Empty/Invalid Role Badge |
| **Test ID** | BAND-MEM-011 |
| **Precondition** | Member with empty string or invalid role |
| **Band Data** | `{role: ''}`, `{role: 'invalid_role'}`, `{role: 'ADMIN'}` (case variation) |
| **Action** | Expand members → Check role badge display |
| **Expected Result** | Invalid/empty roles default to 'Viewer' (gray badge) |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Default badge shown. FAIL: No badge, crash, or incorrect badge |
| **Priority** | P2 |

---

### Test 2.6: Member with Music Roles (Chip Display)
| Field | Value |
|-------|-------|
| **Test Name** | UI-06: Music Roles Chip Rendering |
| **Test ID** | BAND-MEM-012 |
| **Precondition** | Member with multiple music roles |
| **Band Data** | `{musicRoles: ['guitarist', 'vocalist', 'songwriter', 'producer']}` |
| **Action** | Expand members → Observe music role chips |
| **Expected Result** | All chips visible, wrapped correctly, no overflow |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: All chips visible and readable. FAIL: Chips overflow or cause gray screen |
| **Priority** | P2 |

---

## 3. STATE MANAGEMENT TESTS

### Test 3.1: Multiple Expand/Collapse Toggles
| Field | Value |
|-------|-------|
| **Test Name** | SM-01: Rapid Toggle Stress Test |
| **Test ID** | BAND-MEM-013 |
| **Precondition** | Band with 5+ members |
| **Band Data** | Standard band data |
| **Action** | Tap expand/collapse 20 times in rapid succession |
| **Expected Result** | State remains consistent, no memory leak or crash |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Consistent behavior throughout. FAIL: State corruption, gray screen, or crash |
| **Priority** | P0 |

---

### Test 3.2: Switch Between Bands (A → B → A)
| Field | Value |
|-------|-------|
| **Test Name** | SM-02: Band Switching State Preservation |
| **Test ID** | BAND-MEM-014 |
| **Precondition** | Two bands: Band A (3 members), Band B (5 members) |
| **Band Data** | Band A: Problem band (gray screen), Band B: Working band |
| **Action** | Open Band A → Expand → Navigate back → Open Band B → Expand → Navigate back → Open Band A → Expand |
| **Expected Result** | Each band maintains independent state, no cross-contamination |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Each band renders correctly. FAIL: Band A shows gray screen on return |
| **Priority** | P0 |
| **Notes** | **CRITICAL TEST** - Reproduces reported issue |

---

### Test 3.3: Hot Reload During Expanded State
| Field | Value |
|-------|-------|
| **Test Name** | SM-03: Hot Reload State Recovery |
| **Test ID** | BAND-MEM-015 |
| **Precondition** | Band with members expanded |
| **Band Data** | Band with 4+ members |
| **Action** | Expand members → Trigger hot reload → Observe state |
| **Expected Result** | State preserved or gracefully reset, no crash |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: State preserved or clean reset. FAIL: Gray screen or exception |
| **Priority** | P1 |

---

### Test 3.4: App Background/Foreground During Expanded State
| Field | Value |
|-------|-------|
| **Test Name** | SM-04: Lifecycle State Recovery |
| **Test ID** | BAND-MEM-016 |
| **Precondition** | Band with members expanded |
| **Band Data** | Band with 4+ members |
| **Action** | Expand members → Background app → Wait 5 seconds → Foreground app |
| **Expected Result** | State preserved, members still expanded |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: State preserved. FAIL: Gray screen or state loss |
| **Priority** | P1 |

---

### Test 3.5: Navigation Back and Forth
| Field | Value |
|-------|-------|
| **Test Name** | SM-05: Deep Navigation State |
| **Test ID** | BAND-MEM-017 |
| **Precondition** | Band songs screen with members expanded |
| **Band Data** | Band with 3+ members |
| **Action** | Expand members → Navigate to song detail → Back → Expand members → Navigate to About Band → Back |
| **Expected Result** | Members state preserved through navigation stack |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: State preserved. FAIL: Gray screen on return |
| **Priority** | P2 |

---

## 4. EDGE CASES

### Test 4.1: Member with Very Long Email
| Field | Value |
|-------|-------|
| **Test Name** | EC-01: Long Email Fallback |
| **Test ID** | BAND-MEM-018 |
| **Precondition** | Member with no displayName, very long email |
| **Band Data** | `{displayName: null, email: 'verylongemailaddress@verylongdomainname.example.com'}` |
| **Action** | Expand members → Observe avatar initial and display text |
| **Expected Result** | Avatar shows 'V', email truncates with ellipsis |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Email displays with truncation. FAIL: Overflow or gray screen |
| **Priority** | P2 |

---

### Test 4.2: Member with Special Characters
| Field | Value |
|-------|-------|
| **Test Name** | EC-02: Special Character Handling |
| **Test ID** | BAND-MEM-019 |
| **Precondition** | Member with special characters in name |
| **Band Data** | `{displayName: 'José García <script>alert("xss")</script>'}` |
| **Action** | Expand members → Observe rendering |
| **Expected Result** | Special characters display correctly, no XSS execution |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Characters render safely. FAIL: Crash or script execution |
| **Priority** | P2 |

---

### Test 4.3: Member with Empty Strings for All Fields
| Field | Value |
|-------|-------|
| **Test Name** | EC-03: All Empty String Fields |
| **Test ID** | BAND-MEM-020 |
| **Precondition** | Member with all fields as empty strings |
| **Band Data** | `{uid: '', role: '', displayName: '', email: ''}` |
| **Action** | Expand members → Observe tile rendering |
| **Expected Result** | Shows 'Unknown' with default viewer badge |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Default values shown. FAIL: Gray screen or exception |
| **Priority** | P1 |
| **Notes** | Check `(member.displayName ?? member.email ?? '?')[0]` - empty string is not null! |

---

### Test 4.4: Members with Duplicate UIDs
| Field | Value |
|-------|-------|
| **Test Name** | EC-04: Duplicate UID Handling |
| **Test ID** | BAND-MEM-021 |
| **Precondition** | Band with multiple members sharing same UID |
| **Band Data** | `[{uid: 'same-uid', displayName: 'Alice'}, {uid: 'same-uid', displayName: 'Bob'}]` |
| **Action** | Expand members → Observe both entries |
| **Expected Result** | Both members displayed (data issue, not UI crash) |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Both displayed without crash. FAIL: Gray screen or exception |
| **Priority** | P2 |

---

### Test 4.5: Band with memberUids but No Members Array
| Field | Value |
|-------|-------|
| **Test Name** | EC-05: Mismatched memberUids/members |
| **Test ID** | BAND-MEM-022 |
| **Precondition** | Band data inconsistency |
| **Band Data** | `{memberUids: ['u1', 'u2'], members: []}` or `{memberUids: [], members: [...]}` |
| **Action** | Expand members → Observe rendering |
| **Expected Result** | Members array takes precedence, shows actual members |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Members array used. FAIL: Gray screen or exception |
| **Priority** | P1 |
| **Notes** | Check `BandDataFixer` service for data repair |

---

## 5. ADDITIONAL CRITICAL TESTS

### Test 5.1: Avatar Initial from Empty String
| Field | Value |
|-------|-------|
| **Test Name** | CRIT-01: Empty String [0] Access |
| **Test ID** | BAND-MEM-023 |
| **Precondition** | Member with displayName: '' (empty string, not null) |
| **Band Data** | `{displayName: '', email: ''}` |
| **Action** | Expand members → Avatar renders |
| **Expected Result** | Shows '?' as fallback (empty string is truthy in ?? operator!) |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: '?' shown. FAIL: Exception on `''[0]` or gray screen |
| **Priority** | P0 |
| **Notes** | **CRITICAL BUG POTENTIAL**: `('' ?? '?')[0]` returns `''[0]` = `''`, not `'?'` |

---

### Test 5.2: Unicode and Emoji in Names
| Field | Value |
|-------|-------|
| **Test Name** | CRIT-02: Unicode/Emoji Rendering |
| **Test ID** | BAND-MEM-024 |
| **Precondition** | Member with emoji or multi-byte characters |
| **Band Data** | `{displayName: '🎸 Rock Star 音楽'}` |
| **Action** | Expand members → Observe avatar and name |
| **Expected Result** | Emoji/unicode renders correctly, avatar shows first character |
| **Actual Result** | [To be filled during test execution] |
| **Pass/Fail Criteria** | PASS: Correct rendering. FAIL: Garbled text or crash |
| **Priority** | P2 |

---

## APPENDIX A: POTENTIAL ROOT CAUSES

Based on code analysis, here are potential causes for the gray screen:

### A1: Null Safety Issue in Avatar Initial
```dart
// File: band_songs_screen.dart, line ~677
(member.displayName ?? member.email ?? '?')[0]
```
**Problem:** If `displayName` is empty string `''`, the `??` operator won't fallback because empty string is not null.
**Fix:** Use `.isNotEmpty` check:
```dart
(member.displayName?.isNotEmpty == true ? member.displayName : member.email?.isNotEmpty == true ? member.email : '?')[0]
```

### A2: Member Data Inconsistency Between Bands
**Problem:** Band A may have corrupted member data (null in array, missing fields)
**Investigation:** Run `/scripts/debug_band_data.dart` on both bands

### A3: State Management Issue with _isMembersExpanded
**Problem:** State may not reset when switching bands
**Location:** `_BandSongsScreenState._isMembersExpanded` is instance variable

### A4: List Rendering with Null Elements
```dart
// File: band_songs_screen.dart, line ~352
children: band.members.map((member) {
  return _buildMemberTile(member);
}).toList(),
```
**Problem:** If `band.members` contains null elements, map will fail

---

## APPENDIX B: TEST EXECUTION CHECKLIST

### Pre-Test Setup
- [ ] Firebase emulator running
- [ ] Test bands created in Firestore:
  - [ ] Band A (problematic band) - Document ID recorded: _______
  - [ ] Band B (working band) - Document ID recorded: _______
- [ ] Test user account created - UID: _______

### Test Execution Order
1. **P0 Tests (Critical)** - Execute first:
   - [ ] BAND-MEM-001 (Empty members)
   - [ ] BAND-MEM-002 (Single member)
   - [ ] BAND-MEM-003 (Multiple members)
   - [ ] BAND-MEM-004 (Null members)
   - [ ] BAND-MEM-006 (Null fields)
   - [ ] BAND-MEM-013 (Rapid toggle)
   - [ ] BAND-MEM-014 (Band switching)
   - [ ] BAND-MEM-023 (Empty string avatar)

2. **P1 Tests (Important)** - Execute second:
   - [ ] BAND-MEM-005 (Empty vs missing)
   - [ ] BAND-MEM-007 (Expand/collapse)
   - [ ] BAND-MEM-008 (Responsive)
   - [ ] BAND-MEM-010 (Long names)
   - [ ] BAND-MEM-015 (Hot reload)
   - [ ] BAND-MEM-016 (Lifecycle)
   - [ ] BAND-MEM-020 (Empty strings)
   - [ ] BAND-MEM-022 (Data mismatch)

3. **P2 Tests (Edge Cases)** - Execute last:
   - [ ] BAND-MEM-009 (Orientation)
   - [ ] BAND-MEM-011 (Empty role)
   - [ ] BAND-MEM-012 (Music roles)
   - [ ] BAND-MEM-017 (Navigation)
   - [ ] BAND-MEM-018 (Long email)
   - [ ] BAND-MEM-019 (Special chars)
   - [ ] BAND-MEM-021 (Duplicate UIDs)
   - [ ] BAND-MEM-024 (Unicode)

---

## APPENDIX C: DEBUG COMMANDS

### Check Band Data
```bash
cd scripts
dart debug_band_data.dart --band-id <BAND_ID>
```

### Run Unit Tests
```bash
flutter test test/models/band_test.dart
flutter test test/widgets/band_card_test.dart
```

### Run Integration Tests
```bash
flutter test test/integration/band_management_test.dart
```

### Firestore Emulator
```bash
firebase emulators:start --only firestore
```

---

**Document Version:** 1.0
**Created:** 2026-02-28
**Author:** Test Scenario Generator
**Review Status:** Pending QA Review
