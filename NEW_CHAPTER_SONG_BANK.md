# New Development Chapter - Song Bank Architecture

**Branch:** `dev-song-bank-architecture`  
**Started:** February 19, 2026 (Session 9)  
**Status:** 🔄 **IN PROGRESS**

---

## Context

Previous development chapter (main/dev01) focused on:
- ✅ Fixing critical bugs (6 bugs fixed)
- ✅ Simplifying architecture (single provider)
- ✅ Deploying to production (web + Android)
- ✅ Band creation and joining working

New chapter focuses on:
- 🔄 Song bank architecture
- 🔄 Sharing songs between users and bands
- 🔄 Band-specific song customizations

---

## Problem Statement

From user's original conversation:

> "user have its own songs bank.
> band have its owns songs bank.
> user can add songs from personal bank to group bank.
> how to solve this"

### Current State

```
Personal Songs:
/users/{userId}/songs/{songId}
- Owned by user
- User can edit/delete
- Private to user

Band Data:
/bands/{bandId}
- Global collection
- Members can view
- Admins can edit
```

### Missing Piece

```
Band Songs:
??? ← Need to implement
- Shared among band members
- Multiple users can contribute
- Band-specific customizations
```

---

## Solution (Documented in SONG_BANK_ARCHITECTURE.md)

### Recommended Approach: **Copy-Based Model**

**Structure:**
```
/users/{userId}/songs/{songId}     ← Personal song
/bands/{bandId}/songs/{songId}     ← Band's copy
```

**Flow:**
1. User creates song in personal bank
2. User selects "Add to Band"
3. Song copied to band's collection
4. Band members can view/edit band's copy
5. Original user credited as contributor

**Benefits:**
- ✅ Simple implementation
- ✅ Uses existing security rules
- ✅ Band owns their copy
- ✅ Original deletion doesn't break band data
- ✅ Independent customization

---

## Implementation Plan

### Phase 1: Model Updates
- [ ] Add `originalOwnerId` field to Song
- [ ] Add `contributedBy` field (user who added to band)
- [ ] Add `isCopy` flag
- [ ] Add `bandId` for filtering

### Phase 2: Firestore Rules
- [ ] Update rules for `/bands/{bandId}/songs/` subcollection
- [ ] Band members can read
- [ ] Band editors/admins can write
- [ ] Original owner attribution

### Phase 3: UI Components
- [ ] "Add to Band" dialog
- [ ] Band songs list screen
- [ ] Song context menu (add to band option)
- [ ] Contributor badge on songs

### Phase 4: Providers
- [ ] `bandSongsProvider` - Watch band's songs
- [ ] `addSongToBand()` method
- [ ] `removeSongFromBand()` method

### Phase 5: Testing
- [ ] Add song to band
- [ ] View band songs
- [ ] Edit band's copy
- [ ] Delete original (verify band copy intact)

---

## Session Log

### Session 9 - 22:30 PST
**Focus:** New Development Chapter Start
- Created `dev-song-bank-architecture` branch
- Read previous conversation context
- Analyzed problem statement

### Session 10 - 22:45 PST
**Focus:** Architecture Analysis
- Created subagent for analysis
- Proposed copy-based solution
- Created `SONG_BANK_ARCHITECTURE.md`

---

## Next Steps

### Immediate (Next Session)
1. Read `SONG_BANK_ARCHITECTURE.md`
2. Implement Phase 1 (Song model updates)
3. Test model changes
4. Log session 11

### Future Sessions
- Phase 2: Firestore rules
- Phase 3: UI components
- Phase 4: Providers
- Phase 5: Testing

---

## Files Reference

| File | Purpose |
|------|---------|
| `SONG_BANK_ARCHITECTURE.md` | Complete solution document |
| `lib/models/song.dart` | Song model (to update) |
| `lib/models/band.dart` | Band model (reference) |
| `lib/providers/data_providers.dart` | Service methods |
| `firestore.rules` | Security rules (to update) |

---

## Success Criteria

- [ ] User can add personal song to band
- [ ] Band members see song in band list
- [ ] Band can customize their copy
- [ ] Original owner credited
- [ ] Deleting original doesn't break band copy
- [ ] All security rules working

---

**Branch:** `dev-song-bank-architecture`  
**Last Updated:** 2026-02-19T22:45:00Z  
**Status:** 🔄 **READY FOR PHASE 1 IMPLEMENTATION**
