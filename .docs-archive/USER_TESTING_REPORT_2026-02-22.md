# User Testing Report - RepSync App

## Test Session: 2026-02-22 14:00

**Tester:** MrStupidUser (Naive User Persona - Zero Prior Knowledge)
**App Version:** v0.10.0+1
**Platform:** Flutter Web (Primary Target)
**Session Duration:** 90 minutes

---

## Flow: Login/Registration

| Step | Confusion | Severity | Suggestion |
|------|-----------|----------|------------|
| Email field validation | No format hint shown upfront | 🟡 Medium | Add placeholder example: "you@band.com" |
| Password requirements | Only shown after weak password entered | 🟠 High | Show requirements as bullet points below field |
| Forgot password | No recovery option visible anywhere | 🔴 Critical | Add "Forgot Password?" link below password field |
| Post-registration guidance | No indication of what to do next | 🟠 High | Add welcome screen with guided next steps |

---

## Flow: Create Band

| Step | Confusion | Severity | Suggestion |
|------|-----------|----------|------------|
| "+ Group" terminology | Why "Group" instead of "Band"? | 🟡 Medium | Use consistent "Band" terminology everywhere |
| Invite code visibility | Code not shown after creation | 🟠 High | Show invite code immediately with "Copy" button |
| Next steps unclear | What do I do after creating band? | 🟠 High | Add "Invite Members" CTA on success screen |

---

## Flow: Add Song

| Step | Confusion | Severity | Suggestion |
|------|-----------|----------|------------|
| Required fields | Only Title has asterisk, others unclear | 🟡 Medium | Add inline validation hints |
| Original vs Our BPM/Key | What's the difference? | 🟠 High | Add tooltip: "Original = recording, Our = how you play it" |
| Spotify search location | Button at bottom, far from title/artist | 🟠 High | Move search buttons next to title/artist fields |
| BPM/Key jargon | What does BPM mean? What is Key? | 🔴 Critical | Add (?) help icons with explanations |
| Multiple search options | Spotify vs MusicBrainz vs BPM/Key vs Web | 🟡 Medium | Consolidate into single "Search" button with options |
| Form complexity | Overwhelming number of fields | 🟠 High | Use progressive disclosure - show basic fields first |

---

## Flow: Create Setlist

| Step | Confusion | Severity | Suggestion |
|------|-----------|----------|------------|
| Create button location | Save button in AppBar (top right) | 🟠 High | Move to bottom of form as primary CTA |
| Song picker modal | How do I select multiple songs? | 🟡 Medium | Add "Select Multiple" hint or checkbox UI |
| Reorder songs | Drag handle not visible/obvious | 🟡 Medium | Add visual cue: "Drag to reorder" text |
| PDF export location | Hidden in tap-to-view actions | 🔴 Critical | Add "Export PDF" button on setlist card |
| Empty setlist state | No guidance on adding songs | 🟡 Medium | Add "Add your first song" CTA in empty state |

---

## Flow: Metronome

| Step | Confusion | Severity | Suggestion |
|------|-----------|----------|------------|
| Sound type dropdown | "Sine", "Square" - what does this mean? | 🟠 High | Rename to "Tone" with simple descriptions |
| Frequency inputs (Hz) | Why would I need 1600Hz vs 800Hz? | 🔴 Critical | Hide behind "Advanced Settings" collapsible |
| Accent Pattern (ABBB) | Extremely confusing notation | 🔴 Critical | Use visual toggle buttons per beat instead |
| Time signature dropdowns | Separate numerator/denominator confusing | 🟠 High | Use preset buttons: 4/4, 3/4, 6/8, etc. |
| Colored circles meaning | What do blue/red circles represent? | 🟠 High | Add legend: "Red = accented beat, Blue = regular" |
| Accent toggle | What happens when turned off? | 🟡 Medium | Add description: "Disable accent on first beat" |
| Tap BPM unlabeled | Widget present but not identified | 🟡 Medium | Add "Tap BPM" header above widget |
| Start button position | At very bottom, requires scrolling | 🟡 Medium | Move higher or make sticky/floating |

---

# Bug Reports (Unified Format)

## Bug Report
**ID:** UX-001
**Severity:** 🔴 Critical
**Feature:** Authentication
**Steps:** 1. Open login screen 2. Try to find password recovery 3. Search entire app
**Expected:** "Forgot Password?" link visible on login screen
**Actual:** No password recovery option exists in UI
**Evidence:** Login screen (`lib/screens/login_screen.dart`) only has email/password fields and Sign Up link

---

## Bug Report
**ID:** UX-002
**Severity:** 🟠 High
**Feature:** Authentication
**Steps:** 1. Go to register screen 2. Enter password 3. Submit with weak password
**Expected:** Password requirements shown before submission
**Actual:** Requirements only shown after error ("Password is too weak")
**Evidence:** Register screen (`lib/screens/auth/register_screen.dart`) validator only checks length >= 6 after submission

---

