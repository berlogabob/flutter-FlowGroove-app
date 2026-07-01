# FlowGroove Song JSON — v1

The stable, documented format for importing and exporting songs. It is the contract
that AI prompt templates and the FlowGroove MCP endpoint write against, so an external
assistant can prepare a song and you can import it (or the reverse).

Implemented by `lib/services/json/song_json_codec.dart`
(`SongJsonCodec.exportToString` / `.parse`).

## Envelope

```json
{
  "schemaVersion": 1,
  "songs": [ { /* song */ } ]
}
```

`parse` is lenient on input: it also accepts a bare array of songs, or a single song
object. `exportToString` always writes the full envelope. An unrecognized
`schemaVersion` is a **warning**, not a failure (best-effort, forward-compatible).

## Song fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `title` | string | **yes** | Missing/empty → the song is rejected. |
| `artist` | string | no | Defaults to empty. |
| `originalKey` | string | no | Like `C`, `G#`, `Am`, `Bbm` (`^[A-G][#b]?m?$`). |
| `ourKey` | string | no | Our performance key, same format. |
| `originalBPM` | integer | no | 40–300. |
| `ourBPM` | integer | no | 40–300. |
| `notes` | string | no | Free text. |
| `tags` | string[] | no | |
| `spotifyUrl` | string | no | Valid URL. |
| `links` | Link[] | no | See below. |
| `sections` | Section[] | no | Song structure + chords/lyrics. |
| `spotifyId` / `musicbrainzId` / `isrc` / `album` | string | no | External identifiers. |
| `durationMs` | integer | no | |

Unknown fields are ignored (with a warning). Internal fields (ownership, canonical
links, normalized/soundex search keys) are never imported or exported.

### Link

```json
{ "type": "youtube_original", "url": "https://…", "title": "Live take" }
```
`type` ∈ `chords`, `tabs`, `drums`, `spotify`, `youtube_original`, `youtube_cover`,
`other` (defaults to `other`).

### Section

```json
{ "name": "Verse 1", "duration": 1, "notes": "", "chordChart": "[Am]Twinkle [F]little [C]star" }
```
- `name` — section label (defaults to `Section`).
- `duration` — integer phrases/bars (default `1`).
- `notes` — free text.
- `chordChart` — **ChordPro** lyrics with inline `[chords]` (chord before its syllable).
  A whole song can also be rendered to / parsed from a single ChordPro document via the
  sync codec (`utils/chordpro.dart`); see [`CHORDPRO.md`](CHORDPRO.md).
  This is what the performance sheet, transpose, and PDF render.

## Validation

`parse` returns successful songs plus `errors` (a song was rejected) and `warnings`
(imported with caveats). Rejections: missing `title`, invalid key, BPM out of 40–300,
malformed URL. Imported songs get fresh ids; nothing is written until you confirm in the
import preview.

## Example

```json
{
  "schemaVersion": 1,
  "songs": [
    {
      "title": "Zombie",
      "artist": "The Cranberries",
      "originalKey": "Em",
      "ourKey": "Em",
      "ourBPM": 84,
      "tags": ["cover", "90s"],
      "sections": [
        { "name": "Verse 1", "chordChart": "[Em]Another head [C]hangs lowly" },
        { "name": "Chorus", "chordChart": "[Em]In your [C]head, in your [G]head" }
      ]
    }
  ]
}
```
