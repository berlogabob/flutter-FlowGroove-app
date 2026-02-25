# RepSync - PROJECT DOCUMENTATION

**Version:** 0.11.2+51 | **Last Updated:** 2026-02-24 | **Status:** Production Ready

---

## TABLE OF CONTENTS

1. [Project Overview](#project-overview)
2. [Features](#features)
3. [Tech Stack](#tech-stack)
4. [Architecture](#architecture)
5. [Brand & Design](#brand--design)
6. [Setup & Configuration](#setup--configuration)
7. [Build & Deployment](#build--deployment)
8. [Development Workflow](#development-workflow)
9. [Testing](#testing)
10. [Changelog](#changelog)

---

## PROJECT OVERVIEW

**RepSync** (Flutter RepSync App) — Application for managing cover band repertoire, setlists, and shared song databases.

### Purpose
- Create and maintain band song database
- Manage setlists for gigs and rehearsals
- Share repertoire with band members in real-time
- Export setlists to PDF for printing
- Use metronome during rehearsals

### Target Audience
- Cover bands worldwide
- Drummers (primary focus)
- Guitarists/vocalists/bassists
- Hobby and professional bands

### Quick Links
- **Web App:** https://berlogabob.github.io/flutter-repsync-app/
- **GitHub:** https://github.com/berlogabob/flutter-repsync-app
- **Issue Tracker:** https://github.com/berlogabob/flutter-repsync-app/issues

---

## FEATURES

### Core Functionality

#### Authentication & User Management
- Email + password authentication
- Google Sign-In via Firebase
- Profile management with photo upload
- Password reset functionality

#### Band Management
- Create bands with unique 6-character invite codes
- Join bands via invite code
- Role-based access (Viewer, Editor, Admin)
- Multi-band support (one user in several bands)
- Member management with role assignment

#### Song Database
- Comprehensive song fields: title, artist, keys (original/our), BPM (original/our)
- Links attachment (YouTube, tabs, drum lessons)
- Markdown notes support
- Tag-based filtering
- Spotify integration for automatic BPM & key detection
- Search by title, artist, tags, notes
- Filter by key, BPM range, tags, date

#### Setlists
- Create setlists for gigs and rehearsals
- Drag-and-drop song reordering (ReorderableListView)
- Automatic total duration calculation
- Event date and location tracking
- **PDF export** with professional formatting
- Text/Markdown export for chat sharing
- Direct print functionality

#### Metronome
- BPM range: 40-220
- Time signatures: 2/4 to 12/8
- Custom accent patterns (e.g., "ABBB" for 4/4)
- Wave types: sine, square, triangle, sawtooth
- Frequency customization (accent: 1600Hz, beat: 800Hz default)
- Tap BPM calculation
- Subdivisions: 8th notes, triplets, 16th notes
- Preset saving/loading
- Integration with song BPM

### Offline Support
- **Offline-first architecture** with Hive local storage
- Full offline access to songs and setlists
- Automatic sync when connectivity restored
- Offline indicator in UI
- Connectivity monitoring

---

## TECH STACK

### Core Technologies
| Component | Technology | Version |
|-----------|------------|---------|
| Framework | Flutter | 3.19+ |
| Language | Dart | 3.3+ |
| State Management | Riverpod | 3.x |
| Backend | Firebase | Latest |

### Platforms
- **Primary:** Web (GitHub Pages)
- **Secondary:** Android (APK + AAB)
- **Future:** iOS

### Dependencies

#### Firebase
- `firebase_core: ^4.4.0`
- `firebase_auth: ^6.1.4`
- `cloud_firestore: ^6.1.2`

#### State & Data
- `flutter_riverpod: ^3.2.1`
- `hive: ^2.2.3`
- `hive_flutter: ^1.1.0`
- `connectivity_plus: ^6.1.3`

#### Navigation
- `go_router: ^16.2.0`

#### Audio
- `audioplayers: ^6.0.0` (mobile)
- Web Audio API (web)

#### PDF & Export
- `pdf: ^3.10.0`
- `printing: ^5.11.0`

#### UI Components
- `google_fonts: ^6.1.0`
- `flutter_svg: ^2.0.9`

#### API Integrations
- Spotify API (BPM, key detection)
- MusicBrainz (metadata)

---

## ARCHITECTURE

### Project Structure

```
lib/
├── main.dart                    # Entry point, initialization
├── firebase_options.dart        # Firebase configuration
├── router/
│   └── app_router.dart          # go_router configuration
├── models/
│   ├── song.dart               # Song model
│   ├── band.dart               # Band + BandMember models
│   ├── setlist.dart            # Setlist model
│   ├── link.dart               # Link model
│   ├── user.dart               # User model
│   ├── metronome_state.dart    # Metronome state
│   ├── subdivision_type.dart   # Subdivision enum
│   └── time_signature.dart     # Time signature model
├── providers/
│   ├── auth_provider.dart      # Authentication providers
│   ├── data_providers.dart     # Firestore providers
│   ├── metronome_provider.dart # Metronome state
│   └── error_provider.dart     # Error handling
├── services/
│   ├── firestore_service.dart  # CRUD operations
│   ├── cache_service.dart      # Hive caching
│   ├── connectivity_service.dart # Connectivity monitoring
│   ├── spotify_service.dart    # Spotify API
│   ├── musicbrainz_service.dart # MusicBrainz API
│   ├── pdf_service.dart        # PDF generation
│   ├── audio_engine.dart       # Audio interface
│   ├── audio_engine_mobile.dart # Mobile audio (audioplayers)
│   └── audio_engine_web.dart   # Web audio (Web Audio API)
├── screens/
│   ├── main_shell.dart         # Bottom navigation
│   ├── home_screen.dart        # Dashboard
│   ├── profile_screen.dart     # Profile/settings
│   ├── login_screen.dart       # Login
│   ├── auth/
│   │   └── register_screen.dart
│   ├── songs/
│   │   ├── songs_list_screen.dart
│   │   ├── add_song_screen.dart
│   │   └── components/
│   ├── bands/
│   │   ├── my_bands_screen.dart
│   │   ├── create_band_screen.dart
│   │   └── join_band_screen.dart
│   └── setlists/
│       ├── setlists_list_screen.dart
│       └── create_setlist_screen.dart
├── widgets/
│   ├── song_card.dart          # Song card
│   ├── band_card.dart          # Band card
│   ├── attribution_badge.dart  # Authorship badge
│   ├── time_signature_dropdown.dart
│   ├── metronome_widget.dart   # Metronome UI
│   ├── tap_bpm_widget.dart     # Tap BPM
│   ├── song_bpm_badge.dart     # Song BPM badge
│   ├── offline_indicator.dart  # Offline status
│   └── metronome/              # Refactored metronome widgets
└── theme/
    └── app_theme.dart          # Theme configuration
```

### Data Model

#### Firestore Collections

```
users/{userId}
├── uid, email, displayName, photoURL, createdAt
├── songs/{songId} - User's personal songs
└── setlists/{setlistId} - User's setlists

bands/{bandId}
├── id, name, description, createdBy
├── members: [{uid, role, joinedAt}]
├── memberUids, adminUids, editorUids
├── inviteCode (6 char)
├── songs/{songId} - Band songs
└── setlists/{setlistId} - Band setlists
```

#### Security Rules

```javascript
// Users can only access their own data
users/{userId}/songs/{songId} - Owner read/write only
users/{userId}/setlists/{setlistId} - Owner read/write only

// Band members have read access, editors/admins have write
bands/{bandId} - Members read, owner writes
bands/{bandId}/songs/{songId} - Members read, editors/admins write
```

### State Management (Riverpod)

```dart
// Authentication
final currentUserProvider = StreamProvider<AppUser?>((ref) {...})
final authNotifierProvider = AutoDisposeNotifierProvider<...>()

// Data
final bandsProvider = StreamProvider<List<Band>>((ref) {...})
final songsProvider = StreamProvider<List<Song>>((ref) {...})

// Metronome
final metronomeStateProvider = NotifierProvider<MetronomeNotifier, MetronomeState>()
```

---

## BRAND & DESIGN

### Design Philosophy
**Clean. Confident. Premium-minimal.** Expensive-feeling minimalism that quietly owns the screen.

### Inspirations
- **Teenage Engineering** — Raw prototype honesty, Scandinavian restraint
- **Nothing** — Monochromatic base + bold accent, glyph-like clarity
- **Notion** — Content-first clarity, extreme airiness
- **Revolut** — Banking-grade confidence, precision

### Color System

```
Background: #000000 / #0A0A0A / #111111
Surfaces: #121212 → #1A1A1A
Primary Text: #F5F5F5 / #EDEDED
Secondary Text: #8A8A8F → #A0A0A5
Brand Accent: #FF5E00 (vivid orange)
Error: #FF2D55 (muted red)
```

**Rules:**
- No gradients (except subtle vignette)
- No secondary colors
- Orange used surgically: CTAs, active states, progress bars

### Typography
- **Primary:** Inter / Neue Haas Grotesk / GT Walsheim
- **Fallback:** Manrope / SF Pro
- **Weights:** Regular/Medium (body), SemiBold/Bold (headings)
- **Scale:** 4-point grid (4, 8, 12, 16, 20, 24, 32, 40, 48 px)

### UI Principles
- Extreme negative space (24-48 px padding)
- Corner radius: 12-16 px (cards/buttons), 8-10 px (small), 20-24 px (large)
- Icons: 1.5-2 px line weight, outline preferred
- Animations: 120-180 ms, cubic-bezier 0.4 0 0.2 1
- Contrast: WCAG AA+ minimum
- No textures, noise, skeuomorphism, glassmorphism

---

## SETUP & CONFIGURATION

### Prerequisites
- Flutter SDK 3.19+
- Dart 3.3+
- Firebase project
- Spotify API credentials (optional)

### Installation

```bash
# Clone repository
git clone https://github.com/berlogabob/flutter-repsync-app.git
cd flutter-repsync-app

# Install dependencies
flutter pub get

# Copy environment variables
cp .env.example .env

# Edit .env with your credentials
# SPOTIFY_CLIENT_ID=your_id
# SPOTIFY_CLIENT_SECRET=your_secret

# Run on device
flutter run
```

### Firebase Setup

1. Create Firebase project
2. Enable Authentication (Email/Password, Google)
3. Create Firestore database
4. Deploy security rules:
```bash
firebase deploy --only firestore:rules
```

### Environment Variables

**Required:**
- `SPOTIFY_CLIENT_ID` - Spotify API Client ID
- `SPOTIFY_CLIENT_SECRET` - Spotify API Client Secret

**File:** `.env` (gitignored)

---

## BUILD & DEPLOYMENT

### Quick Commands

```bash
# Deploy to GitHub Pages
make deploy

# Full release (Web + Android + Git Tag)
make release

# Build web only
make build-web

# Build Android APK
make build-android

# Run tests
make test

# Show version
make version
```

### Web Deployment (GitHub Pages)

**Critical:** Use correct `base-href` or you'll get a white page!

```bash
# Correct command
flutter build web --release --base-href "/flutter-repsync-app/"

# Copy to docs/
cp -r build/web/* docs/

# Commit and push
git add docs/ pubspec.yaml
git commit -m "Deploy web build"
git push origin main
```

**URL:** https://berlogabob.github.io/flutter-repsync-app/

### Android Build

```bash
# APK (for distribution)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# AAB (for Play Store)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Version Management

**Format:** `MAJOR.MINOR.PATCH+BUILD`

Example: `0.10.1+1`

**Auto-increment:**
```bash
make increment-version
```

**Manual:** Edit `pubspec.yaml`

---

## DEVELOPMENT WORKFLOW

### Agent System

This project uses autonomous AI agents for development:

| Agent | Role |
|-------|------|
| **mr-senior-developer** | Expert code review, implementation |
| **mr-cleaner** | Code quality, formatting, dead code removal |
| **mr-tester** | Unit/widget/integration tests |
| **mr-architect** | System architecture design |
| **mr-ux-agent** | UI/UX design, Material Design |
| **mr-sync** | Task coordination, parallel execution |
| **mr-planner** | Daily development plans |
| **mr-logger** | Logging & session tracking |
| **mr-release** | Release management |
| **mr-android** | Android telemetry, crash reports |
| **mr-stupid-user** | Naive user testing |
| **creative-director** | User journey architecture |

### Development Commands

```bash
# Run on connected device
make run

# Run on Chrome (web)
make run-web

# Run on Android
make run-android

# Watch for changes
make watch

# Analyze code
make analyze

# Format code
dart format lib/

# Clean build
make clean
```

### Code Quality Gates

Before committing:
```bash
make test      # All tests pass
make analyze   # 0 errors
make build-web # Web builds successfully
```

---

## TESTING

### Test Structure

```
test/
├── models/           # Model unit tests
├── providers/        # Provider tests
├── services/         # Service layer tests
├── widgets/          # Widget tests
├── screens/          # Screen tests
├── integration/      # Integration tests
└── coverage/         # Coverage reports
```

### Running Tests

```bash
# Run all tests
flutter test

# With coverage
flutter test --coverage

# Specific test file
flutter test test/services/spotify_service_test.dart

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html
```

### Coverage Targets

| Component | Target | Current |
|-----------|--------|---------|
| Models | 90% | 88.2% |
| Providers | 85% | 17.5% |
| Services | 80% | 45% |
| Widgets | 75% | 49.7% |
| Screens | 70% | 40.1% |
| **Overall** | **80%** | **52%** |

---

## CHANGELOG

### [0.10.1+1] - 2026-02-22

**Status:** ✅ Complete | **Tests:** 98% pass rate (25 failing → from 122)

#### Added
- **Offline-first architecture** - Hive local storage with automatic sync
- **Mobile audio support** - audioplayers integration for Android/iOS
- **go_router navigation** - Type-safe declarative routing
- **Enhanced error handling** - ApiError model + user-friendly messages
- **Connectivity monitoring** - Online/offline detection with UI indicators

#### Changed
- **Metronome UI simplified** - Collapsible advanced settings, visual toggles
- **Large files refactored:**
  - metronome_widget.dart: 458 → 125 lines (73% reduction)
  - add_song_screen.dart: 530 → 248 lines (53% reduction)
  - data_providers.dart: 294 → 73 lines (75% reduction)
- **State management** - Migrated to Riverpod for consistency

#### Fixed
- 10 compilation errors
- 13 warnings → 5 (62% reduction)
- 122 failing tests → 25 (80% reduction)
- 4 P0 UX issues (Forgot Password, password requirements, PDF export, invite code)

#### Technical
- Added CacheService (Hive)
- Added ConnectivityService
- Extracted FirestoreService
- Implemented AudioEngine for mobile
- Created 4 reusable metronome widgets

### [0.10.0+1] - Previous Release

#### Features
- Initial web-first release
- Firebase integration (Auth, Firestore)
- PDF export for setlists
- Spotify integration for BPM & key detection
- Multi-group support
- Real-time collaboration

---

## SECURITY

### Environment Variables
Credentials stored in `.env` (gitignored):
- `SPOTIFY_CLIENT_ID`
- `SPOTIFY_CLIENT_SECRET`

### Firestore Rules
Deploy with:
```bash
firebase deploy --only firestore:rules
```

Users can only access:
- Their own songs and setlists
- Bands they're members of
- Data authorized by their role

---

## TROUBLESHOOTING

### White Page on GitHub Pages
**Problem:** Incorrect base-href
**Solution:**
```bash
flutter build web --release --base-href "/flutter-repsync-app/"
```

### Tests Failing
**Problem:** Mockito stub issues
**Solution:** Check test setup, ensure proper mock initialization

### Build Fails
**Problem:** Missing dependencies
**Solution:**
```bash
flutter clean
flutter pub get
```

### Android Audio Not Working
**Problem:** Permissions not set
**Solution:** Check AndroidManifest.xml for audio permissions

---

## LICENSE

MIT License — see LICENSE file

---

## CONTACT & SUPPORT

- **Issues:** https://github.com/berlogabob/flutter-repsync-app/issues
- **Discussions:** https://github.com/berlogabob/flutter-repsync-app/discussions

**Built with ❤️ for musicians and cover bands**