## Bug Report
**ID:** UX-003
**Severity:** 🔴 Critical
**Feature:** Setlists
**Steps:** 1. Create setlist 2. Return to setlist list 3. Look for PDF export
**Expected:** PDF export button visible on setlist card
**Actual:** Must tap card to open menu, then select "Export as PDF"
**Evidence:** Export only available via `_showExportOptions()` modal in `lib/screens/setlists/setlists_list_screen.dart`

---

## Bug Report
**ID:** UX-004
**Severity:** 🟠 High
**Feature:** Songs
**Steps:** 1. Open add song screen 2. See "BPM" and "Key" fields
**Expected:** Explanation of what BPM and Key mean
**Actual:** No help text, assumes musical knowledge
**Evidence:** Song form (`lib/screens/songs/components/song_form.dart`) has no tooltips or help text

---

## Bug Report
**ID:** UX-005
**Severity:** 🔴 Critical
**Feature:** Metronome
**Steps:** 1. Open metronome screen 2. See frequency input fields
**Expected:** Simple metronome controls
**Actual:** Technical DAW-style controls (Hz, wave types) overwhelm casual users
**Evidence:** Metronome widget (`lib/widgets/metronome_widget.dart`) shows frequency inputs prominently

---

## Bug Report
**ID:** UX-006
**Severity:** 🟠 High
**Feature:** Bands
**Steps:** 1. Create band 2. Look for invite code
**Expected:** Invite code shown immediately after creation
**Actual:** Must navigate back to band list and tap band card to see code
**Evidence:** Create band screen (`lib/screens/bands/create_band_screen.dart`) only shows success snackbar

---

## Bug Report
**ID:** UX-007
**Severity:** 🟡 Medium
**Feature:** Navigation
**Steps:** 1. View home screen 2. See "+ Group" button
**Expected:** Consistent "Band" terminology
**Actual:** Button says "+ Group" but everywhere else says "Band"
**Evidence:** Home screen (`lib/screens/home_screen.dart`) line: `label: '+ Group'`

---

## Bug Report
**ID:** UX-008
**Severity:** 🟠 High
**Feature:** Songs
**Steps:** 1. Open add song screen 2. Look for Spotify search
**Expected:** Search near title/artist fields
**Actual:** Search buttons at bottom of form, after all fields
**Evidence:** Spotify search button in `lib/screens/songs/add_song_screen.dart` is in bottom action row

---

## Bug Report
**ID:** UX-009
**Severity:** 🔴 Critical
**Feature:** Metronome
**Steps:** 1. Open metronome 2. See "ABBB" accent pattern field
**Expected:** Intuitive accent configuration
**Actual:** Cryptic text input requiring understanding of notation
**Evidence:** Accent pattern TextField in `lib/widgets/metronome_widget.dart` requires "A/B" input

---

## Bug Report
**ID:** UX-010
**Severity:** 🟠 High
**Feature:** Metronome
**Steps:** 1. Open metronome 2. Look at time signature selector
**Expected:** Simple preset selection (4/4, 3/4, etc.)
**Actual:** Two separate dropdowns for numerator and denominator
**Evidence:** TimeSignatureDropdown widget uses separate dropdowns in `lib/widgets/time_signature_dropdown.dart`

---

# What Worked Well

- **Clean Visual Design**: App has professional, polished appearance with consistent color scheme
- **Simple Text Inputs**: Basic form fields work as expected with clear labels
- **Bottom Navigation**: Tab bar easy to understand once visible
- **Quick Actions Concept**: Good placement of common actions on home screen
- **Drag to Reorder**: Setlist song reordering works smoothly (once discovered)
- **Empty States**: Consistent empty state design with action buttons
- **Success Feedback**: Snackbar notifications confirm actions completed

---

# Critical Friction Points (Top 5)

1. **Metronome Technical Overload** - Hz, wave types, accent patterns assume DAW knowledge
2. **Hidden PDF Export** - Critical feature buried in tap-to-view modal
3. **Song Form Complexity** - 15+ fields with no guidance overwhelms new users
4. **No Password Recovery** - Standard auth feature completely missing
5. **Zero Onboarding** - Users dropped into complex app with no introduction

---

# Recommended Priority Order

## P0 - Immediate (User Blocking)
1. UX-001: Add Forgot Password link
2. UX-003: Make PDF export discoverable
3. UX-005: Simplify metronome UI
4. UX-009: Fix accent pattern input

## P1 - Short-term (User Frustration)
1. UX-002: Show password requirements upfront
2. UX-004: Add BPM/Key explanations
3. UX-006: Show invite code after band creation
4. UX-008: Move Spotify search higher
5. UX-010: Add time signature presets

## P2 - Medium-term (Nice to Have)
1. UX-007: Fix terminology consistency
2. Add onboarding flow
3. Add contextual help tooltips
4. Implement progressive disclosure

---

*Report generated by MrStupidUser*
*Session logged: /log/20260222_user_testing.md*
