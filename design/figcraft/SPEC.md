# Screen spec format

## Make targets

- `make design-check` runs the offline spec check, the FigCraft command dry run, Code Connect component verification, and the contrast matrix. It fails if any command fails and does not require FigCraft.
- `make design` runs `python3 design/figcraft/build.py all` to rebuild the FigCraft library. FigCraft must already be running with its control channel; this target does not start it.

`python3 design/figcraft/build.py dryrun [commands.json]` runs the build with simulated FigCraft responses. It checks command IDs and top-level parameter names, including commands inside batches. It uses the catalog at `../_plans/song-map/fc_commands.json` relative to the repository root by default. The dry run uses temporary registries and simulates image export and parity scores.

One JSON file per screen in `design/figcraft/specs/<screen>.json`. `build.py` turns it into an
editable 412x915 auto-layout frame in FigCraft (Android phone, Dark by default). Check a spec offline
with `python3 design/figcraft/build.py check design/figcraft/specs/<screen>.json`.
`specs/songs_list.json` is the worked example.

## Screen

```json
{
  "name": "Songs",                 // frame name, unique
  "page": "Songs",                 // Auth | Home & Tools | Songs | Setlists | Bands | Settings | Song Map
  "mode": "dark",                  // optional: light | dark, selects the MonoPulse variable mode
  "source": "lib/screens/...dart", // the Dart file it recreates
  "slot": 0,                       // position on the page (0,1,2... per page, unique per page)
  "links": [{"from": "Back", "to": "Songs"}], // optional prototype connections (node name -> frame name)
  "bg": "black",                   // optional screen background token
  "top": [ ... ],                  // fixed header nodes (usually one appbar)
  "body": [ ... ],                 // content, top to bottom, clipped at the bottom
  "bottom": [ ... ],               // fixed footer: bottomnav, actionbar, or a sticky button row
  "overlay": [ {"x": 340, "y": 760, "node": {"t": "fab", "icon": "add"}} ]  // absolute layers
}
```

A status bar (28 px) is added automatically on top.

`links` connects a named node in this screen to a destination frame by its `name`. `all` adds
click-to-navigate interactions after building every frame. `check` verifies destination frame names
and `dryrun` also checks that the source nodes were built.

## Nodes

Every node is an object with `t`; a bare string is a bodyMedium text. Common keys on containers:
`gap`, `pad` (n or [top,right,bottom,left]), `bg`, `border`, `borderW`, `radius` (n or [tl,tr,br,bl]),
`main` (min|center|max|spaceBetween), `cross` (min|center|max), `w`/`h` (number = fixed px,
"fill", "hug"), `wrap` (true), `shadow` (true), `opacity`, `name`, `c` (children).
Defaults: in a column, children fill the width; in a row, they hug.

| t | keys | what |
|---|---|---|
| `col` / `row` | container keys | vertical / horizontal auto layout |
| `card` | container keys, `dir: "h"` for a row card | AppCard: surface bg, borderSubtle, radius 7, pad 16 |
| `text` | `v`, `style`, `color`, `align` (left/center/right), `maxLines`, `w` | text |
| `icon` | `v` (Flutter `Icons.<name>`, e.g. `music_note_outlined`), `size` (24), `color` | Material icon |
| `iconbtn` | `v` icon, `size`, `color`, `bg`, `border`, `radius` | 48x48 IconButton |
| `button` | `v` label, `kind` (primary/secondary/text/tonal/danger), `icon`, `w`, `small` | CustomButton; primary = ElevatedButton (orange), secondary = OutlinedButton |
| `fab` | `icon`, `v` | FloatingActionButton (white, charcoal border) |
| `chip` | `v`, `sel`, `icon` | AppFilterChip |
| `input` | `label`, `hint`, `v` (filled value), `icon`, `trail`, `lines` | CustomTextField (white fill) |
| `tile` | `lead` (icon name, initials, or a node), `title`, `sub`, `trail` (icon name / text / node / list), `pad`, `bg` | ListTile |
| `switchrow` | `title`, `sub`, `lead`, `on` | SwitchListTile |
| `switch` / `checkbox` | `on` | controls |
| `tabs` | `items`, `sel` (index) | TabBar |
| `segmented` | `items`, `sel` | SegmentedButton / ToggleButtons |
| `slider` / `progress` | `value` 0..1 | slider / LinearProgressIndicator |
| `section` | `v`, `action` | section header with optional trailing link |
| `badge` | `v`, `icon`, `bg`, `color` | AppBadge: small pill (key, BPM, role, status) |
| `avatar` | `v` initials or `icon`, `size`, `bg` | UserAvatar |
| `divider` | `color` | 1 px line |
| `spacer` | `size` (px) or nothing (flex) | gap / Spacer() |
| `box` | `w`, `h`, `bg`, `radius`, `circle`, `border` | plain rectangle (waveforms, images, placeholders) |
| `wave` | `w` (defaults to `fill`), `h` (defaults to 72), `radius` (defaults to 8) | A surfaceRaised waveform with 64 thin `textSecondary` bars whose heights come from a fixed seed. |
| `appbar` | `v` title, `sub`, `back` (default true), `leading` icon, `actions` (icon names or nodes), `style` | AppBar, headlineLarge title |
| `bottomnav` | `sel` (Home/Songs/Bands/Setlists/More) | AppBottomBar.nav: main shell tab bar (top-level tab screens) |
| `actionbar` | `primary` label, `icon` | AppBottomBar.actions: pushed screens' bottom bar: Back, primary action, Menu |
| `sheet` | `c`, `bottom` (default true) | ModalBottomSheet surface |
| `dialog` | `title`, `icon`, `c`, `actions` | AlertDialog |
| `navitem` | `v`, `icon`, `sel` | NavTab |
| `segment` | `v`, `sel` | ButtonSegment |
| `raw` | `type`, `props` (FigCraft node.set keys), `v` | escape hatch |

