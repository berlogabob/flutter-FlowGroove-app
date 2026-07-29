# FlowGroove Song JSON — schema v1

The stable import/export format that the in-app JSON import, the AI prompt
templates (#73), and the MCP tools (#74) all write against. Implementations
that MUST stay in sync with this document:

- Dart: `lib/services/json/song_json_codec.dart` (`SongJsonCodec`)
- Server: `functions/src/mcp/song_schema.js` (`validateSong`)
- Prompt: `lib/services/json/song_ai_prompt.dart` (`songImportPrompt`)

## Envelope

```json
{
  "schemaVersion": 1,
  "songs": [ { "title": "…", "artist": "…" } ]
}
```

For convenience, `SongJsonCodec.parse` also accepts a bare song array or a
single bare song object. An unknown `schemaVersion` produces a warning and a
best-effort import, not a failure.

## Song fields

| Field | Type | Rules |
|---|---|---|
| `title` | string | **required**, non-empty |
| `artist` | string | optional |
| `originalKey`, `ourKey` | string | matches `^[A-G][#b]?m?$` — e.g. `C`, `G#`, `Am`, `Bbm`; invalid → field error |
| `originalBPM`, `ourBPM` | integer | 40–300; invalid → field error |
| `notes` | string | free text |
| `tags` | string[] | non-strings dropped |
| `spotifyUrl` | string | must be a valid URL |
| `links` | object[] | `{ "url", "type"?, "title"? }` per `Link.toJson`; `type` defaults to `other`; url-less entry dropped, invalid url → error (client import) |
| `youtubeUrl` | string | MCP only — convenience alias folded into `links` as `{ type: "youtube_original", url }` |
| `sections` | object[] | see below |
| `spotifyId`, `musicbrainzId`, `isrc`, `album` | string | provenance/identity, passed through |
| `durationMs` | integer | passed through |
| `id` | string | accepted on input but a fresh id is always generated |

Unknown fields are ignored with a warning naming them.

## Section shape

```json
{
  "name": "Verse 1",
  "duration": 4,
  "notes": "palm-muted",
  "chordChart": "[Am]Twinkle [F]little [C]star",
  "colorValue": 4283215696,
  "id": "optional — regenerated if absent"
}
```

- `name` defaults to `"Section"`, `duration` (bars, int) defaults to 1.
- `chordChart` is **ChordPro**: lyric lines with the chord in square brackets
  immediately before its syllable. Directives are not expected inside
  `chordChart` (section identity lives in `name`).

## Error model

`SongJsonCodec.parse` returns `SongParseResult`: `successful` (parsed songs),
`errors` (per-song, field-level; a song with a missing title is skipped),
`warnings` (unknown fields, unknown schemaVersion). The server-side
`validateSong` mirrors the same rules and rejects writes that fail them.
