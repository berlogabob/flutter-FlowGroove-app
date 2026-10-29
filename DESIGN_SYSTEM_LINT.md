# FlowGroove Design System Rules

These rules keep the app recognizable as a shared rehearsal notebook and protect scanability during performance.

## Use shared tokens

- Add or update brand colors in `lib/theme/mono_pulse_theme.dart`; avoid new hex literals in feature widgets.
- Read theme-dependent neutrals through `context.mp`.
- Keep status and song-section colors semantically distinct from the brand palette.
- Use `MonoPulseSpacing`, `MonoPulseRadius`, and `MonoPulseTypography` for shared values while those public identifiers remain in use.

## Component boundaries

- Use `AppCard` for grouped panels instead of inventing new generic bordered cards.
- Use `CustomButton` for primary, secondary, outline, and text actions.
- Use `QuickActionButton` for dashboard launch tiles.
- Use `ToolButton` for dashboard tool launch tiles and `StatCard` for compact library readouts.
- Use `AppFilterChip` for filter selection.
- Add new shared patterns to `lib/widgets/` and demonstrate them on the debug-only design-system screen.

## Visual rules

1. Paper is the default light workspace; charcoal is the dark instrument face.
2. Reserve signal orange for one primary action in a screen, such as Play or Save. Use Stone or Fog with dark labels for selected controls, white for inactive controls and enabled inputs, Stone/Fog for disabled inputs, and gray for secondary information.
3. Use raised surfaces for physical control plates and song-data groupings; keep ordinary lists calm.
4. Marcellus is for headings, Source Serif 4 for prose and musical content, and Arial-style text for controls.
5. Keep body copy and labels readable. Do not shrink labels to fit; reflow or simplify.
6. Use compact, deliberate corners and crisp edges. Avoid pill-shaped everything and soft floating-card stacks.
7. Keep song structure, tempo, key, meter, and lyrics easy to scan at rehearsal distance.

## Interaction and accessibility

- Preserve current routing, state, persistence, audio, and sync behavior when changing presentation.
- Icon-only actions require an accessible name and tooltip.
- Provide visible focus and disabled states. Color must not be the only status cue.
- Maintain touch targets of at least 48 logical pixels where practical.
- Check contrast in both light and dark variants.

## Validation

Format and analyze the files touched by a visual-system change:

```sh
dart format <touched Dart files>
flutter analyze <touched Dart files>
flutter test <focused widget or component test>
```

Review the affected screen at phone and wide layouts. Do not treat the static design-system page as a replacement for checking the real feature screen.
