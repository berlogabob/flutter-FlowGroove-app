
# RepSync

[![Flutter Version](https://img.shields.io/badge/Flutter-3.19+-blue.svg)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.3+-blue.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/berlogabob/flutter-repsync-app?style=social)](https://github.com/berlogabob/flutter-repsync-app/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/berlogabob/flutter-repsync-app?style=social)](https://github.com/berlogabob/flutter-repsync-app/network/members)

**Flutter app for managing band repertoires, setlists, and shared song databases for cover bands**

## Features
- Shared song database with unique IDs
- Setlists for gigs and rehearsals (drag & drop, per-event overrides)
- Multi-group support (one user in several bands)
- PDF export for setlists
- Web-first (works in browser on iPhone/Android)
- Spotify integration for BPM & key detection
- Real-time collaboration with band members

## Tech Stack
- Flutter (web-first)
- Dart
- Firebase (auth, Firestore realtime sync)
- Hive (local offline storage)
- pdf & printing packages (PDF generation)

## Project Roadmap (MVP - February 2026)

Web version with manual song input & PDF export
Post-MVP: MusicBrainz autofill, mobile builds, premium features

## Quick Links

| Documentation | Description |
|---------------|-------------|
| [📖 Build Guide](BUILD_GUIDE.md) | Complete build instructions for all platforms |
| [✅ Deployment Checklist](DEPLOYMENT_CHECKLIST.md) | Step-by-step deployment checklists |
| [🚀 Release Process](RELEASE_PROCESS.md) | Version management and release workflow |
| [📱 Platform Guide](docs/PLATFORMS.md) | Platform support and features |
| [⚡ Quick Start](QUICK_START.md) | Get started in 5 minutes |
| [🔧 Troubleshooting](TROUBLESHOOTING.md) | Common issues and solutions |

## Security

### Environment Variables
Sensitive credentials (Spotify API keys) are stored in environment variables using `flutter_dotenv`.

**Setup:**
1. Copy `.env.example` to `.env`
2. Replace placeholder values with your actual credentials
3. The `.env` file is gitignored to prevent accidental commits

**Required variables:**
- `SPOTIFY_CLIENT_ID` - Your Spotify API Client ID
- `SPOTIFY_CLIENT_SECRET` - Your Spotify API Client Secret

### Firestore Security Rules
Firestore security rules ensure that users can only access their own data and authorized band data.

**Rules Overview:**
- `users/{userId}/songs/{songId}` - Only the owner can read/write
- `users/{userId}/setlists/{setlistId}` - Only the owner can read/write
- `users/{userId}/bands/{bandId}` - Band members can read, owner can write

**Deploy Rules:**
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy rules to Firebase
firebase deploy --only firestore:rules
```

**Test Rules:**
```bash
# Start Firebase Emulator
firebase emulators:start --only firestore

# Or use Rules Playground in Firebase Console
# Go to Firebase Console > Firestore > Rules > Rules Playground
```

See `firestore.rules` for the complete rules implementation and `firestore.test.rules` for test cases.

## License
MIT License — see LICENSE file

---
### Built with ❤️ for musicians and cover bands