### Song Map nodes

See [song_map_demo.json](examples/song_map_demo.json) for a 412×915 example using every node. The same
spec renders in the other theme by changing `mode` to `dark`.

| `t` | Keys | Rendering |
|---|---|---|
| `overview` | `sections` (list of objects with `letter`, `color`, positive integer `bars`, `state`), optional `playhead` (0..1), optional `cuts` (list of 0..1 fractions) | Full-width 64 px seeded waveform with 25% section tint bands and a 32 px proportional lane with centered letters on 35% section-colour tints over the surface. The bands and blocks share edges at the same bar positions. Selected and playing have 3 px `textPrimary` and `accentOrange` outlines respectively. Candidate outlines and new cuts are dashed. A 2 px `textPrimary` playhead crosses both rows. |
| `zoomwave` | `title`, `parts` (list of objects with `letter`, positive integer `bars`, `state`), `startBar` (integer), `color` (defaults to `section1`), optional `playhead` and `cut` (0..1), optional `cutLabel` | Full-width 96 px seeded waveform with a 25% section tint, a proportional parts lane with letters and bar counts on 35% section-colour tints over the surface, and small `labelSmall` `textSecondary` bar numbers under each bar tick starting at `startBar`. Uses the overview states and playhead. The dashed cut can display a label such as “bar 37”. |
| `key` | `v` (label), optional `icon` (Material icon name), `lit` (boolean, defaults to false) | 48 px MPC function key with medium radius. Idle uses `surfaceRaised`, a 1 px `borderStrong` outline and `textPrimary` ink. Lit uses `accentOrange` and charcoal ink. |
| `pad` | `label`, `sub`, optional `letter`, `color` (stripe and badge token, defaults to `section1`), `state` (idle, selected, playing, queued, disabled), `progress` (0..1, defaults to 0), optional numeric `w` (180 px) | A small rounded section-color letter badge precedes the label when supplied. Idle has a 6 px stripe. Selected has a 3 px `textPrimary` border. Playing has an `accentOrange` fill, charcoal text, play icon and 4 px bottom progress bar. Queued has a 3 px `accentOrange` border and a “next” label. Disabled uses 38% opacity. |
| `secblock` | `name` (optional layer name), `letter`, `color` (defaults to `section1`), numeric `w` (112 px), `state` (confirmed, candidate, selected, playing) | Tinted section block labeled with its letter at every width. Candidate borders are dashed. Selected has a 3 px `textPrimary` outline. Playing has a 3 px `accentOrange` outline and a darker tint. |
| `partblock` | `letter`, `bars` (defaults to 4), numeric `w` (80 px), optional `color`, `state` | Same states as `secblock`, with a bar count as the label. |
| `boundary` | `state` (confirmed, candidate, selected), optional `h` (72 px) | Seam handle with a dashed stem for candidates. Use `overlay` to place it over the timeline. |
| `playhead` | Optional `h` (72 px) | Orange playback marker. Set its position with the screen's `overlay` coordinates. |
| `minimap` | `sections` (list of objects with `color` and numeric `w`), `viewport` (`[x, w]` in px relative to the strip) | A strip as wide as the sum of section widths. The viewport defaults to the whole strip. |
| `ruler` | `labels` (list of strings or numbers) | Evenly spaced bar labels with ticks. |
| `beatgrid` | `beats` per bar (defaults to 4), `bars` (defaults to 1), both positive integers | A numbered tick per beat, with a taller tick on each downbeat. |
| `breadcrumb` | `items` (list of labels) | Ordered zoom path with chevron separators. |
| `transport` | `speed` (percent number or display string, defaults to 100), boolean `loop`, `click`, `playing`, `countIn`, `drums` (all default to false) | Sticky playback controls for the screen's `bottom`. The first key reads Play with a play icon while idle and Pause with a pause icon while playing. |

