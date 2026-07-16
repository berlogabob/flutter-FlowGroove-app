# Mono Pulse Component Library

**Shared, reusable components built on the design system.**

---

## CustomButton

Reusable button with variants, sizes, and consistent styling.

**Location:** `lib/widgets/custom_button.dart`

### Props
- `label` (String, required) — Button text
- `onPressed` (VoidCallback?) — Tap handler
- `variant` (ButtonVariant) — `primary`, `secondary`, `outline`, `text`
- `size` (ButtonSize) — `small`, `medium`, `large`
- `isLoading` (bool) — Shows spinner, disables interaction
- `icon` (IconData?) — Optional icon before label
- `fullWidth` (bool) — Expands to available width
- `tooltip` (String?) — Hover message
- `semanticLabel` (String?) — Screen reader label (defaults to label text)

### Usage
```dart
CustomButton(
  label: 'Save',
  variant: ButtonVariant.primary,
  size: ButtonSize.medium,
  onPressed: _handleSave,
  tooltip: 'Save changes',
  semanticLabel: 'Save song changes',
)

// With loading state
CustomButton(
  label: 'Upload',
  isLoading: _isUploading,
  onPressed: _isUploading ? null : _handleUpload,
)

// Secondary variant
CustomButton(
  label: 'Cancel',
  variant: ButtonVariant.secondary,
  onPressed: Navigator.of(context).pop,
)
```

### Accessibility
- ✅ All buttons labeled with semanticLabel
- ✅ Tooltip on hover/long-press
- ✅ Loading state disables interaction
- ✅ Minimum tap target (48×48px via Material)

---

## CustomTextField

Input field with label, hint, validation, and consistent styling.

**Location:** `lib/widgets/custom_text_field.dart`

### Props
- `label` (String?) — Label above field
- `hint` (String?) — Placeholder when empty
- `controller` (TextEditingController?) — Input controller
- `onChanged` (ValueChanged<String>?) — On text change
- `validator` (Function?) — Form validation
- `required` (bool) — Shows red * on label
- `keyboardType` (TextInputType) — Numeric, email, etc.
- `obscureText` (bool) — Password field
- `maxLines` (int?) — Single line (1) or multi-line
- `prefixIcon` (IconData?) — Icon before input
- `suffix` (Widget?) — Widget after input (e.g., clear button)
- `readOnly` (bool) — Disable editing
- `onFocus` / `onBlur` (VoidCallback?) — Focus callbacks

### Usage
```dart
CustomTextField(
  label: 'Song Name',
  hint: 'Enter song title',
  controller: _nameController,
  required: true,
  onChanged: (value) => setState(() => _songName = value),
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
)

// Password field
CustomTextField(
  label: 'Password',
  obscureText: true,
  keyboardType: TextInputType.visiblePassword,
  onChanged: (value) => setState(() => _password = value),
)

// Email field
CustomTextField(
  label: 'Email',
  keyboardType: TextInputType.emailAddress,
  prefixIcon: Icons.email,
)
```

### Accessibility
- ✅ Label associated with field
- ✅ Required indicator (*) shown when needed
- ✅ Error messages read by screen readers

---

## AppIconButton

Accessible icon button with built-in semantics and tooltip.

**Location:** `lib/widgets/app_icon_button.dart`

### Props
- `icon` (IconData, required) — Icon to display
- `label` (String, required) — Semantic label + tooltip text
- `onPressed` (VoidCallback?) — Tap handler
- `size` (double) — Icon size (default: MonoPulseIcons.sizeMedium = 20)
- `color` (Color?) — Icon color (default: textSecondary)
- `padding` (EdgeInsetsGeometry?) — Padding around icon (default: 12px all, = 48×48 min tap)

### Usage
```dart
AppIconButton(
  icon: Icons.edit,
  label: 'Edit song',
  onPressed: _handleEdit,
)

// With custom color
AppIconButton(
  icon: Icons.delete,
  label: 'Delete song',
  onPressed: _handleDelete,
  color: MonoPulseColors.error,
)

// Larger icon for prominent actions
AppIconButton(
  icon: Icons.add,
  label: 'Add new song',
  size: MonoPulseIcons.sizeLarge, // 24px
  onPressed: _handleAdd,
)
```

### Accessibility
- ✅ Semantic label for screen readers
- ✅ Tooltip on hover/long-press
- ✅ Minimum tap target (48×48px)
- ✅ `enabled: false` when onPressed is null

---

## EmptyState

Displays a message when no content is available.

**Location:** `lib/widgets/empty_state.dart`

### Props
- `icon` (IconData) — Icon (excluded from semantics)
- `message` (String) — Main message
- `hint` (String?) — Secondary hint
- `actionLabel` (String?) — Button label
- `onAction` (VoidCallback?) — Button tap handler
- `iconColor` (Color?) — Icon color
- `iconSize` (double) — Icon size

### Factory Constructors
- `EmptyState.songs({onAdd})` — Pre-configured for empty song list
- `EmptyState.bands({onCreate})` — Pre-configured for empty band list
- `EmptyState.setlists({onCreate})` — Pre-configured for empty setlist list
- `EmptyState.search({query})` — Pre-configured for search results

