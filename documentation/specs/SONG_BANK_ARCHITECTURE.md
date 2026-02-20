# Song Bank Architecture Analysis & Solution

**Date:** February 19, 2026
**Author:** Architecture Analysis

---

## Executive Summary

This document analyzes the current song bank architecture in RepSync and proposes a solution for enabling users to share songs from their personal song bank with their band's shared song bank.

---

## 1. Current Architecture Analysis

### 1.1 Data Model Overview

#### Song Model (`lib/models/song.dart`)

```dart
class Song {
  final String id;
  final String title;
  final String artist;
  final String? originalKey;
  final int? originalBPM;
  final String? ourKey;
  final int? ourBPM;
  final List<Link> links;
  final String? notes;
  final List<String> tags;
  final String? bandId;        // Currently unused for ownership
  final String? spotifyUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Key Observation:** The `bandId` field exists but is currently unused for ownership purposes.

#### Band Model (`lib/models/band.dart`)

```dart
class Band {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final List<BandMember> members;
  final List<String> memberUids;   // For efficient rules checking
  final List<String> adminUids;    // For efficient rules checking
  final String? inviteCode;
  final DateTime createdAt;
}
```

### 1.2 Current Firestore Structure

```
/users/{userId}/
  ├── songs/{songId}           # Personal songs (owner-only access)
  ├── bands/{bandId}           # References to global bands
  └── setlists/{setlistId}     # Personal setlists

/bands/{bandId}                # Global band collection (shared)
  └── (band document with members)
```

### 1.3 Current Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    CURRENT ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  User Personal Songs:                                        │
│  /users/{userId}/songs/{songId}                             │
│  - Owned by individual user                                 │
│  - Only user can read/write                                 │
│  - No sharing mechanism                                     │
│                                                              │
│  Band Data:                                                  │
│  /bands/{bandId} (global collection)                        │
│  - Shared among all band members                            │
│  - Members can read, admins can write                       │
│  - NO song storage currently                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 1.4 Security Rules (`firestore.rules`)

```javascript
// Songs subcollection - only owner can read/write
match /songs/{songId} {
  allow read, write: if isAuthenticated() && isOwner(userId);
}

// Global Bands Collection
match /bands/{bandId} {
  allow read: if isAuthenticated();
  allow update: if isAuthenticated() && (
    isGlobalBandAdmin(bandId) ||
    isSelfJoinOnly(bandId)
  );
}
```

---

## 2. Problem Statement

**User Requirement:**
- User has a **personal song bank** with their own songs
- Band has a **shared song bank** for collaborative song management
- User wants to **add songs from personal bank to band bank**
- Multiple band members should be able to contribute songs

**Current Gap:**
- No mechanism exists to share songs between users
- Songs are siloed in individual user collections
- Band collection has no song storage capability

---

## 3. Solution Options Analysis

### Option A: Song References (Link-Based)

**Concept:** Songs remain in the owner's collection; bands store references to song IDs.

```
/users/{userId}/songs/{songId}          # Original song stays here
/bands/{bandId}/songRefs/{songRefId}    # Reference document
  {
    "songId": "original-song-id",
    "ownerId": "user-id",
    "addedBy": "user-id",
    "addedAt": "timestamp"
  }
```

**Pros:**
- Single source of truth (no duplication)
- Owner maintains control over original song
- Changes propagate to all bands automatically
- Storage efficient

**Cons:**
- Complex security rules (need cross-collection access)
- Owner deleting song breaks band references
- Band-specific customizations not possible
- Read performance: need to fetch from multiple locations

**Firestore Structure:**
```
/bands/{bandId}/songRefs/{songRefId}
  - songId: reference to original
  - ownerId: original owner
  - addedBy: who added to band
  - customNotes: band-specific notes (optional)
  - customKey: band's version key (optional)
  - customBPM: band's version BPM (optional)
