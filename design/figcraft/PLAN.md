# Design system plan (FigCraft ↔ FlowGroove)

Full plan: ~/.claude/plans/clever-baking-axolotl.md. Order: 1 → 3.1–3.3 → 2 → 3.4–3.5 → 4.

## Phase 1: tokens, one file, two directions
- [x] `design/tokens/tokens.json` holds the tokens:
  - 82 colours (aliases kept) and 14 palette pairs;
  - fonts, weights and 13 type styles;
  - spacing, radius, elevation, icon, border and shadow values.
  It equals a bootstrap of the old theme (`tokens.py bootstrap <235db715 theme>`).
- [x] `lib/theme/mono_pulse_tokens.g.dart` is generated (`tokens.py gen`) as a `part` of `mono_pulse_theme.dart`. The same class names and members are kept, so no call site changed. `tokens.py check` fails when the generated file is stale.
- [x] Radius literals are named: `MonoPulseRadius.button` (5), `.fab` (6), `.card` (7, AppCard) and `.cardMaterial` (6, Material card theme; differs from AppCard, so kept as its own token).
- [x] `build.py` reads `tokens.json`; the hard-coded PALETTE, BRAND, TYPE, SPACING and RADII dicts are gone.
  - Text styles now carry line height and letter spacing.
  - Variables carry the Dart name as code syntax and description.
  - Alias colours are FigCraft aliases. A palette target aliases in Dark mode only, because Dart means the fixed dark constant there.
- [x] `build.py pull`: document → `tokens.json` → generated Dart. A dark palette change also updates `MonoPulseColors.<name>`. Variables added in FigCraft are added; deleted ones are reported and kept.
- [x] `build.py drift`: document against `tokens.json`; exits 1 on any difference.
- [x] Verified:
  - `drift` reports 0 on the rebuilt file;
  - changes to Spacing/lg, accentOrange and dark textPrimary in FigCraft were pulled into the generated Dart, with `beatModeNormal` still an alias;
  - reverting in FigCraft, then pull, gives `tokens.json` equal to the original theme;
  - `flutter analyze` shows no new issues; `flutter test` passes (3,334).
- [x] Gates: debug APK and web build pass.
- [-] Semantic and component tokens: skipped. CustomButton reads palette tokens directly, so a palette edit already reaches buttons. Add them when a component needs its own colour that differs from the palette.

## Phase 3.1–3.3: real screens from the device
- [x] Debug-only deep link `flowgroove-debug://app/<route>` in the android/app/src/debug manifest. Confirmed in the merged debug manifest.
- [x] `route` key on 33 specs; nothing else in the specs changed.
- [x] `capture.py`:
  - launches the app, opens each route as a deep link, screencaps and scales to 412 px, and writes `design/real/<key>.png` plus `index.json`;
  - `--signed-out` for the Auth pages;
  - `{band}`, `{song}`, `{setlist}`, `{rehearsal}` and `{invite}` come from `design/real/ids.json`.
- [x] `build.py parity` (also runs in `all`):
  - every frame gets dev resources: the GitHub source link (with a `#L` anchor) and the web-app route;
  - captured screens get the real screenshot beside the frame (slots are now twice as wide), an RMSE score note, and `readyForDev` at or under PARITY_OK (cleared otherwise);
  - the Parity page lists every screen.
  - Tested with stand-in captures: the same render scores 0.0 and an unrelated screen 22.6.
- [x] Device run on the P30 (2026-11-18): 28 routed screens captured in Light mode from the real account. The pixel score doesn't work as a readiness gate (the QR code dominates; a structurally wrong Songs design scored better than a correct one). Readiness now comes from `design/real/verdicts.json`, and the score only sorts the page. 28 of 28 match. Not captured: rehearsal_detail (no rehearsal), Auth (`--signed-out`), and the 102 frames with no route.

## Phase 2: components (code is canonical)
- [x] `ButtonVariant.tonal` (FilledButton.tonal) and `.danger` (error red, charcoal text, 4.6:1 contrast). `ButtonSize.medium` uses the theme padding (20/16). Icon-row labels are Flexible, as in Material, after a test caught an overflow. Tests added.
- [x] `AppBadge` (taken from the band-about and offline pills) and `SectionHeader` (title and label styles), with Code Connect. 23 links in total.
- [x] Migration, done by Codex in 3 sequential batches; I verified scope, grep, analyzer and the full suite after each:
  - 33 of 35 ElevatedButton calls (2 kept on purpose: the user-colour picker and a duration toggle);
  - 22 of 27 OutlinedButton calls (5 kept: Google sign-in image, demo button colours, long-press, filter padding, transport);
  - 6 private section-title helpers and 2 pills moved onto the new widgets.
  - Intended visual change: 4 orange buttons that used light `textPrimary` text in dark mode now use the theme's charcoal.
  - Checks: `flutter analyze` at the 265 baseline; 3,335 tests pass; debug APK and web builds pass.
