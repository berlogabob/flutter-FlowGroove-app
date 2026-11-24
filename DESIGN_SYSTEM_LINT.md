# FlowGroove Design System Rules

These rules keep the app recognizable as a shared rehearsal notebook and protect scanability during performance.

## Use shared tokens

- Add or update brand colors in `lib/theme/mono_pulse_theme.dart`; avoid new hex literals in feature widgets.
- Read theme-dependent neutrals through `context.mp`.
- Keep status and song-section colors semantically distinct from the brand palette.
- Use `MonoPulseSpacing`, `MonoPulseRadius`, and `MonoPulseTypography` for shared values while those public identifiers remain in use. Tokens are defined in `design/tokens/tokens.json` and generated with `python3 design/tokens/tokens.py gen`; do not edit `lib/theme/mono_pulse_tokens.g.dart` by hand.
- No raw numbers for padding, gaps, radius or font size, and no `Color(0x...)` or `Colors.*` in `lib/`. An intentional exception is a line ending in `// ds-allow: <reason>`, or an entry with a reason in `design/raw_allow.txt`.

## Component boundaries

- Use `AppCard` for grouped panels instead of inventing new generic bordered cards.
- Use `CustomButton` for primary, secondary, outline, and text actions.
- Use `QuickActionButton` for dashboard launch tiles.
- Use `ToolButton` for dashboard tool launch tiles and `StatCard` for compact library readouts.
- Use `AppFilterChip` for filter selection.
- Use `CustomTextField` for text inputs, `AppDropdownField` for dropdowns and `LabeledField` / `FieldLabel` for any other labelled input. Labels sit above the field; do not use `labelText` or floating labels.
- Use `AppBadge` (or `AppBadge.solid`) for pills.
- Build UI only from design-system components and tokens. Do not hand-build a look-alike widget.
- Add new shared patterns to `lib/widgets/` and demonstrate them on the debug-only design-system screen.

## Visual rules

1. Paper is the default light workspace; charcoal is the dark instrument face.
2. Reserve signal orange for playing, selected and the one main action of a screen, such as Play or Save. Text buttons use the text colour, never orange. Sibling actions share one button style. Use Stone or Fog with dark labels for selected controls, white for inactive controls and enabled inputs, Stone/Fog for disabled inputs, and gray for secondary information.
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

## Frames and guards

- The app follows the approved frames in `design/figcraft/specs/`. A control the app has is never removed to match a frame; redraw the frame.
- A state change never changes geometry (stable layout S1 to S5).
- `make design-guard` runs on every commit and in CI: it checks stable layout, the surface inventory, the metric ratchets, loosened gates, and raw values in added lines (`design/diff_lint.py`).
- A change to a frame, a spec, `design/tokens/tokens.json` or a locked line of `design/parity_lock.txt` needs a `Design-Approved: <who, when>` line in the commit message.
- Run `make design-parity` to render each real screen and compare it with its frame. Details: `design/figcraft/SPEC.md`.

## Validation

Format and analyze the files touched by a visual-system change:

```sh
dart format <touched Dart files>
flutter analyze <touched Dart files>
flutter test <focused widget or component test>
```

Review the affected screen at phone and wide layouts. Do not treat the static design-system page as a replacement for checking the real feature screen.