```

---

### Option B: Shared Collection (Copy-Based)

**Concept:** Songs are copied to band collection; band owns the copy.

```
/users/{userId}/songs/{songId}          # Original personal song
/bands/{bandId}/songs/{songId}          # Band's copy
  {
    ...song data...,
    "originalOwnerId": "user-id",
    "contributedBy": "user-id",
    "contributedAt": "timestamp"
  }
```

**Pros:**
- Simple security rules (band collection follows band permissions)
- Band has full control over their copy
- Band-specific customizations easy
- Read performance: all data in one place
- Original deletion doesn't affect band

**Cons:**
- Data duplication
- Multiple versions of same song possible
- Need to track original contributor
- Sync changes from original (if desired)

**Firestore Structure:**
```
/bands/{bandId}/songs/{songId}
  - All song fields
  - originalOwnerId: who owned the original
  - contributedBy: who added to band
  - contributedAt: when added
  - isCopy: true
  - originalSongId: reference to original (optional)
```

---

### Option C: Hybrid Approach (Ownership + Sharing)

**Concept:** Songs have explicit ownership and sharing fields; can exist in both collections.

```
/users/{userId}/songs/{songId}
  {
    ...song data...,
    "ownerId": "user-id",
    "sharedWithBands": ["band-id-1", "band-id-2"],
    "visibility": "private" | "bands" | "public"
  }

/bands/{bandId}/sharedSongs/{songId}    # Reference with permissions
  {
    "songId": "original-song-id",
    "ownerId": "user-id",
    "permissions": ["read", "edit", "delete"]
  }
```

**Pros:**
- Flexible sharing model
- Owner maintains control
- Can grant different permission levels
- Future-proof for public sharing

**Cons:**
- Most complex implementation
- Complex security rules
- Requires significant model changes

---

## 4. Recommended Solution: Option B (Copy-Based)

### 4.1 Rationale

After analyzing all options, **Option B (Copy-Based)** is recommended for the following reasons:

1. **Simplicity:** Easiest to implement with current architecture
2. **Security:** Leverages existing band security rules
3. **User Experience:** Clear ownership boundaries (personal vs. band)
4. **Performance:** All band songs in one collection
5. **Autonomy:** Bands can customize songs without affecting originals
6. **Resilience:** Original deletion doesn't break band data

### 4.2 Data Model Changes

#### Song Model Updates

Add fields to track origin and sharing:

```dart
class Song {
  // ... existing fields ...
  final String? bandId;              // If song belongs to a band
  final String? originalOwnerId;     // If copied, who owned original
  final String? contributedBy;       // Who added to band
  final DateTime? contributedAt;     // When added to band
  final bool isCopy;                 // True if this is a band copy
  final String? originalSongId;      // Reference to original (if copy)
}
```

### 4.3 New Firestore Structure

```
/users/{userId}/
  ├── songs/{songId}                 # Personal songs (unchanged)
  │     {
  │       "id": "...",
  │       "title": "...",
  │       "bandId": null,            // null = personal song
  │       "originalOwnerId": null,
  │       "isCopy": false
  │     }
  │
  └── bands/{bandId}                 # User's band references

/bands/{bandId}/                     # NEW: Band subcollections
  ├── songs/{songId}                 # Band's shared songs
  │     {
  │       "id": "...",
  │       "title": "...",
  │       "bandId": "band-id",
  │       "originalOwnerId": "user-id",
  │       "contributedBy": "user-id",
  │       "contributedAt": "timestamp",
  │       "isCopy": true,
  │       "originalSongId": "original-song-id"
  │     }
  │
  └── setlists/{setlistId}           # Band setlists (future)
```

### 4.4 Security Rules Updates

```javascript
// Add band songs subcollection rules
match /bands/{bandId} {
  // Existing band rules...

  // Band songs - band members can read, editors/admins can write
  match /songs/{songId} {
    allow read: if isAuthenticated() && isGlobalBandMember(bandId);
    allow create, update: if isAuthenticated() && (
      isGlobalBandMember(bandId) &&
      request.resource.data.bandId == bandId
    );
    allow delete: if isAuthenticated() && isGlobalBandAdmin(bandId);
  }
}
```

---

## 5. UI/UX Flow

### 5.1 Adding Song to Band

```
┌─────────────────────────────────────────────────────────────┐
│                    USER FLOW                                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. User views personal song list                           │
│  2. Long-press or tap menu on song                          │
│  3. Select "Add to Band"                                    │
│  4. Choose band from dropdown/modal                         │
│  5. Confirm addition                                        │
│  6. Song copied to band collection                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Screen Mockups

