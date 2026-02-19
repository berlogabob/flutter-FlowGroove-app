# AGENTS.md - Agent Coding Guidelines for RepSync

## Project Overview

RepSync is a Flutter web application for band repertoire management. Built with Flutter/Dart, Firebase (Auth + Firestore), and Riverpod for state management. Target platforms: Web → Android → iOS.

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
# Analyze code for errors and warnings
flutter analyze

# Analyze with fix suggestions
flutter analyze --fix
```

Uses `flutter_lints: ^6.0.0` (see `analysis_options.yaml`).

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

### State Management (Riverpod)

- Use `StreamProvider` for async data from Firestore
- Use `StateProvider` for simple state
- Use `ConsumerWidget` / `ConsumerStatefulWidget` for widgets that read providers

```dart
final songsProvider = StreamProvider<List<Song>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreProvider).watchSongs(user.uid);
});
```

### Error Handling

- Use try-catch for async operations
- Handle Firebase errors with user-friendly messages
- Always dispose controllers in `dispose()` method
- Show errors via `ScaffoldMessenger.of(context).showSnackBar()`

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
│   └── firestore_service.dart  # Firestore CRUD operations
├── screens/
│   ├── home_screen.dart        # Dashboard with stats
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
| flutter_riverpod | State management |
| uuid | Generate unique IDs |
| intl | Date formatting |

---

## Common Tasks

### Adding a New Screen

1. Create file in appropriate `lib/screens/` subdirectory
2. Create a `ConsumerStatefulWidget` or `ConsumerWidget`
3. Add route in `lib/main.dart` routes map
4. Navigate with `Navigator.pushNamed(context, '/route-name')`

### Adding a New Model

1. Create file in `lib/models/`
2. Define class with `fromJson` and `toJson` methods
3. Add Firestore methods in `lib/providers/data_providers.dart`
4. Create `StreamProvider` for live data

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

1. `flutter analyze` - fix all errors/warnings
2. `flutter build web` - ensure build succeeds
3. Test login/logout flow
4. Test CRUD operations for songs/bands/setlists
