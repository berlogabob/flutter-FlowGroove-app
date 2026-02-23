# Mono Pulse Design System
**Flutter RepSync App - Visual Design Implementation**

---

## Core Philosophy

**Clean. Confident. Premium-minimal.**

> "Expensive Swedish hi-fi brand meets banking fintech that doesn't need to prove anything anymore."

### Inspirations
- **Teenage Engineering** — Raw prototype honesty, Scandinavian restraint
- **Nothing** — Monochromatic base + bold accent courage
- **Notion** — Content-first clarity, hierarchy through space
- **Revolut** — Banking-grade confidence, razor-sharp precision

---

## Color System

### Strict Monochrome + One Hero Accent

#### Base - True Black
```dart
static const Color black = Color(0xFF000000);
static const Color blackSurface = Color(0xFF0A0A0A);
static const Color blackElevated = Color(0xFF111111);
```

#### Surface / Cards
```dart
static const Color surface = Color(0xFF121212);
static const Color surfaceRaised = Color(0xFF1A1A1A);
static const Color surfaceOverlay = Color(0xFF1E1E1E);
```

#### Borders & Dividers
```dart
static const Color borderSubtle = Color(0xFF222222);
static const Color borderDefault = Color(0xFF333333);
static const Color borderStrong = Color(0xFF444444);
```

#### Text
```dart
// Primary
static const Color textPrimary = Color(0xFFF5F5F5);
static const Color textHighEmphasis = Color(0xFFEDEDED);

// Secondary
static const Color textSecondary = Color(0xFFA0A0A5);
static const Color textTertiary = Color(0xFF8A8A8F);
static const Color textDisabled = Color(0xFF555555);
```

#### Brand Accent - Orange (Used Surgically)
```dart
static const Color accentOrange = Color(0xFFFF5E00);
static const Color accentOrangeLight = Color(0xFFFF6B1A);
static const Color accentOrangeDark = Color(0xFFE64E00);
static const Color accentOrangeSubtle = Color(0x1AFF5E00); // 10% opacity
```

#### Error & Success
```dart
// Error - Muted Red (very rare)
static const Color error = Color(0xFFFF2D55);
static const Color errorSubtle = Color(0x1AFF2D55);

// Success - Orange or White
static const Color success = accentOrange;
static const Color successAlt = textPrimary;
```

---

## Typography

### Inter / System SF Pro
**Strict 4-point grid scale**

#### Display - Hero Titles Only
```dart
static const TextStyle displayLarge = TextStyle(
  fontSize: 40,
  fontWeight: FontWeight.w600,
  height: 1.32,
  letterSpacing: -0.5,
);

static const TextStyle displayMedium = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.w600,
  height: 1.35,
  letterSpacing: -0.25,
);
```

#### Headings
```dart
static const TextStyle headlineLarge = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w600,
  height: 1.38,
);

static const TextStyle headlineMedium = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w600,
  height: 1.4,
);

static const TextStyle headlineSmall = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  height: 1.45,
);
```

#### Body
```dart
static const TextStyle bodyLarge = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  height: 1.45,
);

static const TextStyle bodyMedium = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  height: 1.43,
);

static const TextStyle bodySmall = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.33,
);
```

#### Labels / Buttons
```dart
static const TextStyle labelLarge = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  height: 1.43,
  letterSpacing: 0.1,
);

static const TextStyle labelMedium = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  height: 1.33,
  letterSpacing: 0.5,
);

static const TextStyle labelSmall = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w500,
  height: 1.45,
  letterSpacing: 0.5,
);
```

---

## Spacing

### 4-Point Grid System
**Generous padding for negative space**

```dart
static const double xs = 4;
static const double sm = 8;
static const double md = 12;
static const double lg = 16;
static const double xl = 20;
static const double xxl = 24;
static const double xxxl = 32;
static const double huge = 40;
static const double massive = 48;
```

### Usage Guidelines
- **Screen padding:** 24-48px (xxl-massive)
- **Card padding:** 16-24px (lg-xxl)
- **Button padding:** 16x12px (lg-md)
- **Element spacing:** 8-16px (sm-lg)

---

## Border Radius