The default state is idle for pads and confirmed for section blocks, part blocks and boundaries.
Overview sections and zoom parts use the block states `confirmed`, `selected`, `playing` and
`candidate`, with `confirmed` as the default.
Pad contrast is required in both themes. Playing text needs 4.5:1 on `accentOrange`. The selected
border, queued border and playing fill each need 3:1 against the idle pad surface. Dark pads use
`surface` and Light pads use `white` so the orange states clear 3:1.
Lit key text and letter badge text require 4.5:1 in both modes. Badges use white text on
`section1` through `section4` and charcoal on `section5` through `section14`. The
`section1` badge has a 6% charcoal overlay so white text clears 4.5:1.

## Tokens

Colours (theme-aware, dark values shown in the app): `black` (app background), `blackSurface`,
`blackElevated`, `surface`, `surfaceRaised`, `surfaceOverlay`, `borderSubtle`, `borderDefault`,
`borderStrong`, `textPrimary`, `textHighEmphasis`, `textSecondary`, `textTertiary`, `textDisabled`.
Brand: `accentOrange`, `accentOrangeLight`, `accentOrangeDark`, `accentOrange10/15/20/30`, `petrol`,
`sage`, `selection`, `paper`, `stone`, `fog`, `charcoal`, `white`, `error`, `error10`, `warning`,
`info`, `successGreen`, `beatAccent`, `beatSilent`, `roleAdmin`, `roleEditor`, `roleViewer`,
`section1`..`section14`. `#RRGGBB` / `#RRGGBBAA` also work. Map `context.mp.X` and
`MonoPulseColors.X` to the token of the same name.

Text styles (MonoPulseTypography): `displayLarge` 40, `displayMedium` 32, `headlineLarge` 24,
`headlineMedium` 20, `headlineSmall` 16, `titleLarge` 22, `titleMedium` 16 (Marcellus);
`bodyLarge` 16, `bodyMedium` 15, `bodySmall` 13, `caption` 12 (Source Serif 4); `labelLarge` 15,
`labelMedium` 13, `labelSmall` 12 (Arial bold); `mono`.

Spacing (MonoPulseSpacing): xxs 2, xs 4, sm 8, md 12, lg 16, xl 20, xxl 24, xxxl 32, huge 40,
massive 48. Radius (MonoPulseRadius): small 8, medium 10, large 12, xlarge 16, huge 20, massive 24.

## Rules

### Stable layout

Stable layout is the main design-system rule for every component.

| Rule | Do | Don't |
|---|---|---|
| **S1. Preserve geometry across states.** Selected, active, pressed, focused, disabled, loading, playing and queued may change colour, fill, opacity or icon glyph. Keep size, padding, border width, font size, font weight and line count constant. Reserve the widest border in every state and make it transparent when off. | Give Song Map lane blocks a 3 dp outline slot in every state and change the outline colour. | Give the lane a 3 dp border when selected and 1 dp at rest, add a FilterChip side only on selection, bold its selected label, or grow a tuner pad from 72 to 80 dp when active. |
| **S2. Reserve space for changing values.** Use tabular figures and fixed-width slots for time, BPM, counters and bar numbers. Size swapped labels and indicators for their largest content. | Give the metronome BPM a fixed-width slot for the widest value and give Play/Pause a slot that fits Pause. | Let unslotted BPM text push nearby controls as digits change, or let a loading spinner shrink its button. |
| **S3. Repaint live data in place.** Use reserved bounds for playback position, meters, progress and analysis results. Keep the playhead inside the playing clip. | Update the Song Map playhead and pad progress inside the playing clip's bounds. | Show a stale playback position in the neighbouring clip during a loop wrap. |
| **S4. Reserve or overlay appearing content.** Banners, hints, errors and loaders use a reserved slot or an overlay. Reflow is allowed only for an explicit user-tapped expand or collapse, and it animates. | Reserve a line under an input for its error message. | Insert the error as a new row that pushes the rest of the form down. |
| **S5. Align list columns.** Give each column a fixed slot across rows and keep slots for missing values. | Keep a BPM slot in every song row, including songs without a tempo. | Move the key or trailing actions into the BPM slot when a value is missing. |

