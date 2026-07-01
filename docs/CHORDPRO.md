# ChordPro in FlowGroove

FlowGroove uses [ChordPro](https://www.chordpro.org/) as the **readable text
layer** for a song's chords, lyrics and structure. The FlowGroove `Song` object
stays the **source of truth**; ChordPro is what we render, export, and (in
future) let users edit as text. A small internal codec keeps the two in sync.

All of this lives in `lib/utils/chordpro.dart` (tests in
`test/chordpro_test.dart`). It is intentionally internal for now — see
[Deferred](#deferred).

## The sync model

```
FlowGroove Song  ── songToChordPro ──▶  ChordPro document (text)
      ▲                                        │
      └────────────  chordProToSong  ◀─────────┘
```

- `songToChordPro(Song)` assembles one canonical document.
- `chordProToSong(String, {required Song base})` reads a document back onto a
  song and returns a `ChordProParse` (`song`, `sections`, `unknownDirectives`).

### Rule that makes interop safe

**Unknown directives are never dropped.** Anything that isn't a standard ChordPro
directive or a FlowGroove `x_flowgroove_*` field is collected into
`ChordProParse.unknownDirectives` so a caller can preserve it on re-export. This
is what lets a `.cho` file survive a round-trip through FlowGroove without losing
data another app wrote.

## Field mapping

| FlowGroove `Song` field        | ChordPro                                   |
|--------------------------------|--------------------------------------------|
| `title`                        | `{title: ...}`                             |
| `artist`                       | `{artist: ...}`                            |
| `ourKey`                       | `{key: ...}`                               |
| `ourBPM`                       | `{tempo: ...}`                             |
| `accentBeats`                  | `{time: N/4}` (numerator only — see below) |
| `notes`                        | `{comment: ...}`                           |
| `originalKey` (if ≠ `ourKey`)  | `{x_flowgroove_original_key: ...}`         |
| section order (song map)       | `{x_flowgroove_song_map: A \| B \| C}`     |
| `Section.name`                 | `{start_of_verse: label="Name"}`           |
| `Section.notes`                | `[* ...]` annotation line(s)               |
| `Section.chordChart`           | the chord/lyric lines inside the block     |
| `Section.duration` / colour    | `{x_flowgroove_section: bars=N; color=RRGGBB}` |

Section "extras" (bars/duration, colour) aren't expressible in plain ChordPro, so
they ride in a per-section `x_flowgroove_section` directive — lossless through a
text round-trip and MCP. When ChordPro text is edited live, `reconcileSections`
also carries these forward by matching sections on order+name, so editing chords
never wipes structure.

`x_flowgroove_*` uses the official ChordPro `x_` namespace for
application-specific directives, so other ChordPro tools ignore it rather than
choke on it.

### Derived, not stored

- **Scale** is derived from the key string with `keyToScale('Am') → (root: 'A',
  accidental: null, quality: 'minor')`. There is no scale field on the model.
- **Song map** is just the ordered section names; `songMapSummary([...])` collapses
  consecutive repeats into `Intro · Verse · Chorus ×2 · Bridge` for cards and the
  PDF header.

### Time signature caveat

The model has no time-signature *denominator*, so songs are emitted as `N/4`
(numerator = `accentBeats`) and only the numerator is read back. A real
denominator would need a model change — deferred until an app actually needs 6/8.

## Example document

```chordpro
{title: Zombie}
{artist: The Cranberries}
{key: Em}
{tempo: 84}
{time: 4/4}
{x_flowgroove_song_map: Verse 1 | Chorus}

{start_of_verse: label="Verse 1"}
[* soft, light kick]
[Em]Another [C]head hangs lowly
{end_of_verse}

{start_of_verse: label="Chorus"}
[Em]In your [C]head
{end_of_verse}
```

## Where it's used

- **Song editor** (`screens/songs/song_editor_screen.dart` +
  `chordpro_sync_controller.dart`) — a full-screen view where the visual song map
  and a ChordPro text area are two live-synced views of one `sections` store. Map
  edits regenerate the text instantly; text edits debounce then reconcile back.
  Opened from the Add/Edit Song overflow menu ("Song editor").
- **Paste import** (`components/import_lyrics_dialog.dart`) — a full ChordPro doc
  fills title/artist/key/tempo/time + sections; loose lyrics just split sections.
- **Song cards** (`widgets/song_card.dart`) — key + derived scale + section count
  (the full map lives in the editor, keeping the card uncluttered).
- **PDF export** (`services/export/pdf_service.dart`) — header line with key/scale,
  tempo, time signature and song map.
- **`.cho` file export** (`services/export/chordpro_export.dart`) —
  `shareSongChordPro(song)` runs `songToChordPro` and shares a standard ChordPro
  file (share_plus). Surfaced from the Performance Sheet AppBar for saved songs.
- **CSV** (`services/csv/`) — the `section_{n}_chart` column carries each
  section's `chordChart` through the Google-Sheets round-trip.
- **Per-section charts** (`Section.chordChart`) — the existing storage the codec
  assembles from and parses back into.

## Deferred

- External `.cho` file **import** (file picker) — export ships; import is the
  remaining half.
- Extracting the parser into a standalone `chordpro_dart` package + upstream
  contribution — only after it's proven on real songs here.
- Structured scale/mode field; time-signature denominator; ABC/LilyPond/MusicXML.
