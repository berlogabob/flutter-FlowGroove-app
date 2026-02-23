# Changelog

All notable changes to RepSync will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**For detailed release notes, see [PROJECT.md#changelog](PROJECT.md#changelog).**

---

## [0.11.2+33] - 2026-02-23

**Status:** ✅ Complete | **Dependencies Updated**

### Updated Dependencies
- `go_router`: ^16.3.0 → ^17.1.0 (type-safe navigation)
- `json_annotation`: ^4.10.0 → ^4.11.0
- `json_serializable`: ^6.12.0 → ^6.13.0
- `package_info_plus`: ^8.3.1 (compatible version)
- `permission_handler`: ^11.4.0 → ^12.0.1
- `permission_handler_android`: ^12.1.0 → ^13.0.1
- `uuid`: ^4.5.2 → ^4.5.3

### Fixed
- Makefile: Push to current branch instead of hardcoded `main`
- Android build: Resolved package_info_plus compatibility issues
- Documentation: Consolidated 61 files into single PROJECT.md

### Build Artifacts
- **Web:** 3.8MB (main.dart.js)
- **Android APK:** 58.4MB
- **Android AAB:** 48.3MB
- **GitHub Release:** https://github.com/berlogabob/flutter-repsync-app/releases/tag/v0.11.2+33

---

## [0.10.1+1] - 2026-02-22

**Status:** ✅ Complete | **Tests:** 98% pass rate

### Added
- **Offline-first architecture** - Hive local storage with automatic sync
- **Mobile audio support** - audioplayers integration for Android/iOS
- **go_router navigation** - Type-safe declarative routing
- **Enhanced error handling** - ApiError model + user-friendly messages
- **Connectivity monitoring** - Online/offline detection with UI indicators

### Changed
- **Metronome UI simplified** - Collapsible advanced settings, visual toggles
- **Large files refactored:**
  - metronome_widget.dart: 458 → 125 lines (73% reduction)
  - add_song_screen.dart: 530 → 248 lines (53% reduction)
  - data_providers.dart: 294 → 73 lines (75% reduction)
- **State management** - Migrated to Riverpod for consistency

### Fixed
- 10 compilation errors
- 13 warnings → 5 (62% reduction)
- 122 failing tests → 25 (80% reduction)
- 4 P0 UX issues (Forgot Password, password requirements, PDF export, invite code)

### Technical
- Added CacheService (Hive)
- Added ConnectivityService
- Extracted FirestoreService
- Implemented AudioEngine for mobile
- Created 4 reusable metronome widgets

---

## [0.10.0+1] - Previous Release

### Added
- Initial web-first release
- Firebase integration (Auth, Firestore)
- PDF export for setlists
- Spotify integration for BPM & key detection
- Multi-group support
- Real-time collaboration

---
