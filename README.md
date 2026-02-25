# RepSync

[![Flutter Version](https://img.shields.io/badge/Flutter-3.19+-blue.svg)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.3+-blue.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/berlogabob/flutter-repsync-app?style=social)](https://github.com/berlogabob/flutter-repsync-app/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/berlogabob/flutter-repsync-app?style=social)](https://github.com/berlogabob/flutter-repsync-app/network/members)

**Flutter app for managing band repertoires, setlists, and shared song databases for cover bands**

## 🎵 Key Features

### Song Management
- **Shared Song Database** - Centralized repository with unique IDs for each song
- **Comprehensive Song Details** - Title, artist, original/our key, original/our BPM, notes, tags
- **Song Structure Editor** - Visual song sections (Intro, Verse, Chorus, Bridge, etc.) with colors and durations
- **Links Management** - Attach YouTube, Spotify, tabs, drums, and chords links to each song
- **Metronome Settings** - Configurable beat patterns with accent/normal/silent/rest modes
- **Multi-Group Support** - One user can belong to multiple bands simultaneously
- **Song Attribution** - Track who created and contributed each song
- **Tags & Filtering** - Organize songs with custom tags for easy searching

### Setlist Management
- **Create Setlists** - Build setlists for gigs and rehearsals
- **Drag & Drop Ordering** - Intuitive rearrangement of songs within setlists
- **Per-Event Overrides** - Customize key and BPM for specific performances
- **PDF Export** - Generate professional setlist sheets for band members
- **Setlist Templates** - Reuse successful setlist structures

### Collaboration & Sharing
- **Real-Time Sync** - All band members see updates instantly via Firebase
- **Band Member Management** - Invite and manage band members with unique IDs
- **Song Sharing** - Copy songs from personal library to band repertoire
- **Attribution Tracking** - See who added each song to the band

### Data Import/Export
- **CSV Import** - Import songs from CSV files or clipboard (Google Sheets compatible)
- **CSV Export** - Export entire song library to CSV for backup or sharing
- **Google Sheets Migration** - Step-by-step guide for transitioning from spreadsheets
- **Share Integration** - Share exported files via email, cloud storage, or other apps

### Audio & Practice
- **Mobile Audio Playback** - Built-in audio player for practice and performance
- **Spotify Integration** - Automatic BPM and key detection from Spotify tracks
- **Beat Mode Editor** - Configure complex rhythmic patterns for metronome
- **Section-Based Practice** - Break songs into manageable parts with duration markers

### Offline & Performance
- **Offline-First Architecture** - Full functionality without internet connection
- **Local Storage** - Hive-based caching for instant access to data
- **Smart Synchronization** - Automatic sync when connection restored
- **Error Resilience** - Comprehensive error handling and recovery

### User Experience
- **Web-First Design** - Works in browser on iPhone/Android (no app install required)
- **Enhanced Navigation** - Smooth routing with go_router
- **Material Design** - Clean, modern UI following Material Design 3 principles
- **Dark Theme** - Easy on the eyes for late-night practice sessions
- **Responsive Layout** - Adapts to phones, tablets, and desktop screens

## 🛠️ Tech Stack

### Frontend
- **Flutter** 3.19+ - Cross-platform UI framework
- **Dart** 3.3+ - Type-safe, modern programming language
- **flutter_riverpod** 3.2.1 - State management and dependency injection
- **go_router** 17.1.0 - Declarative routing

### Backend & Storage
- **Firebase Auth** 6.1.4 - User authentication
- **Cloud Firestore** 6.1.2 - Real-time database sync
- **Hive** 2.2.3 - Local offline storage
- **Hive Flutter** 1.1.0 - Flutter integration for Hive

### Media & Export
- **Audioplayers** 6.5.1 - Audio playback
- **PDF** 3.11.2 - PDF generation
- **Printing** 5.14.2 - Print and share PDFs

### Utilities
- **CSV** 7.1.0 - CSV parsing and serialization
- **File Picker** 8.3.2 - File selection for import/export
- **Share Plus** 10.1.4 - Native sharing functionality
- **Path Provider** 2.1.5 - File system paths
- **Connectivity Plus** 7.0.0 - Network status monitoring
- **URL Launcher** 6.3.2 - Open external links
- **Package Info Plus** 9.0.0 - App version and metadata
- **Intl** 0.20.2 - Internationalization
- **UUID** 4.5.3 - Unique identifier generation

### Development
- **Build Runner** 2.4.8 - Code generation
- **JSON Serializable** 6.13.0 - JSON serialization
- **Mockito** 5.6.3 - Mocking for tests
- **Mocktail** 1.0.0 - Modern mocking library
- **Flutter Test** - Built-in testing framework

## 📚 Documentation

### Main Documentation
- **[📄 PROJECT.md](PROJECT.md)** — Complete project documentation including:
  - Architecture & tech stack details
  - Brand & design guidelines
  - Setup & configuration instructions
  - Build & deployment guide
  - Development workflow
  - Testing strategy
  - Complete changelog

### User Guides
- **[📊 CSV Import/Export Guide](CSV_IMPORT_EXPORT_GUIDE.md)** — Complete guide for:
  - Importing songs from CSV files
  - Exporting song library to CSV
  - Migrating from Google Sheets
  - CSV format specification
  - Troubleshooting common issues

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.19+
- Dart 3.3+
- Firebase project (for backend services)
- Spotify API credentials (optional, for BPM/key detection)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/berlogabob/flutter-repsync-app.git
   cd flutter-repsync-app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Setup environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your Spotify API credentials
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

### Build for Production

**Web:**
```bash
flutter build web --release
```

**Android:**
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

## 🔒 Security

### Environment Variables
Sensitive credentials (Spotify API keys) are stored in environment variables using `flutter_dotenv`.

**Required variables:**
- `SPOTIFY_CLIENT_ID` - Your Spotify API Client ID
- `SPOTIFY_CLIENT_SECRET` - Your Spotify API Client Secret

**Setup:**
1. Copy `.env.example` to `.env`
2. Replace placeholder values with your actual credentials
3. The `.env` file is gitignored to prevent accidental commits

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

## 🧪 Testing

### Run All Tests
```bash
flutter test
```

### Run Specific Test Suite
```bash
# CSV import/export tests
flutter test test/services/csv/

# Model tests
flutter test test/models/

# Widget tests
flutter test test/widgets/

# Screen tests
flutter test test/screens/
```

### Test Coverage
```bash
flutter test --coverage
```

## 📦 Project Structure

```
lib/
├── models/           # Data models (Song, Setlist, Band, etc.)
├── providers/        # Riverpod providers
│   ├── auth/        # Authentication providers
│   └── data/        # Data providers
├── screens/          # UI screens
│   ├── songs/       # Song management screens
│   └── setlists/    # Setlist management screens
├── services/         # Business logic services
│   ├── api/         # External API clients
│   ├── audio/       # Audio playback services
│   ├── csv/         # CSV import/export services
│   └── export/      # PDF export services
├── theme/            # App theme and design system
├── widgets/          # Reusable UI components
└── main.dart         # App entry point
```

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

MIT License — see [LICENSE](LICENSE) file for details

## 🙏 Acknowledgments

- Built with ❤️ for musicians and cover bands
- Thanks to all contributors and supporters
- Special thanks to the Flutter and Firebase communities

---

**Last Updated:** February 2026  
**Current Version:** 0.11.2+51
