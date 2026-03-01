# 🛠 Tools Architecture Guide

## Overview

The Tools system provides a unified architecture for building "apps within apps" - self-contained tool screens like Metronome, Tuner, and future tools (Recorder, Sound Generator, etc.).

## Design Principles

1. **Consistency** - All tools share the same visual language and interaction patterns
2. **Modularity** - Tools are composed of reusable blocks that can be rearranged
3. **Responsiveness** - Tools adapt to screen size and orientation
4. **Accessibility** - WCAG AA+ contrast, 48px minimum touch zones, haptic feedback
5. **Offline-First** - Tool settings persist locally via Hive

---

## Architecture

### Directory Structure

```
lib/
├── screens/tools/
│   ├── metronome_screen.dart      # Existing metronome
│   ├── tuner_screen.dart          # Existing tuner
│   └── (future tools)
├── widgets/tools/
│   ├── tool_scaffold.dart         # Base scaffold for all tools
│   ├── tool_app_bar.dart          # Consistent app bar
│   ├── tool_transport_bar.dart    # Play/Stop controls
│   ├── tool_mode_switcher.dart    # Mode pills widget
│   └── tools.dart                 # Exports
└── theme/
    └── mono_pulse_theme.dart      # Design tokens
```

---

## Core Components

### 1. ToolScreenScaffold

Base scaffold for all tool screens.

**Features:**
- AppBar with back button, title, 3-dot menu
- Main tool widget (takes available space)
- Optional secondary widget (e.g., fine adjustment buttons)
- Optional bottom widget (e.g., transport bar)
- No bottom navigation bar (tools are full-screen)

**Usage:**
```dart
ToolScreenScaffold(
  title: 'Metronome',
  menuItems: [
    PopupMenuItem(child: Text('Save'), onTap: _save),
  ],
  mainWidget: CentralTempoCircle(),
  secondaryWidget: FineAdjustmentButtons(),
  bottomWidget: BottomTransportBar(),
)
```

---

### 2. ToolAppBar

Consistent app bar for all tools.

**Features:**
- Circular back button with border
- Three dots menu button
- Haptic feedback on tap
- 48px minimum touch zones

**Usage:**
```dart
ToolAppBar.build(
  context,
  title: 'Metronome',
  menuItems: [...],
)
```

---

### 3. ToolTransportBar

Transport controls for audio tools.

**Features:**
- Play/Pause button (primary action, orange)
- Optional Previous/Next buttons
- Optional Settings button
- Haptic feedback

**Usage:**
```dart
ToolTransportBar(
  isPlaying: true,
  onPlayPause: () => togglePlay(),
  showNavigation: true,
  onPrevious: () => previousPreset(),
  onNext: () => nextPreset(),
)
```

---

### 4. ToolModeSwitcher

Mode selection for tools with multiple modes.

**Features:**
- Animated pill buttons
- Smooth fade transition (250ms)
- Haptic feedback

**Usage:**
```dart
ToolModeSwitcher<TunerMode>(
  activeMode: mode,
  options: [
    ToolModeOption(
      mode: TunerMode.generate,
      label: 'Generate Tone',
      icon: Icons.graphic_eq,
    ),
    ToolModeOption(
      mode: TunerMode.listen,
      label: 'Listen & Tune',
      icon: Icons.mic,
    ),
  ],
  onModeChanged: (mode) => setMode(mode),
)
```

---

## Responsive Design

### Breakpoint System

```dart
enum ToolBreakpoint {
  compact,   // < 375px (small phones)
  medium,    // 375-599px (standard phones)
  expanded,  // 600-1023px (tablets)
  desktop;   // >= 1024px (desktop)
}
```

### Adaptive Spacing

```dart
ToolSpacing.lg(context)  // 16px (compact), 24px (expanded)
ToolSpacing.xxl(context) // 24px (compact), 48px (expanded)
```

### Adaptive Touch Targets

```dart
ToolTouchTarget.small(context)  // 40-48px
ToolTouchTarget.large(context)  // 48-72px
```

---

## Creating a New Tool

### Step 1: Create Screen File

```dart
// lib/screens/tools/new_tool_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/tools/tools.dart';

class NewToolScreen extends ConsumerStatefulWidget {
  const NewToolScreen({super.key});

  @override
  ConsumerState<NewToolScreen> createState() => _NewToolScreenState();
}

class _NewToolScreenState extends ConsumerState<NewToolScreen> {
  @override
  Widget build(BuildContext context) {
    return ToolScreenScaffold(
      title: 'New Tool',
      menuItems: [
        PopupMenuItem(
          child: const Text('Settings'),
          onTap: _showSettings,
        ),
      ],
      mainWidget: _buildMainControl(),
      secondaryWidget: _buildSecondaryControls(),
      bottomWidget: ToolTransportBar(
        isPlaying: _isPlaying,
        onPlayPause: _togglePlay,
      ),
    );
  }
}
```