- [x] `build.py verify-components` (offline): 10 linked app widgets; checks constructor parameters and enum members. Negative tests: renaming an enum member or a parameter makes it fail.
- [x] FigCraft Button, Badge and SectionHeader redrawn from the code (tonal radius 12, danger charcoal, medium padding 16/20, badge pill, header Style variant). Rebuilt, 130 screens, drift 0.
- [x] One orange CTA (2026-11-19): `filledButtonTheme` = primary look (radius 5, charcoal border, shadow, labelLarge). Colours stay on colorScheme, padding stays compact. No call-site churn for the ~50 FilledButtons; raw `.tonal` sites moved to `CustomButton(tonal)`, which clears the border and shadow. FigCraft tonal is now radius 5. Verified: P30 before/after, tests 3335, APK and web builds.
- [x] Font bug (2026-11-19): every screen rendered in Roboto, because google_fonts registers "Marcellus_regular" while the const styles ask for "Marcellus". Fonts are now bundled (assets/fonts, OFL, hash-verified from gstatic) under the exact names, and google_fonts is removed. Verified on the P30, tests 3335, APK and web builds.
- [x] Icons page (one component per `icons.txt` name) with instance swap and Code Connect `Icons.<name>`.
- [x] States: button disabled and loading; input focus, error and disabled; chip disabled; list tile selected.
- [x] Pattern components from repeated spec subtrees (SongCard, SetlistCard, MemberCard; `pattern` spec node with title, subtitle and meta text properties).
- [x] Docs: usage notes, contrast matrix, touch-target note (48×48 dp minimum).
- [x] Song Map components and spec nodes, Light and Dark modes, required pad contrast, and a demo spec.
- [x] Song Map SONG screen specs: MPC rework with overview, Chorus 1 zoomwave, Shift/Chop/Range keys, letter-coded section pads and playing transport in Dark and Light.
- [x] Song Map inside-section specs: MPC rework with overview, Chorus 1 zoomwave, ‹ Song/Shift/Chop/Range keys, selected part b pads, caption and stopped transport in Dark and Light.
- [x] Song Map PART slots 4–5 repurposed as the MPC Rename section hold-pad sheet in Dark and Light; overview replaces the old separate timeline aids.
- [x] Song Map PLAYING + RANGE screen specs: range selection from Part B 1 through Chorus 1, with Chorus 1 playing and Part D 1 queued, in Dark and Light.
- [x] Song Map CHOP WHILE PLAYING specs: dashed cut at bar 37 in the Part D 1 overview and zoom, lit Chop key, section pads, snackbar and playing transport in Dark and Light.
- [x] Song Map REVIEW screen specs: MPC review after Analyze, with candidate overview/zoom, section pads, and tempo/review banners in Dark and Light.
- [x] SD7 review of the Song Map frames, and SD8 fixes: section widths proportional to bars, letter label below 64 dp, pad subtitle = bar count, waveform shape, Range at Song level. Code followed in `docs/plans/song-map/` (C1–C14), released in 0.35.0+379.
- [x] MPC rework components (overview, zoomwave, key)

## Phase 3.4–3.5
- [x] Spec repair loop: Codex fixed 8 mismatched specs from the screenshots (only those files changed); Metronome dial redone by hand.
- [x] Prototype links: collect spec `links`, connect them after `all` builds every frame, and check destination frame names offline. Main tab navigation links are generated for the five shell destinations.
- [x] N6: use `proto.interaction.add` for click navigation. Draw Song Map nodes with custom child geometry directly so the main component retains control of inherited instance layers.

## Phase 4
- [x] `make design` and `make design-check` targets; offline checks in the test gate; commit `design/`; library version bump.
- [x] N7: run the full build with a fake FigCraft transport in `make design-check`, validating command IDs and parameters against the command catalog.

## Done before (2026-11-17)
130 screens as editable frames; 24 components; 21 Code Connect links; Foundations and Docs pages; library version 1.
