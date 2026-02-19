# AGENTS.md - Agent Coding Guidelines for RepSync

## Project Overview

RepSync is a Flutter web application for band repertoire management. Built with Flutter/Dart, Firebase (Auth + Firestore), and Riverpod 3.x for state management. Target platforms: Web → Android → iOS.

---

## Build / Lint / Test Commands

### Dependencies

```bash
flutter pub get
```

### Running the App

```bash
# Run on web (development)
flutter run -d chrome

# Run on specific device
flutter run -d <device_id>

# Run in release mode
flutter run --release
```

### Code Analysis & Linting

```bash
# Analyze code for errors and warnings (REQUIRED before commits)
flutter analyze

# Analyze with fix suggestions
flutter analyze --fix

# Format all code
dart format .
```

Uses `flutter_lints: ^6.0.0` (see `analysis_options.yaml`). **No issues should remain after analysis.**

### Testing

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Run tests matching a name pattern
flutter test --name "pattern"

# Run with coverage
flutter test --coverage
```

### Building

```bash
# Build web (primary target)
flutter build web

# Build Android APK
flutter build apk --debug
flutter build apk --release

# Build iOS (requires macOS)
flutter build ios --simulator --no-codesign
```

---

## Code Style Guidelines

### Imports

- Use package imports for external packages: `import 'package:flutter/material.dart';`
- Use relative imports for local files: `import '../models/song.dart';`
- Group imports: external packages first, then local relative imports

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../models/song.dart';
```

### Formatting

- Use 2 spaces for indentation (Flutter default)
- Use trailing commas for better formatting in lists/maps
- Keep lines under 80 characters when practical
- Run `dart format .` before committing
- Avoid unnecessary underscores in lambda parameters: use `(error, stack)` not `(_, __)`

### Naming Conventions

- **Classes**: PascalCase (`Song`, `SongsNotifier`, `AddSongScreen`)
- **Functions/variables**: camelCase (`addSong`, `_selectedSongs`)
- **Private members**: prefix with underscore (`_formKey`, `_isLoading`)
- **Files**: snake_case (`add_song_screen.dart`, `data_providers.dart`)
- **Providers**: camelCase with `Provider` suffix (`songsProvider`, `firestoreProvider`)

### Types

- Prefer explicit types over `var` when type is not obvious
- Use `final` by default, `var` only when reassignment needed
- Use `const` for compile-time constants

### Widgets

- Use `const` constructor for stateless widgets where possible
- Use `super.key` for widget keys
- Prefer `SizedBox` over `Container` for spacing
- Avoid deprecated methods like `withOpacity()` - use `withValues(alpha:)` instead

### State Management (Riverpod 3.x)

- Use `StreamProvider` for async data from Firestore
- Use `NotifierProvider` for complex state (replaces `StateNotifierProvider`)
- Use `ConsumerWidget` / `ConsumerStatefulWidget` for widgets that read providers
- Avoid deprecated `valueOrNull` - use `value` instead

```dart
// StreamProvider for Firestore data
final songsProvider = StreamProvider<List<Song>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreProvider).watchSongs(user.uid);
});

// NotifierProvider for state (Riverpod 3.x)
class SelectedBandNotifier extends Notifier<Band?> {
  @override
  Band? build() => null;
  
  void select(Band? band) => state = band;
}

final selectedBandProvider = NotifierProvider<SelectedBandNotifier, Band?>(() {
  return SelectedBandNotifier();
});
```

### Error Handling

- Use try-catch for async operations
- Handle Firebase errors with user-friendly messages
- Always dispose controllers in `dispose()` method
- Use `mounted` check before using context in async callbacks
- Use curly braces in if statements even for single statements

```dart
try {
  await firestore.saveSong(song, user.uid);
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}
```

### Firebase / Firestore

- Check `currentUserProvider` before Firestore operations
- Use `FirestoreService` class for all Firestore operations
- Data stored per-user: `users/{uid}/songs`, `users/{uid}/bands`, `users/{uid}/setlists`

---

## Project Structure

