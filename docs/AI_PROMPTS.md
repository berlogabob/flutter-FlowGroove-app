# AI prompt templates

FlowGroove doesn't run AI itself (no token cost to you). Instead, ask **your own**
assistant (ChatGPT, Claude, Gemini, a local model) to produce a song in
[FlowGroove Song JSON](./SONG_JSON_SCHEMA.md), then paste the result into
**Import** (it auto-detects JSON). The app can copy these prompts for you — in the
Import dialog, tap **Copy AI prompt**.

## 1. Create a song

```
You are helping me add a song to FlowGroove. Output only valid FlowGroove Song
JSON v1 — no prose, no markdown fences.

Envelope:
{ "schemaVersion": 1, "songs": [ { ...song... } ] }

Song fields:
- "title" (required), "artist"
- "originalKey", "ourKey" — like "C", "G#", "Am", "Bbm"
- "originalBPM", "ourBPM" — integers 40–300
- "tags" — array of strings; "notes" — string
- "sections" — array of { "name", "duration" (bars, int), "notes", "chordChart" }
  where "chordChart" is ChordPro: the chord in [brackets] immediately before its
  syllable, e.g. "[Am]Twinkle [F]little [C]star".

Give me the song title "<TITLE>" by "<ARTIST>" with an accurate key, BPM, section
structure, and chords-over-lyrics in "chordChart". If unsure of a value, omit it
rather than guessing. Return the JSON object only.
```

## 2. "Make our version"

Same JSON contract, plus arrangement instructions:

```
Take "<TITLE>" by "<ARTIST>" and give me OUR version as FlowGroove Song JSON v1:
- ourKey a whole tone below the original
- shorter structure: Intro, Verse, Chorus, Verse, Chorus, Outro
- chords over the lyrics in each section's "chordChart"
- ourBPM slightly slower than the original
Return only the JSON.
```

## 3. Import back

Copy your assistant's JSON, open FlowGroove → Import → **Paste from clipboard**.
It's validated and previewed (add / merge / problems) before anything is saved.

See also: the schema is the source of truth (`docs/SONG_JSON_SCHEMA.md`), and this
same contract is what the planned MCP endpoint will expose to agents directly.
