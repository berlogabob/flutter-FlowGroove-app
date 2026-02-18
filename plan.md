# RepSync MVP - Detailed Development Plan

## Overview
- **App Name**: RepSync
- **Purpose**: Band repertoire management with collaborative setlists
- **Platform**: Web-first (Flutter), then Android
- **Language**: English
- **Timeline**: 4 days (MVP) + 2 weeks (Polish)

---

## Phase 1: Days 1-2 (Core Infrastructure)

### 1.1 Project Setup & Theme
- [ ] **1.1.1** Configure app theme using color palette:
  - Primary: `#96B3D9` (color1) - headers, buttons
  - Secondary: `#7EBFB3` (color5) - accents, icons
  - Background Dark: `#0B2624` (color4) - dark mode bg
  - Surface: `#D5E7F2` (color2) - light mode surface
  - Highlight: `#C9EBF2` (color3) - selections, focus
- [ ] **1.1.2** Add Riverpod to pubspec.yaml
- [ ] **1.1.3** Add Hive to pubspec.yaml
- [ ] **1.1.4** Create theme configuration in lib/theme/

### 1.2 Authentication (Firebase Auth)
- [ ] **1.2.1** Create AuthController with Riverpod
- [ ] **1.2.2** Implement email/password registration
- [ ] **1.2.3** Implement email/password login
- [ ] **1.2.4** Add Google Sign-In (optional for MVP)
- [ ] **1.2.5** Create AuthGuard - redirect to login if not authenticated
- [ ] **1.2.6** Create persistent session handling

### 1.3 Data Models
- [ ] **1.3.1** Create Song model:
  ```dart
  class Song {
    String id;
    String title;
    String artist;
    String? originalKey;      // e.g., "Am"
    int? originalBPM;
    String? ourKey;
    int? ourBPM;
    List<Link> links;         // youtube, tabs, drums, etc.
    String? notes;             // markdown support
    List<String> tags;        // "ready", "learning", "drums-hard"
    DateTime createdAt;
    DateTime updatedAt;
  }
  ```
- [ ] **1.3.2** Create Link model:
  ```dart
  class Link {
    String type;    // "youtube_original", "youtube_cover", "tabs", "drums", "other"
    String url;
    String? title;
  }
  ```
- [ ] **1.3.3** Create Band model:
  ```dart
  class Band {
    String id;
    String name;
    String? description;
    String createdBy;          // UID
    List<BandMember> members;  // {uid, role: admin/editor/viewer}
    String? inviteCode;
    DateTime createdAt;
  }
  ```
- [ ] **1.3.4** Create Setlist model:
  ```dart
  class Setlist {
    String id;
    String bandId;
    String name;
    String? description;
    String? eventDate;         // concert date
    String? eventLocation;
    List<String> songIds;      // ordered
    int? totalDuration;        // in minutes
    DateTime createdAt;
    DateTime updatedAt;
  }
  ```

---

## Phase 2: Days 2-3 (Songs & Setlists UI)

### 2.1 Songs Feature
- [ ] **2.1.1** Create SongsRepository (Hive + Firestore sync)
- [ ] **2.1.2** Create SongsListScreen:
  - ListView with song cards (title, artist, our BPM, key)
  - Search bar (filter by title/artist)
  - FAB → Add new song
  - Swipe to delete
- [ ] **2.1.3** Create AddEditSongScreen:
  - Form fields: title, artist, keys, BPM
  - Links section: add multiple link chips
  - Notes: multi-line TextField
  - Tags: chip selection
  - "Copy from original" button for key/BPM
- [ ] **2.1.4** Add SongDetailScreen (view mode)

### 2.2 Bands/Groups Feature
- [ ] **2.2.1** Create BandsRepository
- [ ] **2.2.2** Create MyBandsScreen:
  - List of user's bands
  - "Create New Band" button
  - "Join Band" button (enter code)
- [ ] **2.2.3** Create CreateBandScreen:
  - Band name input
  - Generate invite code automatically
- [ ] **2.2.4** Create JoinBandScreen:
  - Input invite code
  - Validate and join
- [ ] **2.2.5** Create BandSettingsScreen (manage members, roles)

### 2.3 Setlists Feature
- [ ] **2.3.1** Create SetlistsRepository
- [ ] **2.3.2** Create SetlistsListScreen:
  - List of setlists (name, song count, date)
  - FAB → Create new
- [ ] **2.3.3** Create SetlistEditScreen:
  - Name, description, date, location fields
  - ReorderableListView for songs (drag-drop)
  - "Add Songs" button → song picker (multi-select)
  - Calculate total duration
- [ ] **2.3.4** Implement song picker modal

---

## Phase 3: Day 4 (MVP Polish)