```
lib/
├── main.dart                    # App entry point, routes
├── firebase_options.dart        # Firebase configuration
├── models/
│   ├── song.dart               # Song data model
│   ├── band.dart               # Band + BandMember models
│   ├── setlist.dart            # Setlist model
│   ├── link.dart               # Link model (for song links)
│   └── user.dart               # AppUser model
├── providers/
│   ├── auth_provider.dart      # Firebase auth providers
│   └── data_providers.dart     # Firestore providers + service
├── services/
│   ├── firestore_service.dart  # Firestore CRUD operations
│   ├── pdf_service.dart       # PDF export for setlists
│   ├── musicbrainz_service.dart # Music metadata search (title, artist, BPM)
│   └── spotify_service.dart  # Spotify API (BPM, key) - requires API credentials
├── screens/
│   ├── main_shell.dart         # Bottom navigation shell
│   ├── home_screen.dart        # Dashboard with stats
│   ├── profile_screen.dart     # Profile/settings screen
│   ├── login_screen.dart       # Login form
│   ├── auth/
│   │   └── register_screen.dart
│   ├── songs/
│   │   ├── songs_list_screen.dart
│   │   └── add_song_screen.dart
│   ├── bands/
│   │   ├── my_bands_screen.dart
│   │   ├── create_band_screen.dart
│   │   └── join_band_screen.dart
│   └── setlists/
│       ├── setlists_list_screen.dart
│       └── create_setlist_screen.dart
└── theme/
    └── app_theme.dart          # AppColors + light/dark themes
```

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| firebase_core | Firebase initialization |
| firebase_auth | Email/password authentication |
| cloud_firestore | Data persistence |
| flutter_riverpod | State management (v3.x) |
| uuid | Generate unique IDs |
| intl | Date formatting |
| pdf | PDF document generation |
| printing | PDF printing/export |
| url_launcher | Open external links |
| http | HTTP requests for API calls |

---

## Common Tasks

### Adding a New Screen

1. Create file in appropriate `lib/screens/` subdirectory
2. Create a `ConsumerStatefulWidget` or `ConsumerWidget`
3. Add route in `lib/main.dart` routes map
4. Navigate with `Navigator.pushNamed(context, '/route-name')`

### Adding Edit Functionality

1. Add optional model parameter to screen constructor
2. Check `if (_isEditing = model != null)` in initState
3. Pre-populate form fields from existing data
4. Use existing ID when saving (don't generate new UUID)
5. Update title: `_isEditing ? 'Edit' : 'Add'`

### Adding a New Model

1. Create file in `lib/models/`
2. Define class with `fromJson` and `toJson` methods
3. Add Firestore methods in `lib/services/firestore_service.dart`
4. Create `StreamProvider` for live data in `lib/providers/data_providers.dart`

### Firestore Rules

Ensure Firestore rules allow authenticated users:
```
allow read, write: if request.auth != null;
```

---

## Color Palette

| Color | Hex | Usage |
|-------|-----|-------|
| color1 | #96B3D9 | Primary - buttons, headers |
| color2 | #D5E7F2 | Surface - light mode bg |
| color3 | #C9EBF2 | Highlight - selections |
| color4 | #0B2624 | Background - dark mode |
| color5 | #7EBFB3 | Secondary - accents |

---

## Pre-Commit Checklist

1. `flutter analyze` - fix all errors/warnings (no issues allowed)
2. `dart format .` - format all code
3. `flutter build web` - ensure build succeeds
4. Test login/logout flow
5. Test CRUD operations for songs/bands/setlists

## Music Services

### MusicBrainz (No API key required)
- Provides: title, artist, album, BPM
- No authentication needed
- Rate limited: 1 request per second (be careful with rapid searches)

### Spotify (Requires API credentials + Premium subscription)
- Provides: title, artist, album, BPM, musical key (major/minor), Spotify URL
- Requires Spotify Developer account AND Spotify Premium subscription
- Get credentials: https://developer.spotify.com/dashboard
- Edit `lib/services/spotify_service.dart` to add your Client ID and Client Secret
- Note: Spotify API requires a Premium account to work

### Web Search (Fallback - No API needed)
- Users can search on Spotify web via browser
- Useful when Spotify API is unavailable (e.g., no Premium subscription)

---

## Important Notes for Agents

- **Always run `flutter analyze` before finishing any task** - no issues should remain
- **Use Riverpod 3.x syntax**: `NotifierProvider` instead of `StateNotifierProvider`
- **Avoid deprecated methods**: `withOpacity()` → `withValues(alpha:)`, `valueOrNull` → `value`
- **Keep responses concise** - max 3-4 lines unless user requests detail
- **Do NOT commit changes unless explicitly asked by user**
