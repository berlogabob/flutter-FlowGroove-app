# Song Structure Constructor

A Flutter widget for building song structures with a puzzle-like interface. Features collapsed/expanded states with visual pill representation and detailed section editing.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Dart](https://img.shields.io/badge/Dart-3.x-blue)

## ✨ Features

- 🧩 **Two-State Interface**: Collapsed (pill visualization) and expanded (detailed list) views
- 🎨 **Pill Visualization**: Colored blocks proportional to section durations in collapsed state
- 📝 **Duration Support**: Each section has configurable duration in phrases
- ✏️ **Rich Editing**: Edit section name, duration, and notes (e.g., guitar chords)
- 🔄 **Drag-and-Drop**: Reorder sections vertically in expanded state
- ⚡ **Auto-Generate**: Quick start with random structure (3-7 sections)
- 📚 **Template Library**: Predefined sections (Intro, Verse, Chorus, Bridge, etc.)
- 🗑️ **Easy Delete**: Remove sections with confirmation dialog

## 📸 Screenshots

### Collapsed State
Shows a pill-shaped visualization with colored blocks representing each section. Block widths are proportional to section durations.

### Expanded State
Displays a vertical list of cards with section details including name, duration, and notes.

## 🚀 Quick Start

### Installation

1. Clone or copy the project:
```bash
cd slutter_sandbox
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Basic Usage

```dart
import 'package:slutter_sandbox/song_constructor.dart';

// Simple usage
SongConstructor()

// With callback for structure changes
SongConstructor(
  onChange: (sections) {
    print('Structure changed: ${sections.length} sections');
    // Export to JSON if needed
    final json = sections.map((s) => s.toJson()).toList();
  },
)

// With initial sections
SongConstructor(
  initialSections: [
    Section(id: '1', name: 'Intro', duration: 2),
    Section(id: '2', name: 'Verse', duration: 4, notes: 'Am - C - G'),
    Section(id: '3', name: 'Chorus', duration: 4, notes: 'G - D - Em'),
  ],
)
```

## 📖 API Reference

### SongConstructor Widget

| Parameter | Type | Description |
|-----------|------|-------------|
| `onChange` | `Function(List<Section>)?` | Callback triggered when structure changes |
| `initialSections` | `List<Section>?` | Initial sections to display |

### Section Model

```dart
class Section {
  final String id;
  String name;
  String notes;
  int duration;
  
  // Methods
  Section copyWith({String? name, String? notes, int? duration})
  Map<String, dynamic> toJson()
  factory Section.fromJson(Map<String, dynamic> json)
  int get colorIndex  // For consistent pill colors
}
```

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique identifier (UUID) |
| `name` | `String` | Section name (e.g., "Verse", "Chorus") |
| `notes` | `String` | Optional notes (e.g., guitar chords) |
| `duration` | `int` | Duration in phrases (default: 1) |

### Predefined Templates

```dart
Section.templates = [
  'Intro',
  'Verse',
  'Chorus',
  'Bridge',
  'Pre-Chorus',
  'Outro',
  'Instrumental',
]
```

## 🎯 User Guide

### Collapsed State
- Shows pill-shaped visualization
- Colored blocks represent sections
- Block width ∝ section duration
- Tap expand icon (↓) to see details

### Expanded State
1. **Add Section**: Tap "Add Section" button
2. **Edit Section**: Tap on any section card
3. **Reorder**: Long press and drag vertically
4. **Delete**: Tap the delete icon (trash)
5. **Auto-Generate**: Tap "Auto-Generate" for random structure

### Edit Dialog
- **Section Type**: Choose from dropdown or enter custom name
- **Duration**: Quick-select buttons (1-4) or custom value
- **Notes**: Multi-line text for chords/lyrics hints

## 🧪 Testing

Run all tests:
```bash
flutter test
```

### Test Coverage
- State toggle (collapsed ↔ expanded)
- Auto-generate functionality
- Add/Edit/Delete sections
- Duration updates
- Pill visualization
- Model serialization

## 📁 Project Structure

```
slutter_sandbox/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── song_constructor.dart        # Main widget
│   ├── models/
│   │   └── section.dart             # Section data model
│   └── widgets/
│       ├── section_card.dart        # Card for expanded state
│       ├── section_picker.dart      # Template picker
│       ├── edit_section_dialog.dart # Edit dialog with duration
│       └── pill_view.dart           # Pill visualization
├── test/
│   └── widget_test.dart             # Widget tests
├── agents/                          # Qwen agent prompts
│   ├── planner_agent.md
│   ├── ui_designer_agent.md
│   ├── coder_agent.md
│   ├── tester_agent.md
│   ├── integrator_agent.md
│   └── run_agents.sh
└── pubspec.yaml                     # Dependencies
```

## 🛠️ Development

### Using Qwen Agents

The `agents/` folder contains prompts for multi-agent development:

```bash
cd agents
./run_agents.sh
```

Agents:
1. **Planner**: Project planning and requirements
2. **UI Designer**: Interface design and user flow
3. **Coder**: Code implementation
4. **Tester**: Testing and quality assurance
5. **Integrator**: Documentation and integration

### AGENT TODOs

Search for `// AGENT TODO` comments in the code for potential improvements:
- Enhance random generation with musical patterns
- Optimize pill rendering for long structures
- Add haptic feedback for drag operations
- Implement undo/redo functionality

## 📄 License

MIT License - See LICENSE file for details.

## 🤝 Contributing

Contributions welcome! Areas for improvement:
- [ ] Undo/redo functionality
- [ ] Export to MIDI/text formats
- [ ] Custom color schemes
- [ ] Section templates management
- [ ] Drag-and-drop in collapsed state
- [ ] Animation between states