### Usage
```dart
// Generic
EmptyState(
  icon: Icons.inbox,
  message: 'No messages',
  hint: 'You haven\'t received any messages yet',
  actionLabel: 'Compose',
  onAction: _handleCompose,
)

// Using factory
EmptyState.songs(onAdd: () => Navigator.push(...))

// In a ListView
ListView(
  children: [
    if (_songs.isEmpty)
      EmptyState.songs(onAdd: _handleAddSong)
    else
      ..._songs.map((song) => SongCard(song: song)),
  ],
)
```

### Accessibility
- ✅ Icon marked `excludeSemantics: true` (message is the semantic description)
- ✅ Main message read by screen readers
- ✅ Action button has label and semantic focus
- ✅ Minimum 48px button tap targets

---

## ErrorBanner

Displays error messages with optional retry action.

**Location:** `lib/widgets/error_banner.dart`

### Variants
- `ErrorBanner.banner()` — Full-width banner (top of screen)
- `ErrorBanner.card()` — Card-style with icon
- `ErrorBanner.inline()` — Inline error with small icon

### Props
- `message` (String) — Error message
- `onRetry` (VoidCallback?) — Retry button handler (optional)

### Usage
```dart
// Banner (for page-level errors)
ErrorBanner.banner(
  message: 'Failed to load songs',
  onRetry: _handleRetry,
)

// Card (for dialogs or cards)
ErrorBanner.card(
  message: 'Network connection lost',
  onRetry: _reconnect,
)

// Inline (for form fields)
if (_hasError)
  ErrorBanner.inline(message: 'Invalid email address')
```

### Accessibility
- ✅ Semantic label with message
- ✅ Icon color indicates error state (red)
- ✅ Retry button labeled and tappable (48px min)

---

## LoadingIndicator

Displays loading spinner with optional message.

**Location:** `lib/widgets/loading_indicator.dart`

### Props
- `size` (double) — Spinner diameter (default: 40)
- `color` (Color?) — Spinner color (default: accentOrange)
- `message` (String?) — Message below spinner
- `messageStyle` (TextStyle?) — Message text style
- `semanticsLabel` (String) — Screen reader label (default: "Loading")

### Usage
```dart
// Default spinner
LoadingIndicator()

// With message
LoadingIndicator(
  message: 'Uploading song...',
)

// Custom color
LoadingIndicator(
  color: MonoPulseColors.success,
  message: 'Processing...',
)
```

### Accessibility
- ✅ Semantic label for screen readers (customizable)
- ✅ Message text read as description

---

## Card

Flutter's built-in `Card` widget with Mono Pulse theme applied automatically.

**Styling (via theme):**
- Color: `MonoPulseColors.surface`
- Elevation: 0 (flat design)
- Border: 1px `MonoPulseColors.borderSubtle`
- Radius: `MonoPulseRadius.large` (12px)
- Shadow: soft drop shadow

### Usage
```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(MonoPulseSpacing.lg),
    child: Column(
      children: [
        Text('Title', style: MonoPulseTypography.headlineSmall),
        SizedBox(height: MonoPulseSpacing.md),
        Text('Content', style: MonoPulseTypography.bodyMedium),
      ],
    ),
  ),
)
```

---

## Typography

All text uses `MonoPulseTypography` presets. Do **not** use raw `fontSize` or `TextStyle` literals.

**Available styles:**
```dart
MonoPulseTypography.displayLarge    // 40px, bold, hero title
MonoPulseTypography.displayMedium   // 32px, bold
MonoPulseTypography.headlineLarge   // 24px, semibold
MonoPulseTypography.headlineMedium  // 20px, semibold
MonoPulseTypography.headlineSmall   // 16px, semibold
MonoPulseTypography.titleLarge      // 22px, semibold
MonoPulseTypography.titleMedium     // 16px, semibold
MonoPulseTypography.bodyLarge       // 16px, regular
MonoPulseTypography.bodyMedium      // 14px, regular
MonoPulseTypography.bodySmall       // 12px, regular
MonoPulseTypography.labelLarge      // 14px, medium (buttons)
MonoPulseTypography.labelMedium     // 12px, medium
MonoPulseTypography.labelSmall      // 11px, medium
```

### Usage
```dart
// Good
Text('Songs', style: MonoPulseTypography.headlineLarge)

// Bad (raw fontSize)
Text('Songs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600))

// Customization: use .copyWith()
Text(
  'Important',
  style: MonoPulseTypography.bodyMedium.copyWith(
    color: MonoPulseColors.error,
    fontWeight: FontWeight.w700,
  ),
)
```

---

## Spacing

Use `MonoPulseSpacing` tokens for all padding/margin. Do **not** use raw numeric values.

```dart
MonoPulseSpacing.xxs = 2px
MonoPulseSpacing.xs = 4px
MonoPulseSpacing.sm = 8px
MonoPulseSpacing.md = 12px
MonoPulseSpacing.lg = 16px
MonoPulseSpacing.xl = 20px
MonoPulseSpacing.xxl = 24px
MonoPulseSpacing.xxxl = 32px
MonoPulseSpacing.huge = 40px
MonoPulseSpacing.massive = 48px
```