#### Song List Screen - Enhanced

```
┌─────────────────────────────────────┐
│  Songs                        [+]   │
├─────────────────────────────────────┤
│  [Search songs...]                  │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🎵 Wonderwall               │   │
│  │    Oasis                    │   │
│  │    [120 BPM] [Em]  [⋮]     │   │
│  └─────────────────────────────┘   │
│         └─ Tap for menu:           │
│            • Edit                  │
│            • Add to Band ← NEW     │
│            • Delete                │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🎵 Creep                    │   │
│  │    Radiohead                │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

#### Add to Band Modal

```
┌─────────────────────────────────────┐
│  Add to Band                        │
├─────────────────────────────────────┤
│  Song: Wonderwall - Oasis           │
│                                     │
│  Select Band:                       │
│  ┌─────────────────────────────┐   │
│  │ ▼ The Cover Band           │   │
│  └─────────────────────────────┘   │
│                                     │
│  Your Bands:                        │
│  ○ The Cover Band (Admin)          │
│  ○ Weekend Warriors (Member)       │
│                                     │
│  [Cancel]          [Add to Band]   │
└─────────────────────────────────────┘
```

### 5.3 Band Song List Screen (New)

```
┌─────────────────────────────────────┐
│  The Cover Band - Songs       [+]   │
├─────────────────────────────────────┤
│  Members: You, Alice, Bob           │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🎵 Wonderwall               │   │
│  │    Oasis                    │   │
│  │    Added by: You            │   │
│  │    [120 BPM] [Em]  [⋮]     │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🎵 Creep                    │   │
│  │    Radiohead                │   │
│  │    Added by: Alice          │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## 6. Implementation Plan

### Phase 1: Data Model Updates (Week 1)

#### 6.1.1 Update Song Model

**File:** `lib/models/song.dart`

```dart
class Song {
  // ... existing fields ...
  final String? bandId;
  final String? originalOwnerId;
  final String? contributedBy;
  final DateTime? contributedAt;
  final bool isCopy;
  final String? originalSongId;

  Song({
    // ... existing params ...
    this.bandId,
    this.originalOwnerId,
    this.contributedBy,
    this.contributedAt,
    this.isCopy = false,
    this.originalSongId,
  });

  // Update copyWith, toJson, fromJson methods
}
```

#### 6.1.2 Update Firestore Service

**File:** `lib/providers/data_providers.dart`

```dart
class FirestoreService {
  // ... existing methods ...

  // Copy personal song to band
  Future<void> addSongToBand(String songId, String bandId, String userId) async {
    // 1. Fetch original song
    final originalDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('songs')
        .doc(songId)
        .get();

    if (!originalDoc.exists) throw Exception('Song not found');

    final originalSong = Song.fromJson(originalDoc.data()!);

    // 2. Create band song copy
    final bandSong = Song(
      id: const Uuid().v4(),  // New ID for band copy
      title: originalSong.title,
      artist: originalSong.artist,
      originalKey: originalSong.originalKey,
      originalBPM: originalSong.originalBPM,
      ourKey: originalSong.ourKey,
      ourBPM: originalSong.ourBPM,
      links: originalSong.links,
      notes: originalSong.notes,
      tags: originalSong.tags,
      bandId: bandId,
      spotifyUrl: originalSong.spotifyUrl,
      originalOwnerId: userId,
      contributedBy: userId,
      contributedAt: DateTime.now(),
      isCopy: true,
      originalSongId: songId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 3. Save to band collection
    await _firestore
        .collection('bands')
        .doc(bandId)
        .collection('songs')
        .doc(bandSong.id)
        .set(bandSong.toJson());
  }

  // Watch band songs
  Stream<List<Song>> watchBandSongs(String bandId) {
    return _firestore
        .collection('bands')
        .doc(bandId)
        .collection('songs')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Song.fromJson(doc.data())).toList());
  }

  // Delete band song
  Future<void> deleteBandSong(String bandId, String songId) async {
    await _firestore
        .collection('bands')
        .doc(bandId)
        .collection('songs')
        .doc(songId)
        .delete();
  }
}
```

