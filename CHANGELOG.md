# Changelog

All notable changes to RepSync will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.10.1+1] - 2026-02-22

### Added
- **Offline-first architecture** - Implemented Hive local storage for offline access to songs and setlists
- **Mobile audio support** - Integrated audioplayers package for audio playback on mobile devices
- **go_router navigation** - Implemented declarative routing with go_router for better navigation management
- **Enhanced error handling** - Comprehensive error handling throughout the application

### Changed
- **UX improvements** - Various user experience enhancements across the application
- **Code quality improvements** - Refactored code for better maintainability and performance

### Technical
- Updated dependencies to latest stable versions
- Improved offline synchronization with Firestore
- Enhanced audio playback capabilities for mobile platforms

---

## [0.10.0+1] - Previous Release

### Features
- Initial web-first release
- Firebase integration (Auth, Firestore)
- PDF export for setlists
- Spotify integration for BPM & key detection
- Multi-group support
- Real-time collaboration