### 3.1 Navigation
- [ ] **3.1.1** Implement bottom navigation:
  - Tab 1: Songs
  - Tab 2: Setlists
  - Tab 3: Bands
  - Tab 4: Profile/Settings
- [ ] **3.1.2** Add deep linking support

### 3.2 Firebase Sync
- [ ] **3.2.1** Create Firestore service
- [ ] **3.2.2** Sync songs to band collection
- [ ] **3.2.3** Implement real-time listeners (StreamProvider)
- [ ] **3.2.4** Add offline-first with Hive caching

### 3.3 MVP Export
- [ ] **3.3.1** Create PDF export for setlists
- [ ] **3.3.2** Format: setlist name, date, songs with BPM/key/links
- [ ] **3.3.3** Add "Share" button (text format)

---

## Phase 4: Days 5-18 (Polish & Features)

### 4.1 UI/UX Polish
- [ ] **4.1.1** Dark/Light theme toggle
- [ ] **4.1.2** Loading states & skeletons
- [ ] **4.1.3** Error handling with user-friendly messages
- [ ] **4.1.4** Empty states with illustrations

### 4.2 Advanced Features
- [ ] **4.2.1** Onboarding flow for new users
- [ ] **4.2.2** Profile screen (name, email, avatar)
- [ ] **4.2.3** Import from CSV/Google Sheets
- [ ] **4.2.4** Song sorting (by title, artist, BPM, key)

### 4.3 Deployment
- [ ] **4.3.1** Configure Firebase Hosting
- [ ] **4.3.2** Build web version: `flutter build web`
- [ ] **4.3.3** Deploy to Firebase Hosting
- [ ] **4.3.4** Test on multiple browsers

### 4.4 Testing & Bug Fixes
- [ ] **4.4.1** Manual testing on web
- [ ] **4.4.2** Fix critical bugs
- [ ] **4.4.3** Performance optimization

---

## Technical Architecture

```
lib/
├── main.dart
├── app.dart
├── theme/
│   └── app_theme.dart
├── models/
│   ├── song.dart
│   ├── band.dart
│   ├── setlist.dart
│   └── link.dart
├── providers/
│   ├── auth_provider.dart
│   ├── songs_provider.dart
│   ├── bands_provider.dart
│   └── setlists_provider.dart
├── repositories/
│   ├── songs_repository.dart
│   ├── bands_repository.dart
│   └── setlists_repository.dart
├── services/
│   ├── firebase_service.dart
│   ├── hive_service.dart
│   └── pdf_export_service.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── songs/
│   │   ├── songs_list_screen.dart
│   │   ├── song_detail_screen.dart
│   │   └── add_edit_song_screen.dart
│   ├── bands/
│   │   ├── my_bands_screen.dart
│   │   ├── create_band_screen.dart
│   │   ├── join_band_screen.dart
│   │   └── band_settings_screen.dart
│   ├── setlists/
│   │   ├── setlists_list_screen.dart
│   │   └── setlist_edit_screen.dart
│   └── profile/
│       └── profile_screen.dart
└── widgets/
    ├── song_card.dart
    ├── link_chip.dart
    ├── song_picker_modal.dart
    └── custom_app_bar.dart
```

---

## Key Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^4.4.0
  firebase_auth: ^6.1.4
  cloud_firestore: ^5.6.0
  
  # State Management
  flutter_riverpod: ^2.5.1
  
  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # PDF Export
  pdf: ^3.10.8
  printing: ^5.12.0
  
  # UI Utilities
  flutter_markdown: ^0.7.3
  url_launcher: ^6.2.5
  uuid: ^4.3.3
  intl: ^0.19.0
```

---

## Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| color1 | #96B3D9 | Primary - headers, buttons |
| color2 | #D5E7F2 | Surface - light mode background |
| color3 | #C9EBF2 | Highlight - selections, focus |
| color4 | #0B2624 | Background - dark mode |
| color5 | #7EBFB3 | Secondary - accents, icons |

---

## Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Timeline too tight | High | High | Focus MVP only; defer polish |
| Firebase complexity | Medium | Medium | Use Hive for offline-first |
| Auth issues | Medium | High | Test thoroughly, add error handling |
| Web build issues | Low | Medium | Test early, use flutter build web |

---

## Daily Checklist Format

Each day use this template:

```markdown
## Day N: [Date]
### Completed
- [ ] Task 1
- [ ] Task 2

### Blockers
- [ ] Blocker 1

### Tomorrow
- [ ] Task A
- [ ] Task B
```

---

## MVP Goals Checkpoint

By end of Day 4 (Sunday), have:
- [ ] User can register/login
- [ ] User can create/join a band
- [ ] User can add/edit/delete songs
- [ ] User can create setlists with songs
- [ ] App works on web browser