### Step 2: Create Provider

```dart
// lib/providers/tools/new_tool_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NewToolState {
  idle,
  active,
}

class NewToolNotifier extends StateNotifier<NewToolState> {
  NewToolNotifier() : super(NewToolState.idle);

  void start() {
    state = NewToolState.active;
  }

  void stop() {
    state = NewToolState.idle;
  }
}

final newToolProvider = StateNotifierProvider<NewToolNotifier, NewToolState>(
  (ref) => NewToolNotifier(),
);
```

### Step 3: Add to Router

```dart
// lib/router/app_router.dart
GoRoute(
  path: '/main/tools/new-tool',
  name: 'new-tool',
  builder: (context, state) => const NewToolScreen(),
),
```

---

## Best Practices

### 1. Widget Composition

Break tools into small, focused widgets:

```dart
// ✅ Good
Column(
  children: [
    TimeSignatureBlock(),
    CentralTempoCircle(),
    FineAdjustmentButtons(),
    BottomTransportBar(),
  ],
)

// ❌ Bad
Column(
  children: [
    // 200 lines of widget tree...
  ],
)
```

### 2. State Management

Use Riverpod for tool state:

```dart
final toolProvider = StateNotifierProvider<ToolNotifier, ToolState>(
  (ref) => ToolNotifier(),
);

// In widget:
final tool = ref.watch(toolProvider.notifier);
final state = ref.watch(toolProvider);
```

### 3. Responsive Layout

Use breakpoint system:

```dart
final breakpoint = ToolBreakpoint.of(context);
final spacing = ToolSpacing.lg(context);
final touchSize = ToolTouchTarget.large(context);
```

### 4. Haptic Feedback

Provide tactile feedback:

```dart
onTap: () {
  HapticFeedback.lightImpact();
  // Action
}
```

### 5. Offline Support

Cache tool settings:

```dart
final settings = await Hive.box('tool_settings').get('metronome');
await Hive.box('tool_settings').put('metronome', newSettings);
```

---

## Migration Guide

### Metronome (Existing)

**Before:**
```dart
Scaffold(
  appBar: CustomAppBar.build(context, title: 'Metronome'),
  body: Column(...),
)
```

**After:**
```dart
ToolScreenScaffold(
  title: 'Metronome',
  menuItems: [...],
  mainWidget: CentralTempoCircle(),
  bottomWidget: BottomTransportBar(),
)
```

### Tuner (Existing)

**Before:**
```dart
Scaffold(
  appBar: CustomAppBar.buildSimple(context, title: 'Tuner'),
  body: Column(...),
)
```

**After:**
```dart
ToolScreenScaffold(
  title: 'Tuner',
  mainWidget: CentralDial(),
  bottomWidget: TransportBar(),
)
```

---

## Future Tools

### Planned Tools

1. **Recorder** - Audio recording and playback
2. **Sound Generator** - Frequency generator for testing
3. **Pitch Pipe** - Reference pitches for instruments
4. **Drum Machine** - Simple drum patterns

### Template

Use this structure for new tools:

```
lib/screens/tools/
├── tool_name_screen.dart
├── tool_name_provider.dart
└── widgets/
    ├── main_control.dart
    ├── secondary_controls.dart
    └── transport_bar.dart
```

---

## Testing

### Widget Tests

```dart
testWidgets('ToolTransportBar shows play button', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ToolTransportBar(
        isPlaying: false,
        onPlayPause: () {},
      ),
    ),
  );
  
  expect(find.byIcon(Icons.play_arrow), findsOneWidget);
});
```

### Integration Tests

```dart
testWidgets('Tool preserves state across orientation', (tester) async {
  await tester.pumpWidget(const ToolScreen());
  
  // Rotate device
  tester.view.physicalSize = const Size(1024, 768);
  
  // State should be preserved
  expect(find.byType(CentralDial), findsOneWidget);
});
```

---

## Resources

- [MonoPulse Theme](../theme/mono_pulse_theme.dart)
- [Responsive Design](tool_scaffold.dart)
- [State Management](../../providers/tools/)

---

**Last Updated:** February 28, 2026  
**Version:** 1.0.0