```dart
static const double small = 8;    // Small elements, chips
static const double medium = 10;  // Input fields
static const double large = 12;   // Cards, buttons
static const double xlarge = 16;  // FAB, large panels
static const double huge = 20;    // Hero panels
static const double massive = 24; // Large containers
```

---

## Elevation & Shadows

### Very Soft, Subtle Depth
```dart
static BoxShadow shadowLow = BoxShadow(
  color: Colors.black.withValues(alpha: 0.3),
  blurRadius: 8,
  offset: const Offset(0, 2),
);

static BoxShadow shadowMedium = BoxShadow(
  color: Colors.black.withValues(alpha: 0.4),
  blurRadius: 16,
  offset: const Offset(0, 4),
);

static BoxShadow shadowHigh = BoxShadow(
  color: Colors.black.withValues(alpha: 0.5),
  blurRadius: 24,
  offset: const Offset(0, 8),
);
```

---

## Animation & Motion

### Short (120-180ms), Buttery-Smooth
```dart
static const Duration durationShort = Duration(milliseconds: 120);
static const Duration durationMedium = Duration(milliseconds: 180);
static const Duration durationLong = Duration(milliseconds: 240);

static const Curve curveDefault = Curves.easeOut;
static const Curve curveEmphasized = Curves.easeOutCubic;
static const Curve curveCustom = Cubic(0.4, 0.0, 0.2, 1.0);
```

### Principles
- **Purposeful** — Never decorative
- **Restrained** — Nothing bounces or overshoots
- **Alive** — Butter-smooth easing

---

## Icons

### 1.5-2px Line Weight
```dart
static const double sizeSmall = 16;
static const double sizeMedium = 20;
static const double sizeLarge = 24;
static const double sizeXLarge = 32;

static const double strokeWidthDefault = 1.5;
static const double strokeWidthBold = 2.0;
```

### Usage
- **Outline preferred** — Filled only on active/hero states
- **Consistent stroke** — 1.5px default, 2px bold
- **No decorative icons** — Functional only

---

## What We Avoid

❌ Rainbow / multi-color accents  
❌ Large illustrations or 3D assets  
❌ Glassmorphism / heavy blur  
❌ Cyberpunk / neon / retro overload  
❌ Cute / playful microcopy elements  
❌ Excessive motion / parallax  
❌ Warm off-whites or light mode  
❌ Gradients (except subtle vignette)  
❌ Textures, noise, skeuomorphism  

---

## Implementation

### Usage in Code

```dart
import 'package:flutter_repsync_app/theme/mono_pulse_theme.dart';

// Colors
Container(
  color: MonoPulseColors.surface,
  child: Text(
    'Hello',
    style: MonoPulseTypography.bodyLarge.copyWith(
      color: MonoPulseColors.textPrimary,
    ),
  ),
);

// Spacing
Padding(
  padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
  child: SizedBox(height: MonoPulseSpacing.xxxl),
);

// Radius
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(MonoPulseRadius.large),
    border: Border.all(color: MonoPulseColors.borderDefault),
  ),
);

// Animation
AnimatedContainer(
  duration: MonoPulseAnimation.durationMedium,
  curve: MonoPulseAnimation.curveCustom,
  // ...
);
```

### Theme Application

```dart
// In main.dart
MaterialApp(
  theme: MonoPulseTheme.theme,
  darkTheme: MonoPulseTheme.theme,
  themeMode: ThemeMode.dark, // Dark-only
)
```

---

## Design Gut-Check Questions

Before shipping any screen, ask:

1. **Does it breathe?** — Enough negative space?
2. **Is it confident?** — Doesn't shout, quietly owns the screen
3. **Is it restrained?** — Orange used surgically?
4. **Is it sharp?** — Razor-sharp precision?
5. **Does it feel expensive?** — Premium minimalism?

> "Expensive Swedish hi-fi brand meets banking fintech that doesn't need to prove anything anymore."

---

## Files

| File | Purpose |
|------|---------|
| `lib/theme/mono_pulse_theme.dart` | Complete theme implementation |
| `documentation/brandbook.md` | Original design brief |
| `documentation/MONO_PULSE_GUIDE.md` | This guide |

---

**Status:** ✅ Implemented  
**Version:** 0.10.1+2  
**Theme:** Dark-only (as per brandbook)

---

**Last Updated:** 2026-02-23
