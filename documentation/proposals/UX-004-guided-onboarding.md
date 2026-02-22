# PROPOSAL UX-004: Create Guided Onboarding Flow

**Status:** Pending Approval  
**Priority:** P1 (High)  
**Effort:** High  
**Impact:** High  

---

## Problem Statement

First-time users have no guidance:
1. User logs in for the first time
2. Sees empty HomeScreen with statistics showing 0
3. No indication of what to do next
4. Must discover band creation independently
5. High drop-off rate expected

This violates **Nielsen Heuristic #2: Match Between System and Real World** - new users don't understand the app's mental model.

---

## Proposed Solution

**Create a 3-step onboarding flow:**

### Step 1: Welcome Screen
- Value proposition: "Manage your band's repertoire with ease"
- Key features highlighted (Songs, Setlists, Metronome)
- "Get Started" CTA

### Step 2: Create or Join Band
- Primary action: Create Band
- Secondary action: Join with Code
- Explanation: "Bands let you share songs with your group"

### Step 3: Add First Song
- Guided tutorial on song creation
- Highlight key fields (Title, Artist, BPM, Key)
- Option to skip for experienced users

---

## Implementation Details

### New Files to Create

1. `/lib/screens/onboarding/welcome_screen.dart`
2. `/lib/screens/onboarding/band_setup_screen.dart`
3. `/lib/screens/onboarding/first_song_tutorial.dart`
4. `/lib/providers/onboarding_provider.dart`

### Files to Modify

1. `/lib/main.dart` - Add onboarding route logic
2. `/lib/screens/home_screen.dart` - Check onboarding status

### Data Model

```dart
// In Firestore: users/{userId}/onboarding
{
  completed: boolean,
  completedAt: timestamp,
  currentStep: number
}
```

---

## User Flow

```
First Login
    ↓
Welcome Screen
    ↓
Band Setup (Create or Join)
    ↓
First Song Tutorial
    ↓
Home Screen (with data)
```

---

## User Impact

**Before:**
- Confusing first experience
- High drop-off rate
- Users don't understand value

**After:**
- Clear path to value
- Reduced time-to-first-action
- Better user retention

---

## Success Metrics

- Increased Day 1 retention
- Reduced time to create first band
- Increased song creation rate
- Improved onboarding completion rate

---

## Dependencies

- Existing band creation screens
- Existing song creation screens
- Firestore for storing onboarding state

---

## Risks

- **Skipping:** Users might skip onboarding and still be confused
  - **Mitigation:** Add contextual help for users who skip
- **Length:** Onboarding might feel too long
  - **Mitigation:** Add progress indicator; allow skip on each step
- **Maintenance:** Onboarding needs updates as features change
  - **Mitigation:** Keep onboarding simple; link to help docs for details

---

## Alternative Approaches

| Approach | Pros | Cons |
|----------|------|------|
| **Full guided onboarding (proposed)** | Comprehensive, high impact | High effort |
| **Tooltips on first visit** | Lower effort | Less engaging |
| **Empty state guidance only** | Minimal effort | Easy to miss |
| **Video tutorial** | Engaging | Production effort |

**Recommendation:** Start with empty state guidance (quick win), then implement full onboarding.

---

## Approval

- [ ] MrUXUIDesigner Review
- [ ] MrStupidUser Approval
- [ ] Technical Feasibility Confirmed

---

**Created:** 2026-02-22  
**Last Updated:** 2026-02-22