### Usage
```dart
// Good
Padding(
  padding: EdgeInsets.symmetric(
    horizontal: MonoPulseSpacing.lg,
    vertical: MonoPulseSpacing.md,
  ),
  child: child,
)

// Bad (raw numeric)
Padding(padding: EdgeInsets.all(16), child: child)
```

---

## Colors

Use `MonoPulseColors` for all color references. Never use `Colors.*` outside `mono_pulse_theme.dart`.

**Text colors:**
```dart
MonoPulseColors.textPrimary       // Main text (#F5F5F5)
MonoPulseColors.textSecondary     // Secondary (#A0A0A5)
MonoPulseColors.textTertiary      // Tertiary (#8A8A8F)
MonoPulseColors.textDisabled      // Disabled (#555555)
```

**Surface colors:**
```dart
MonoPulseColors.black             // #000000
MonoPulseColors.surface           // Card background (#121212)
MonoPulseColors.surfaceRaised     // Elevated surface (#1A1A1A)
```

**Accent:**
```dart
MonoPulseColors.accentOrange      // Primary brand (#FF5E00)
MonoPulseColors.accentOrange10    // 10% opacity overlay
MonoPulseColors.accentOrange15    // 15% opacity
MonoPulseColors.accentOrange20    // 20% opacity
MonoPulseColors.accentOrange30    // 30% opacity
```

**Status:**
```dart
MonoPulseColors.error             // Red (#FF2D55)
MonoPulseColors.error10           // Error @ 10%
MonoPulseColors.success           // Orange (same as accentOrange)
MonoPulseColors.successGreen      // Green (#4CAF50)
MonoPulseColors.warning           // Orange (#FF9800)
MonoPulseColors.info              // Blue (#2196F3)
```

---

## Contributing

When adding new components:
1. ✅ Use `MonoPulseColors`, `MonoPulseSpacing`, `MonoPulseTypography`, `MonoPulseRadius` tokens
2. ✅ Add `semanticsLabel` or wrap with `Semantics` for interactive elements
3. ✅ Ensure minimum tap target 48×48px for buttons
4. ✅ Document props, variants, usage, and a11y notes
5. ✅ Run `flutter analyze` to catch lint violations
6. ✅ Update this file with the new component


## AppBottomBar

`lib/widgets/bottom_nav_or_action_bar.dart` — the app's single bottom bar (there is no top app bar).

### Modes
- `AppBottomBar.tabs(tabs:, selectedIndex:, onTabTap:, onMenuTap:, menuSelected:, menuHasBadge:)` — root mode: 4 nav tabs + the ⋮ Menu slot (dot badge when the screen published actions).
- `AppBottomBar.actions({required onBack, title, primaryAction, onMenu})` — pushed mode: `[← Back][title|primaryAction][⋮]`. `primaryAction` wins the center slot; ⋮ renders only when `onMenu != null`.

### Rules
- One bar per screen. Root-pushed screens (tools, join-band) instantiate `.actions` themselves; shell branches get it from `MainShell`.
- All items carry `Semantics(button:, label:)`.

## AppMenuItem / showAppMenuSheet

`lib/widgets/app_menu_sheet.dart` — the contextual menu bottom sheet (replaces PopupMenuButton app-wide).

### Props
- `AppMenuItem(icon, label, onTap, {destructive, trailing})` — `trailing` (e.g. a `Switch`) keeps the sheet OPEN and runs `onTap` in place; rows without it close the sheet, then run `onTap` post-frame.
- `showAppMenuSheet(context, {required title, required items, showProfileRow, ref})` — the `title` header is mandatory (audit P1-2: sheets without context confused users). `showProfileRow` appends the avatar+name Profile row (root mode only).

## MenuScopePublisher / MenuScopeRegistry

`lib/widgets/menu_items_scope.dart` — how screens tell the shell what the bar/sheet should show.

### Usage
Wrap the screen (StandardScreenScaffold does it automatically): `MenuScopePublisher(data: MenuScopeData(title:, items:, primaryAction:), child: ...)`. Publications are post-frame only — never write during build (screen-blanking regression class). Location captured once on first didChangeDependencies.

## SetlistSongRow

`lib/widgets/setlist_song_row.dart` — shared setlist row used by both the read-only view and the editor. Pass `song: null` to render the "Unavailable song" placeholder for orphaned entries (never silently drop an entry — audit P0-4).

## showAppSnackBar (undo support)

`lib/utils/snackbar.dart` — `showAppSnackBar(context, message, {error, actionLabel, onAction, analyticsAction})`. With `actionLabel`/`onAction` it renders a 5s SnackBar action — the app's single-level undo pattern (section delete, setlist delete, setlist-song removal, practice unload). `analyticsAction` logs `undo_shown`/`undo_used`. Member removal must NOT use this (server-authoritative; keep a confirm dialog).
