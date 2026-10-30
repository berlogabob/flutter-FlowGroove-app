# FlowGroove app design system

The interface is a shared music notebook: warm paper for the workspace, charcoal for instrument faces, and clear orange for the active action. Controls should feel like real hardware or well-used rehearsal notes rather than generic SaaS cards.

## Brand tokens

| Role | Token | Value | Use |
|---|---|---|---|
| Workspace | Paper | `#F6F5F0` | Default light background |
| Panel | Stone | `#D8D6CC` | Raised plates and selected controls |
| Quiet detail | Fog | `#B5B2A8` | Dividers, subdued details, and selected controls |
| Natural accent | Sage | `#8A907F` | Supportive status and illustration accents |
| Supporting accent | Petrol | `#285E6E` | Restrained supporting labels and metadata |
| Instrument face | Charcoal | `#1E1E1C` | Dark mode and strong text |
| Main action | Signal orange | `#FF5A36` | Play, save, or the primary action |

Status colors remain distinct from brand colors so success, warnings, and errors stay unambiguous. Orange is reserved for the main action and should not spread across secondary controls or informational blocks.

## Type roles

- **Marcellus** — screen titles and section headings. Keep headings short and sign-like.
- **Source Serif 4** — song details, lyrics, notes, and explanatory copy.
- **Arial-style sans serif** — button labels, navigation, and compact controls.

These roles are configured through `MonoPulseTypography` and the shared app theme. Google Fonts are loaded through the existing `google_fonts` package; no manual font installation is required for Flutter feature screens. Use readable sizes and comfortable line height. Secondary information may be quieter, but should not be reduced to tiny decorative text.

## Shared component patterns

### Surfaces and cards

Use `AppCard` for grouped content. The `surface` variant creates a flush paper or charcoal panel; `raised` creates a bordered plate with a crisp lower edge and soft grounding shadow. Use these for song information, settings sections, and dashboard modules. Reserve orange fills for the active song, transport, or one clear call to action.

### Buttons and actions

Use `CustomButton` variants for actions. Keep the primary action orange and singular. Secondary actions use a white face with charcoal text and outline. Add a meaningful icon to add or attach actions, such as a plus for “Add recording.” Use the hardware transport components for play, stop, back, and next controls.

### Selection controls

Use `AppFilterChip` for section selectors and button-like checkboxes. Selected controls use Stone or Fog with dark labels and a subtle drop shadow; inactive controls use white. Do not add a checkmark: the surface treatment communicates selection. Color should not be the only status cue.

### Inputs

Use `CustomTextField` for labeled form inputs. Enabled inputs have a white background; disabled inputs use Stone. Keep focus, error, and disabled states visible and accessible.

### Setlist information

Use `SetlistSongRow` and `SetlistBreakRow` for setlist entries. Preserve comfortable right padding for song rows. Breaks and other secondary information use quiet gray styling and sentence case rather than orange.

## Copy and accessibility

- Prefer sentence case. Reserve capitals for standard abbreviations such as BPM and short hardware readouts.
- Keep song structure, tempo, key, meter, and lyrics easy to scan at rehearsal distance.
- Keep labels and body copy readable; reflow or simplify instead of shrinking text to fit.
- Retain semantic labels, tooltips, visible focus states, and minimum 48 logical pixel touch targets where practical.
- Maintain readable contrast in light and dark themes.
- Brand styling must not change navigation, song data, audio, sync, or persistence behavior.

## Using the system in a feature screen

1. Keep the existing `MonoPulse*` public identifiers for compatibility. Add shared palette, type, spacing, or radius values in `lib/theme/mono_pulse_theme.dart` instead of hard-coding colors in feature screens.
2. Use `context.mp` for theme-dependent workspace, surface, border, and text colors. Use brand constants such as `MonoPulseColors.accentOrange` only for the primary action and established semantic accents.
3. Build grouped surfaces with `AppCard`; choose `surface` for flush groups and `raised` for tactile plates.
4. Use `CustomButton`, `CustomTextField`, `AppFilterChip`, `SetlistSongRow`, and `SetlistBreakRow` for consistent existing patterns. The API reference is in [COMPONENT_LIBRARY.md](COMPONENT_LIBRARY.md).
5. Keep interface copy in sentence case and use tokens instead of one-off colors and typography.

## Preview and focused checks

Run the standalone reference without initializing Firebase or signing in:

```bash
flutter run -d chrome -t tool/design_system_preview.dart
```

The reference includes palette and type samples, controls, song data, rules, and interactive setlist, song, and add-song examples. The same screen is reachable from Settings in debug builds only.

Focused coverage:

```bash
flutter test test/screens/settings/design_system_screen_test.dart
```

Format and analyze the files touched by a visual-system change. Review the affected feature screen at phone and wide layouts; the static reference complements that review rather than replacing it.

## Source of truth

- Tokens and typography: `lib/theme/mono_pulse_theme.dart` (legacy class name retained for migration compatibility).
- Shared patterns: the reusable widget files under `lib/widgets/`.
- Visual examples: `lib/screens/settings/design_system_screen.dart` and `lib/screens/settings/design_system_screen_examples.dart`.
- Standalone preview entry: `tool/design_system_preview.dart`.
