# AGENTS.md - Agent Coding Guidelines for RepSync

## Project Overview

RepSync is a Flutter mobile application with Firebase authentication (Firebase Core + Firebase Auth). The project uses Dart SDK ^3.10.7.

---

## Build / Lint / Test Commands

### Running the App

```bash
# Run on connected device/simulator
flutter run

# Run on specific platform
flutter run -d <device_id>
flutter run -d ios
flutter run -d android

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

The project uses `flutter_lints: ^6.0.0` (see `analysis_options.yaml`). Default Flutter lints are enabled with no custom rules overridden.

### Testing

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Run tests matching a name pattern
flutter test --name "Counter increments"

# Run with coverage
flutter test --coverage
```

### Building

```bash
# Build iOS (requires macOS)
flutter build ios
flutter build ios --simulator --no-codesign

# Build Android APK
flutter build apk --debug
flutter build apk --release

# Build web
flutter build web
```

---

## Code Style Guidelines

### General Principles

- Use `flutter analyze` to check code before committing
- Prefer const constructors wherever possible
- Keep functions small and focused (single responsibility)
- Use meaningful variable and function names

### Imports

- Use package imports: `import 'package:flutter/material.dart';`
- Use relative imports for local files: `import 'firebase_options.dart';`
- Group imports: external packages first, then local relative imports
- Do not use relative imports for package imports

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
```

### Formatting

- Use 2 spaces for indentation (Flutter default)
- Maximum line length: 80 characters (recommended)
- Use trailing commas for better formatting in lists/maps
- Always use curly braces for control flow statements

```dart
// Good
const SizedBox(height: 16)

// Good - trailing comma
Column(
  children: [
    const Text('Title'),
    const Text('Subtitle'),
  ],
)
```

### Naming Conventions

- **Classes**: PascalCase (`MyApp`, `LoginScreen`)
- **Functions/variables**: camelCase (`isLogin`, `_emailController`)
- **Private members**: prefix with underscore (`_LoginScreenState`)
- **Constants**: PascalCase with k prefix (`kPrimaryColor`)
- **Files**: snake_case (`login_screen.dart`)

### Types

- Prefer explicit types over `var` when type is not obvious
- Use `final` by default, `var` only when reassignment needed
- Use `const` for compile-time constants
- Enable strict type checking in analysis_options.yaml

```dart
// Good
final TextEditingController emailController = TextEditingController();
const int maxLength = 100;

// Avoid when type is unclear
var controller = TextEditingController();
```

### Widgets

- Use `const` constructor for stateless widgets
- Extract widgets into separate widgets for reusability
- Use `super.key` for widget keys
- Prefer `SizedBox` over `Container` for spacing

```dart
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Hello');
  }
}
```

### Error Handling

- Use try-catch for async operations
- Handle Firebase errors with user-friendly messages
- Always dispose controllers in `dispose()` method

```dart
@override
void dispose() {
  _emailController.dispose();
  _passwordController.dispose();
  super.dispose();
}
```

### State Management

- Use StatefulWidget for local state
- Follow the pattern: `MyWidget` (Stateless) + `MyWidgetState` (State)
- Use `setState()` only when needed

### Firebase Integration

- Initialize Firebase in `main()` before `runApp()`
- Use `WidgetsFlutterBinding.ensureInitialized()` before Firebase init

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
```

---

## Project Structure

```
lib/
  main.dart                 # App entry point
  firebase_options.dart     # Firebase configuration
  screens/
    login_screen.dart       # Login/Registration screen
test/
  widget_test.dart          # Widget tests
```

---

## Common Tasks

### Adding a New Screen

1. Create file in `lib/screens/` with snake_case name
2. Create a StatefulWidget/StatelessWidget
3. Import and navigate to it from parent screen

### Adding a New Dependency

1. Add to `pubspec.yaml` under `dependencies` or `dev_dependencies`
2. Run `flutter pub get`
3. Import in code using `package:` syntax

### Running Analysis Before Commit

```bash
flutter analyze
```

Fix any errors or warnings before committing. Errors will block the build; warnings should be addressed for code quality.

---

## IDE Setup

For VS Code / Cursor / other editors:
- Install Flutter extension
- Enable "Format on Save" 
- Enable Dart analysis on save

For Android Studio:
- Enable "Format code on save"
- Enable Flutter inspector

---

## Resources

- Flutter Docs: https://flutter.dev/docs
- Dart Docs: https://dart.dev/guides
- Firebase Flutter: https://firebase.google.com/docs/flutter/setup