### Phase 2: Security Rules (Week 1)

#### 6.2.1 Update Firestore Rules

**File:** `firestore.rules`

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ... existing helper functions ...

    match /bands/{bandId} {
      // Existing band rules...
      allow read: if isAuthenticated();
      allow update: if isAuthenticated() && (
        isGlobalBandAdmin(bandId) ||
        isSelfJoinOnly(bandId)
      );
      allow delete: if isAuthenticated() && isGlobalBandAdmin(bandId);

      // NEW: Band songs subcollection
      match /songs/{songId} {
        allow read: if isAuthenticated() && isGlobalBandMember(bandId);

        allow create: if isAuthenticated() &&
          isGlobalBandMember(bandId) &&
          request.resource.data.bandId == bandId;

        allow update: if isAuthenticated() &&
          isGlobalBandMember(bandId) &&
          resource.data.bandId == bandId;

        allow delete: if isAuthenticated() &&
          isGlobalBandAdmin(bandId);
      }

      // Future: Band setlists
      match /setlists/{setlistId} {
        allow read: if isAuthenticated() && isGlobalBandMember(bandId);
        allow write: if isAuthenticated() && isGlobalBandAdmin(bandId);
      }
    }

    // ... rest of existing rules ...
  }
}
```

### Phase 3: UI Components (Week 2)

#### 6.3.1 Add Song Context Menu

**File:** `lib/screens/songs/songs_list_screen.dart`

Add "Add to Band" option to song card menu.

#### 6.3.2 Create Add to Band Dialog

**File:** `lib/screens/songs/components/add_to_band_dialog.dart` (NEW)

```dart
class AddToBandDialog extends ConsumerStatefulWidget {
  final Song song;

  const AddToBandDialog({required this.song});

  @override
  ConsumerState<AddToBandDialog> createState() => _AddToBandDialogState();
}

class _AddToBandDialogState extends ConsumerState<AddToBandDialog> {
  Band? _selectedBand;