`build.py check` checks the width and height of component-set variants offline. It compares states
at the same declared Button Size or Input Lines setting.

### Screen composition

- Recreate what the screen shows in its main, populated state for a signed-in user with realistic
  sample data (FlowGroove is a band/rehearsal app: songs, setlists, bands, rehearsals). Use the
  real labels, icons, section order and controls from the Dart code and the widgets it uses.
- Top-level tab screens (Home, Songs, Bands, Setlists) end with `bottomnav`; pushed screens use
  `actionbar` (or a sticky primary button row if the screen has its own); auth screens have neither.
- Keep the body within 915 px of height; it clips. Show 3-6 list items, not 30.
- Use only the node types and tokens above; unknown icons fail `check`, so use names that exist in
  Flutter's `Icons` class.

## Sheets and dialogs

Set `"modal": "sheet"` or `"modal": "dialog"` on the screen and `"page": "Sheets & Dialogs"`. The
body becomes a dark scrim; put ONE `sheet` node (docked at the bottom) or ONE `dialog` node
(centred) in `body`, and leave `top`/`bottom` empty. `dialog` keys: `title`, `icon`, `c` (content),
`actions` (usually `button` nodes with `kind: "text"`; destructive confirm = `kind: "danger"`).
Examples: `examples/modal_dialog.json`, `examples/modal_sheet.json`.

## Components

`setup` and `all` build a component library on the "Components" page, and screens use instances of it:
- **CustomButton:** variants Variant (Primary, Secondary, Outline, Text, Tonal, Danger, following CustomButton), Size (Small, Medium, Large), and State (Default, Disabled, Loading). Disabled uses 38% opacity; Loading shows a spinner glyph instead of the label. Spec `kind: secondary` still means Outline; `kind: white` gives CustomButton's white Secondary; `size: small|medium|large` is optional.
- **FloatingActionButton, IconButton, AppBadge:** single components.
- **AppFilterChip:** variant State (Default, Selected, Disabled). Disabled uses 38% opacity.
- **UserAvatar:** variant Type (Initials, Icon).
- **Switch, Checkbox:** variant State (On, Off).
- **CustomTextField:** variants State (Hint, Filled, Focus, Error, Disabled) and Lines (Single, Multi). All states use a 2 px border and reserve a helper line. Focus uses `accentOrange`; Error uses `error` and shows the helper text; Disabled uses 38% opacity.
- **Slider, LinearProgressIndicator:** variant Value, in 10% steps.
- **Tab, ButtonSegment, NavTab:** variant State.
- **AppBottomBar:** variant Tab includes Actions and navigation tabs in one component set. Screen footers place individual NavTab instances so each tab can carry its own prototype link.
- **StatusBar, SectionHeader:** single components.
- **ListTile:** variant State (Default, Selected) and Leading and Trailing slots. Selected uses an `accentOrange10` background.
- **SwitchListTile:** variant State, Leading slot.
- **AppBar:** variant Leading (Back, None), Actions slot.
- **AppBottomBar.actions:** a nested Primary button.
- **AppCard:** variant Direction, Content slot.
- **ModalBottomSheet:** variant Docked, Content slot.
- **AlertDialog:** Content and Actions slots.
- **Song Map:** SongMapPads (`pad`), SectionBlock, PartBlock, Boundary, Playhead, Minimap, Ruler, BeatGrid,
  Breadcrumb, SongMapTransport (`transport`), SongMapOverview (`overview`), SongMapTimeline (`zoomwave`) and Key have Mode (Dark, Light) variants using the
  MonoPulse collection. Pad, SectionBlock, PartBlock, Boundary and Key also have a State variant.
  The builder selects the Mode variant from the screen's `mode` key. Pad, block and key labels
  are text properties. Minimap, Ruler, BeatGrid, Breadcrumb, Transport, Overview and ZoomWave
  use slots populated from their spec data.

Labels, titles and icons are text properties. An icon property holds the Material glyph, and the icon layer is renamed `icon/<name>`. Optional parts have `Show …` boolean properties. Spec keys an instance can't express, such as a wrapping card, fall back to plain layers.

Rebuild one screen: `build.py screen specs/x.json`. It needs `.components.json`, written by `setup` and `all`.

## Tokens, docs, Code Connect

- **Tokens:** `Spacing` and `Radius` number variables. The builder binds every on-scale gap, padding and radius to them.
- **Pages:** the Foundations page shows the tokens; the Docs page documents each component.
- **Code Connect:** the `CONNECT` map in build.py links components to Flutter widgets, exported to `figcraft.connect.json`.
- **Publishing:** `all` publishes the file as a library.
- **Plan:** see PLAN.md.
