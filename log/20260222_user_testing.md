# User Testing Session Log - 2026-02-22

**Tester:** MrStupidUser (Naive User Persona)
**Date:** 2026-02-22
**Session Time:** 14:00 - 15:30
**App Version:** v0.10.0+1
**Testing Scope:** Main User Flows

---

## Test Session Summary

| Flow | Completion | Confusion Points | Severity |
|------|------------|------------------|----------|
| Login/Registration | Partial | 4 | High |
| Create Band | Complete | 3 | Medium |
| Add Song | Partial | 6 | High |
| Create Setlist | Partial | 5 | High |
| Metronome | Complete | 8 | Critical |

---

## Detailed Observations

### 1. Login/Registration Flow

**Path Tested:** Login Screen -> Register Screen

**What I Did:**
1. Opened the app
2. Saw login screen with email/password fields
3. Clicked "Sign Up" to register
4. Entered email and password
5. Created account

**Confusion Points:**
- No indication of what email format is expected (beyond basic validation)
- Password requirements only shown after entering weak password
- No "Forgot Password" option visible anywhere
- No clear indication of what happens after registration

**Emotional State:**
- Initial: Curious
- During: Anxious (will my password work?)
- After: Relieved but uncertain

---

### 2. Create Band Flow

**Path Tested:** Home Screen -> Quick Actions -> "+ Group" -> Create Band Screen

**What I Did:**
1. Landed on home screen after login
2. Saw "+ Group" button in Quick Actions
3. Clicked it and was taken to Create Band screen
4. Entered band name and description
5. Saved the band

**Confusion Points:**
- Why is it called "+ Group" instead of "+ Band"? (Inconsistent terminology)
- No explanation of what happens after creating a band
- No visible invite code shown after creation - had to tap on the band card to find it
- Unclear what I should do next after creating the band

**Emotional State:**
- Initial: Confused (Group vs Band)
- During: Satisfied (form was simple)
- After: Lost (what now?)

---

### 3. Add Song Flow

**Path Tested:** Home Screen -> Quick Actions -> "+ Song" -> Add Song Screen

**What I Did:**
1. Clicked "+ Song" from home screen
2. Saw form with many fields
3. Tried to use Spotify search
4. Entered BPM and Key manually

**Confusion Points:**
- SO many fields! Which ones are required?
- What's the difference between "Original Key/BPM" and "Our Key/BPM"?
- Spotify search button is at the BOTTOM of the form, not near the title/artist fields
- "BPM" and "Key" are musician jargon - no explanation provided
- The "BPM/Key" auto-fetch button is separate from Spotify search - why?
- What does the "Web" search button do differently from Spotify?

**Emotional State:**
- Initial: Overwhelmed
- During: Frustrated (too many decisions)
- After: Defeated (just want to add a song!)

---

### 4. Create Setlist Flow

**Path Tested:** Home Screen -> Quick Actions -> "+ Setlist" -> Create Setlist Screen

**What I Did:**
1. Clicked "+ Setlist" from home screen
2. Entered setlist name
3. Tried to add songs
4. Looked for PDF export option

**Confusion Points:**
- Create button is in AppBar (top right) - not discoverable
- "Add Songs" button appears but song picker modal is confusing
- No visual feedback on how to reorder songs (drag handle is subtle)
- PDF export is HIDDEN - had to tap on setlist card to find export options
- No indication that songs need to be added BEFORE creating setlist

**Emotional State:**
- Initial: Hopeful
- During: Confused (where's the create button?)
- After: Frustrated (can't find PDF export)

---

### 5. Metronome Flow

**Path Tested:** Home Screen -> Tools -> Metronome -> Metronome Screen

**What I Did:**
1. Found "Metronome" under Tools section
2. Opened metronome screen
3. Tried to adjust BPM
4. Tried to understand time signature
5. Tried to configure accent pattern

**Confusion Points:**
- "Sound" dropdown says "Sine", "Square" etc - what does this mean?
- Frequency input fields (1600Hz, 800Hz) - why would I need this?
- "Accent Pattern" with ABBB - this is extremely confusing!
- Time signature dropdowns are separate (numerator/denominator) - why not presets?
- No explanation of what the colored circles mean
- "Accent on beat 1" toggle - what happens if I turn it off?
- Tap BPM widget is present but not labeled
- Start button is at the very bottom - lots of scrolling needed

**Emotional State:**
- Initial: Intrigued
- During: Completely Lost (what is Hz?)
- After: Defeated (just want a simple metronome!)

---

## Key Insights

### What Worked Well
1. **Clean Visual Design** - App looks professional and polished
2. **Simple Forms** - Text input fields work as expected
3. **Bottom Navigation** - Easy to understand once you see it
4. **Quick Actions** - Good concept for common tasks

### Critical Friction Points (Top 5)
1. **Metronome Technical Jargon** - Hz, wave types, accent patterns overwhelm casual users
2. **Hidden PDF Export** - Critical feature buried in tap-to-view actions
3. **Song Form Complexity** - Too many fields without clear guidance
4. **Inconsistent Terminology** - "Group" vs "Band" confusion
5. **No Onboarding** - Users dropped into complex app with zero guidance

### Missing Features Users Would Expect
1. **Forgot Password** - Standard auth feature completely absent
2. **Password Requirements** - Should be shown upfront
3. **Field Help/Tooltips** - What is BPM? What is Key?
4. **Empty State Guidance** - "No songs yet" should explain what a song is
5. **Progressive Disclosure** - Show simple options first, advanced on demand

---

## Recommendations Summary

### Immediate (P0 - Critical)
1. Add "Forgot Password" link on login screen
2. Show password requirements upfront on register screen
3. Move PDF export to a more discoverable location
4. Add tooltips/explanations for BPM and Key fields

### Short-term (P1 - High)
1. Simplify metronome UI - hide advanced frequency controls
2. Add onboarding flow for first-time users
3. Rename "+ Group" to "+ Band" for consistency
4. Add field-level help text throughout app

### Medium-term (P2 - Medium)
1. Implement progressive disclosure for advanced features
2. Add contextual help tooltips
3. Create video tutorials for complex features
4. Add search functionality to find features

---

**Next Steps:**
1. Create bug reports in unified format
2. Update ToDo.md with UX improvements
3. Present findings to UX team

---

*Session logged by MrStupidUser*
*Append-only mode active*
