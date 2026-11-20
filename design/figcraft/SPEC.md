# Screen spec format

One JSON file per screen in `design/figcraft/specs/<screen>.json`. `build.py` turns it into an
editable 412x915 auto-layout frame in FigCraft (Android phone, dark theme). Check a spec offline
with `python3 design/figcraft/build.py check design/figcraft/specs/<screen>.json`.
`specs/songs_list.json` is the worked example.

## Screen

```json
{
  "name": "Songs",                 // frame name, unique
  "page": "Songs",                 // Auth | Home & Tools | Songs | Setlists | Bands | Settings
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

`links` connects a named node in this screen to a destination frame by its `name`. `all` applies
these connections after building every frame; `check` verifies that every destination frame exists.

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
| `button` | `v` label, `kind` (primary/secondary/text/tonal/danger), `icon`, `w`, `small` | buttons; primary = ElevatedButton (orange), secondary = OutlinedButton |
| `fab` | `icon`, `v` | FloatingActionButton (white, charcoal border) |
| `chip` | `v`, `sel`, `icon` | FilterChip / AppFilterChip |
| `input` | `label`, `hint`, `v` (filled value), `icon`, `trail`, `lines` | TextField (white fill) |
| `tile` | `lead` (icon name, initials, or a node), `title`, `sub`, `trail` (icon name / text / node / list), `pad`, `bg` | ListTile |
| `switchrow` | `title`, `sub`, `lead`, `on` | SwitchListTile |
| `switch` / `checkbox` | `on` | controls |
| `tabs` | `items`, `sel` (index) | TabBar |
| `segmented` | `items`, `sel` | SegmentedButton / ToggleButtons |
| `slider` / `progress` | `value` 0..1 | slider / LinearProgressIndicator |
| `section` | `v`, `action` | section header with optional trailing link |
| `badge` | `v`, `icon`, `bg`, `color` | small pill (key, BPM, role, status) |
| `avatar` | `v` initials or `icon`, `size`, `bg` | CircleAvatar |
| `divider` | `color` | 1 px line |
| `spacer` | `size` (px) or nothing (flex) | gap / Spacer() |
| `box` | `w`, `h`, `bg`, `radius`, `circle`, `border` | plain rectangle (waveforms, images, placeholders) |
| `appbar` | `v` title, `sub`, `back` (default true), `leading` icon, `actions` (icon names or nodes), `style` | AppBar, headlineLarge title |
| `bottomnav` | `sel` (Home/Songs/Bands/Setlists/More) | main shell tab bar (top-level tab screens) |
| `actionbar` | `primary` label, `icon` | pushed screens' bottom bar: Back, primary action, Menu |
| `sheet` | `c`, `bottom` (default true) | bottom sheet / dialog surface |
| `raw` | `type`, `props` (FigCraft node.set keys), `v` | escape hatch |

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
- **Button:** variants Variant (Primary, Secondary, Outline, Text, Tonal, Danger, following CustomButton) and Size (Small, Medium, Large). Spec `kind: secondary` still means Outline; `kind: white` gives CustomButton's white Secondary; `size: small|medium|large` is optional.
- **FAB, IconButton, Badge:** single components.
- **Chip:** variant State.
- **Avatar:** variant Type (Initials, Icon).
- **Switch, Checkbox:** variant State (On, Off).
- **Input:** variants State (Hint, Filled) and Lines (Single, Multi).
- **Slider, Progress:** variant Value, in 10% steps.
- **Tab, Segment, NavItem:** variant State.
- **BottomNav:** variant Tab.
- **StatusBar, SectionHeader:** single components.
- **ListTile:** Leading and Trailing slots.
- **SwitchRow:** variant State, Leading slot.
- **AppBar:** variant Leading (Back, None), Actions slot.
- **ActionBar:** a nested Primary button.
- **Card:** variant Direction, Content slot.
- **Sheet:** variant Docked, Content slot.
- **Dialog:** Content and Actions slots.

Labels, titles and icons are text properties. An icon property holds the Material glyph, and the icon layer is renamed `icon/<name>`. Optional parts have `Show …` boolean properties. Spec keys an instance can't express, such as a wrapping card, fall back to plain layers. The spec format is unchanged.

Rebuild one screen: `build.py screen specs/x.json`. It needs `.components.json`, written by `setup` and `all`.

## Tokens, docs, Code Connect

- **Tokens:** `Spacing` and `Radius` number variables. The builder binds every on-scale gap, padding and radius to them.
- **Pages:** the Foundations page shows the tokens; the Docs page documents each component.
- **Code Connect:** the `CONNECT` map in build.py links components to Flutter widgets, exported to `figcraft.connect.json`.
- **Publishing:** `all` publishes the file as a library.
- **Plan:** see PLAN.md.
