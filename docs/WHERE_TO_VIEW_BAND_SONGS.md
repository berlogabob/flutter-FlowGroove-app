# 📍 Where to View Band Songs

**Question:** Where in the app can I see band songs?

**Answer:** There are **2 ways** to view band songs!

---

## Method 1: From Songs Screen (Recommended)

### Steps:
1. **Tap "Songs" tab** (bottom navigation)
2. **Tap the "Groups" icon** (👥) in the top-right corner of the AppBar
3. **Select your band** from the list
4. **View band songs!**

### Screenshot Location:
```
Songs Screen → Top Right → Groups Icon → Select Band → Band Songs Screen
```

### What You'll See:
- All songs shared to that band
- Filter chips by contributor
- Search functionality
- Edit/Delete buttons (if you're admin/editor)
- Attribution badges showing who contributed each song

---

## Method 2: From Add to Band Dialog

### Steps:
1. **Long-press any song** OR **tap "Add to Band" button**
2. **In the dialog**, you'll see your bands listed
3. **Tap a band name**
4. **Song is added** and you can choose to view band songs

---

## Band Songs Screen Features

### At the Top:
- **Band name** in the title
- **Filter chips** - Filter by who contributed songs
- **Search bar** - Search songs in the band

### Song List Shows:
- ✅ Song title and artist
- ✅ Original key and BPM
- ✅ Our key and BPM (if different)
- ✅ **Attribution badge** showing:
  - Original owner (who created the song)
  - Contributor (who added to band)
  - "Copy" indicator (if it's a band copy)

### Actions Available:
- **Play on Spotify** - Opens song on Spotify
- **Edit** - Edit song details (admin/editor only)
- **Remove from Band** - Remove song from band (admin only)

---

## Navigation Path

```
App Launch
    ↓
Bottom Navigation
    ↓
[Songs] Tab
    ↓
Look at Top-Right Corner
    ↓
[👥 Groups Icon] Button
    ↓
Select Your Band
    ↓
Band Songs Screen! ✅
```

---

## Why Can't I See Band Songs?

### Possible Reasons:

1. **No songs added yet**
   - Add songs using long-press or "Add to Band" button

2. **Not in a band**
   - Join or create a band first
   - Go to "Bands" tab → Create/Join band

3. **Wrong band selected**
   - Make sure you're viewing the correct band

4. **Permission issue**
   - You need to be a band member to view songs
   - Check your role in the band (admin/editor/viewer)

---

## Quick Access Tips

### From Home Screen:
- No direct access - use Songs tab method

### From Bands Screen:
- View your bands list
- But NOT band songs directly
- Use Songs tab → Groups icon

### Shortcut:
- Add band songs to favorites (coming soon)
- Quick access from Home (coming soon)

---

## Related Features

### Also Available:
- **Add to Band** - Long-press song or use button
- **Filter by Contributor** - See who added what
- **Search Band Songs** - Find songs quickly
- **Edit Band Songs** - If you have permission
- **Remove from Band** - Admins can remove

---

## Technical Details

### Data Location:
```
Firestore → bands → {bandId} → songs → {songId}
```

### Provider:
```dart
ref.watch(bandSongsProvider(bandId))
```

### Screen:
```
lib/screens/bands/band_songs_screen.dart
```

---

**Status:** ✅ **FEATURE WORKING**  
**Location:** Songs tab → Groups icon → Select band  
**Alternative:** Long-press song → Add to band