  @override
  Widget build(BuildContext context) {
    final bandsAsync = ref.watch(bandsProvider);

    return AlertDialog(
      title: const Text('Add to Band'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add "${widget.song.title}" to which band?'),
          const SizedBox(height: 16),
          bandsAsync.when(
            data: (bands) => DropdownButton<Band>(
              value: _selectedBand,
              hint: const Text('Select band'),
              items: bands.map((band) => DropdownMenuItem(
                value: band,
                child: Text(band.name),
              )).toList(),
              onChanged: (band) => setState(() => _selectedBand = band),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedBand != null ? _addToBand : null,
          child: const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _addToBand() async {
    if (_selectedBand == null) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await ref.read(firestoreProvider).addSongToBand(
        widget.song.id,
        _selectedBand!.id,
        user.uid,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to ${_selectedBand!.name}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
```

#### 6.3.3 Create Band Songs Screen

**File:** `lib/screens/bands/band_songs_screen.dart` (NEW)

```dart
class BandSongsScreen extends ConsumerWidget {
  final Band band;

  const BandSongsScreen({required this.band});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(bandSongsProvider(band.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${band.name} - Songs'),
      ),
      body: songsAsync.when(
        data: (songs) => ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return ListTile(
              title: Text(song.title),
              subtitle: Text('Added by: ${song.contributedBy}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (song.ourKey != null) Text(song.ourKey!),
                  if (song.ourBPM != null) Text('${song.ourBPM} BPM'),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSongOptions(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddSongOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add new song'),
              onTap: () => Navigator.pushNamed(context, '/add-song'),
            ),
            ListTile(
              leading: const Icon(Icons.library_music),
              title: const Text('Add from personal library'),
              onTap: () {
                Navigator.pop(context);
                _showPersonalSongsPicker(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

### Phase 4: Providers (Week 2)

#### 6.4.1 Add Band Songs Provider

**File:** `lib/providers/data_providers.dart`

```dart
// Provider for watching songs in a specific band
final bandSongsProvider = StreamProvider.family<List<Song>, String>((ref, bandId) {
  return ref.watch(firestoreProvider).watchBandSongs(bandId);
});
```

### Phase 5: Testing (Week 3)

- Unit tests for new Song model fields
- Integration tests for addSongToBand flow
- Security rules testing with Firestore emulator
- UI tests for new dialogs and screens

---

## 7. Code Examples

### 7.1 Complete Song Model with New Fields

```dart
class Song {
  final String id;
  final String title;
  final String artist;
  final String? originalKey;
  final int? originalBPM;
  final String? ourKey;
  final int? ourBPM;
  final List<Link> links;
  final String? notes;
  final List<String> tags;
  final String? bandId;
  final String? spotifyUrl;

  // NEW: Sharing fields
  final String? originalOwnerId;
  final String? contributedBy;
  final DateTime? contributedAt;
  final bool isCopy;
  final String? originalSongId;

  final DateTime createdAt;
  final DateTime updatedAt;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.originalKey,
    this.originalBPM,
    this.ourKey,
    this.ourBPM,
    this.links = const [],
    this.notes,
    this.tags = const [],
    this.bandId,
    this.spotifyUrl,
    this.originalOwnerId,
    this.contributedBy,
    this.contributedAt,
    this.isCopy = false,
    this.originalSongId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Check if this song is owned by a specific user
  bool isOwnedBy(String userId) => originalOwnerId == userId || (originalOwnerId == null && bandId == null);

  // Check if this song belongs to a band
  bool get isBandSong => bandId != null;

  // Check if this is a personal song
  bool get isPersonalSong => bandId == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'originalKey': originalKey,
    'originalBPM': originalBPM,
    'ourKey': ourKey,
    'ourBPM': ourBPM,
    'links': links.map((l) => l.toJson()).toList(),
    'notes': notes,
    'tags': tags,
    'bandId': bandId,
    'spotifyUrl': spotifyUrl,
    'originalOwnerId': originalOwnerId,
    'contributedBy': contributedBy,
    'contributedAt': contributedAt?.toIso8601String(),
    'isCopy': isCopy,
    'originalSongId': originalSongId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    artist: json['artist'] ?? '',
    originalKey: json['originalKey'],
    originalBPM: json['originalBPM'],
    ourKey: json['ourKey'],
    ourBPM: json['ourBPM'],
    links: (json['links'] as List<dynamic>?)
        ?.map((l) => Link.fromJson(l as Map<String, dynamic>))
        .toList() ?? [],
    notes: json['notes'],
    tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    bandId: json['bandId'],
    spotifyUrl: json['spotifyUrl'],
    originalOwnerId: json['originalOwnerId'],
    contributedBy: json['contributedBy'],
    contributedAt: json['contributedAt'] != null
        ? DateTime.parse(json['contributedAt'])
        : null,
    isCopy: json['isCopy'] ?? false,
    originalSongId: json['originalSongId'],
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'])
        : DateTime.now(),
  );
}
```

### 7.2 Firestore Service Extension

```dart
class FirestoreService {
  // ... existing methods ...

  /// Adds a personal song to a band's shared collection.
  ///
  /// Creates a copy of the song in the band's collection with
  /// attribution to the original owner.
  Future<void> addSongToBand(String songId, String bandId, String userId) async {
    // Fetch original song from user's collection
    final originalDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('songs')
        .doc(songId)
        .get();

    if (!originalDoc.exists) {
      throw Exception('Song not found');
    }

    final originalData = originalDoc.data()!;
    originalData['id'] = originalDoc.id;
    final originalSong = Song.fromJson(originalData);

    // Create band song copy
    final bandSong = Song(
      id: const Uuid().v4(),
      title: originalSong.title,
      artist: originalSong.artist,
      originalKey: originalSong.originalKey,
      originalBPM: originalSong.originalBPM,
      ourKey: originalSong.ourKey,
      ourBPM: originalSong.ourBPM,
      links: originalSong.links,
      notes: originalSong.notes,
      tags: originalSong.tags,
      bandId: bandId,
      spotifyUrl: originalSong.spotifyUrl,
      originalOwnerId: userId,
      contributedBy: userId,
      contributedAt: DateTime.now(),
      isCopy: true,
      originalSongId: songId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save to band collection
    await _firestore
        .collection('bands')
        .doc(bandId)
        .collection('songs')
        .doc(bandSong.id)
        .set(bandSong.toJson());
  }

  /// Watches songs in a band's shared collection.
  Stream<List<Song>> watchBandSongs(String bandId) {
    return _firestore
        .collection('bands')
        .doc(bandId)
        .collection('songs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Song.fromJson(doc.data())).toList());
  }

  /// Deletes a song from a band's collection.
  Future<void> deleteBandSong(String bandId, String songId) async {
    await _firestore
        .collection('bands')
        .doc(bandId)
        .collection('songs')
        .doc(songId)
        .delete();
  }

  /// Gets all songs for a user (personal + band contributions).
  Stream<List<Song>> watchAllUserSongs(String userId) {
    // This would require a collection group query or merging streams
    // For now, keep personal and band songs separate
    return watchSongs(userId);
  }
}
```

---

## 8. Migration Path

### 8.1 Backward Compatibility

- Existing songs without new fields will work unchanged
- Default values ensure no breaking changes
- `bandId == null` indicates personal song

### 8.2 Data Migration (Optional)

If desired, existing songs with `bandId` set can be migrated:

```dart
// Migration script (run once)
Future<void> migrateExistingBandSongs() async {
  // Find all songs with bandId set
  // Create copies in band collections
  // Update original songs to reference band copies
}
```

---

## 9. Future Enhancements

### 9.1 Phase 2 Features

1. **Song Sync:** Option to sync changes from original to band copies
2. **Version History:** Track changes to band songs
3. **Song Requests:** Band members can request songs from each other
4. **Setlist Integration:** Use band songs in band setlists
5. **Practice Notes:** Band-specific practice notes on songs

### 9.2 Advanced Sharing

1. **Read-Only Sharing:** Share songs without allowing edits
2. **Temporary Sharing:** Time-limited song access
3. **Public Song Library:** Community song database

---

## 10. Conclusion

The **Copy-Based (Option B)** approach provides the best balance of:

- **Simplicity:** Minimal changes to existing architecture
- **Security:** Leverages existing band permission model
- **User Experience:** Clear separation between personal and band content
- **Flexibility:** Bands can customize their copies
- **Performance:** All band data in one location

Implementation can be completed in 2-3 weeks with the phased approach outlined above.

---

## Appendix A: File Change Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/models/song.dart` | Modify | Add sharing fields |
| `lib/providers/data_providers.dart` | Modify | Add band song methods |
| `firestore.rules` | Modify | Add band songs rules |
| `lib/screens/songs/songs_list_screen.dart` | Modify | Add "Add to Band" menu |
| `lib/screens/songs/components/add_to_band_dialog.dart` | Create | New dialog component |
| `lib/screens/bands/band_songs_screen.dart` | Create | New band songs screen |
| `lib/providers/data_providers.dart` | Modify | Add band songs provider |

---

## Appendix B: Glossary

- **Personal Song:** Song owned by individual user, stored in `/users/{userId}/songs/`
- **Band Song:** Song in band's shared collection, stored in `/bands/{bandId}/songs/`
- **Copy:** Band version of a song, derived from personal song
- **Original Owner:** User who owns the personal song
- **Contributor:** User who added song to band
