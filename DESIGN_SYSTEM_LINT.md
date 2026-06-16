# Design System Lint Enforcement

**Phase 6 of Mono Pulse Remediation Plan**

---

## Automated Lint Rules (flutter analyze)

The following patterns trigger lint warnings. These are enforced via the existing lint suite in `analysis_options.yaml`:

### Raw Values (Design System Tokens)

**Pattern:** Numeric literals for spacing, radius, sizing  
**Rule:** `use_named_constants` + manual `flutter analyze`  
**Examples:**
```dart
// ❌ Bad: Raw numeric value
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)

// ✅ Good: Uses token
padding: const EdgeInsets.symmetric(
  horizontal: MonoPulseSpacing.lg,
  vertical: MonoPulseSpacing.md,
)
```

**Enforcement:** Run `flutter analyze` on every CI build (see CI config below).

---

### Colors

**Pattern:** `Colors.*` or raw `Color(0x...)` literals (except in theme definitions)  
**Rule:** No global Color constants outside `mono_pulse_theme.dart`  
**Examples:**
```dart
// ❌ Bad: Raw Colors.white usage
child: Text('Error', style: TextStyle(color: Colors.white))

// ✅ Good: Uses MonoPulseColors
child: Text('Error', style: TextStyle(color: MonoPulseColors.textPrimary))
```

**Enforcement:** Grep gate in CI (see below).

---

### Icon Buttons & Custom Tap Targets

**Pattern:** `IconButton` without label/tooltip OR `GestureDetector` without `Semantics`  
**Rule:** All icon-only controls must have `label` param or be wrapped with `Semantics(button: true, label:)` + `Tooltip`

**Recommended:** Use `AppIconButton` helper instead of raw `IconButton`:
```dart
// ❌ Bad: IconButton with no label
IconButton(icon: Icon(Icons.edit), onPressed: _handleEdit)

// ✅ Good: AppIconButton helper
AppIconButton(
  icon: Icons.edit,
  label: 'Edit song',
  onPressed: _handleEdit,
)

// ✅ Also acceptable: manual Semantics + Tooltip
Semantics(
  button: true,
  label: 'Edit song',
  child: Tooltip(
    message: 'Edit song',
    child: IconButton(icon: Icon(Icons.edit), onPressed: _handleEdit),
  ),
)
```

---

## CI Enforcement

Add these gates to your CI/CD pipeline (GitHub Actions, GitLab CI, etc.):

### 1. Flutter Analyze (required check)
```bash
flutter analyze lib/
```
**Fails on:** Lint violations in analysis_options.yaml

### 2. Design System Grep Gates

Run these before merging:

```bash
# Catch stray Colors.* usage (fail if found)
grep -r "Colors\." lib/ --include="*.dart" \
  --exclude-dir=generated \
  | grep -v "mono_pulse_theme.dart" \
  && echo "ERROR: Found Colors.* outside theme" && exit 1

# Catch raw Color(0x...) hex literals
grep -r "Color(0x" lib/ --include="*.dart" \
  | grep -v "mono_pulse_theme.dart" \
  && echo "ERROR: Found raw Color(0x...) literal" && exit 1

# Catch raw SizedBox numeric widths/heights (sample)
grep -r "SizedBox(width: [0-9]" lib/ --include="*.dart" \
  | grep -v MonoPulseSpacing \
  && echo "WARNING: SizedBox with raw numeric width" || true
```

### 3. Example GitHub Actions Workflow

```yaml
name: Design System Lint

on: [pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2

      - name: Flutter Analyze
        run: flutter analyze lib/

      - name: No Colors.* outside theme
        run: |
          ! grep -r "Colors\." lib/ --include="*.dart" \
            | grep -v "mono_pulse_theme.dart"

      - name: No raw Color(0x...) hex
        run: |
          ! grep -r "Color(0x" lib/ --include="*.dart" \
            | grep -v "mono_pulse_theme.dart"
```

---

## Deprecated Token Cleanup

The following tokens are marked `@Deprecated` and should be removed once all callers are migrated:

- `orangeSubtle15`, `orangeSubtle20`, `orangeSubtle30` → use `accentOrange15/20/30`
- `accentOrangeSubtle` → use `accentOrange10`
- `errorSubtle` → use `error10`
- `errorSubtle5/20/30` → use `error5/20/30`
- `successGreenSubtle` → use `successGreen5`
- `warningSubtle` → use `warning5`
- `infoSubtle` → use `info5`

**Schedule for Phase 7 (future):** Run `flutter pub upgrade` to pick up new versions, then grep for deprecated token usage and migrate remaining callers.

---

## Component Documentation

See `COMPONENT_LIBRARY.md` for documentation on shared components, variants, states, and a11y notes.
