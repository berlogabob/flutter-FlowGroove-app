# Proposal: one song, one musical context, several useful views

**Status: recommended direction, awaiting product validation; no application implementation.**

## 1. The organizing idea

Do not merge screens indiscriminately or add three new instrument modules. Make a **song workspace** the meeting point for the song map, playable material, instrument visualization, editing, practice and performance. Lab and Practice become useful entry points into that context, not parallel worlds.

```text
Song / band context                         Learn · Practice · Perform
Source: [MIDI arrangement / saved pattern / no backing]
Song map: Intro → Verse 1 → Chorus 1 → Verse 2 → Chorus 2
Focus: Chorus 2 · bars 25–32
My part: [Drums] [Keys] [Guitar]       Track: [Lead guitar ▼]

[ schematic drum kit / keyboard / fretboard ]
[ current notes / optional expanded editor ]

Listen to part · Play without my part · Edit · Add note / take
──────────────────────────────────────────────────────────
Play / Stop · position · loop · practice speed · click
```

This is information hierarchy, not a requirement to fit everything above the fold. On a phone keep the focused section, instrument and transport visible; expand the editor or Lab details when asked. In Perform prioritize current/next section and transport instead of editor controls.

### Keep three choices distinct

1. **View:** which instrument/track I am inspecting. No audio change.
2. **Mix:** what I hear: listen to this part, full band, or play without my part. Explicit action; show its state.
3. **Content:** which source, arrangement or pattern is loaded. Explicit operation, with preparation/error feedback.

Selecting Guitar must not silently replace the backing, mute a track, reset the cursor, or save an arrangement. Multiple guitar or keys tracks remain individually addressable; a musical role is not a unique track identity.

If the selected track has no notes in the current loop, keep the loop/cursor and show “No notes in this range.” Offer an explicit jump to a populated passage; never perform it as a side effect of view selection.

## 2. Song map is the shared navigation, not another editor

Use existing `Song.sections` for section occurrence identity/order, with per-source `SectionSpan` alignment into the MIDI. Show one map, overlaid with the selected source's coverage and the current play/queue state. Do not create a second song structure store.

- Repeated Chorus/Solo occurrences have different IDs even if their labels match. A reusable pattern may be used by several occurrences; changing one occurrence should not change all unless explicitly chosen.
- Separate structural order, source-file location, and temporary practice selection. A section label is not a time coordinate.
- Source offset, lead-in, partial sections and unmapped regions are visible. Show gaps as unavailable or click-only by explicit choice, never silently claim a complete backing.
- The P30 example is real: the piano MIDI reports **8 bars** and **Covers 8 of 23 bars**. Do not spread it evenly across the whole song and present that as verified alignment.
- Resolve **phrases versus bars** before migration: the constructor labels `Section.duration` in phrases, while the backing fallback uses the value as bars. No automatic multiplication/renaming of existing data without reviewing its meaning.
- An empty song map is valid: offer one whole-source range and optional sections added to that song's existing `Song.sections`. A songless quick exercise uses a temporary loop/range, not persistent song sections or a second structure store. Keep quick metronome practice available without dummy song creation; attaching authored material to a song is a subsequent slice with an explicit save destination.

## 3. Drums, keys and guitar

| Instrument | Schematic view | Editing surface | What not to invent |
|---|---|---|---|
| Drums | Reuse `DrumKitView`; highlight mapped kit pieces from the active note stream, show unmapped notes separately | Reuse the friendly drum grid for short patterns and existing per-track note editor for imported material | Stick/foot assignment or left/right technique not stored in the source |
| Keys | Compact keyboard, visible octave/range, simultaneous pressed notes and duration; optional note-name labels | Improve existing pitched `NoteEditorSheet` rather than introducing a second note model; add duration/velocity editing deliberately | Hands, fingering or sustain-pedal fidelity not present in current data |
| Guitar | Fretboard using explicit tuning/capo, show possible positions or a clearly labeled proposed position | Existing pitched notes remain the truth; optional user-selected string/fret annotation is separate from pitch | A unique correct string/fret, fingering, strumming direction or guitar technique from ordinary note-only MIDI |

The schematic is a learning aid, not a second sequencer or a button that unexpectedly changes sound. Give visual emphasis to now/next notes and retain text/semantic labels; meaning must not depend on color alone. Support chords/polyphony, scrolling ranges and left/right orientation where a real need is confirmed.

Initial guitar scope: demonstrate pitch locations with manual tuning, not automatic playable tablature or a voicing optimizer. Initial keys scope: note display and basic edits, not a full notation engine. Generalized instrument plugin systems are unnecessary for three explicit views.

Candidate fretboard positions are always labeled provisional. Changing the visible candidate does not change a note's identity or create a saved string/fret annotation; only an explicit user annotation can do that, and it remains separate from the MIDI note.

## 4. End-to-end journeys

### J1 — Understand and practice an imported part

Open song → choose MIDI source → choose section → choose track/instrument → **Listen to part** → loop a small range → slow to a session-local percentage → **Play without my part** → optionally capture a take → add a section-linked Lab observation/task.

The song, source, track, section, loop and cursor stay selected across diagram/editor/Lab views. Changing visual view has no transport side effect. Return to the exact passage from a task or take when that linkage is available; mark older unlinked records as such rather than guessing their passage.

### J2 — Create a pattern, then use it in a song

Choose song section (or start a free exercise) → **Create part** → Drums / Keys / Guitar → edit a draft using the appropriate surface → explicit audition → Save / Save as copy → use once or repeat across explicitly chosen section occurrences → practice using the same controls.

For the first release, complete this for existing drums plus imported pitched tracks. Creation of brand-new pitched tracks is a later bounded slice because the existing `MidiSongMeta.fileUrl`/loader path cannot simply be assumed to support fileless material. Do not advertise Create Keys/Guitar until that storage/load/save path is tested end to end.

### J3 — Import without falling into a different product

Add MIDI from Song, Lab or Practice → same validated preview → inspect/correct roles and tracks → review BPM/meter and source fidelity → confirm song-map alignment or keep Whole file → enter the same workspace.

Keep original bytes immutable and edit a working overlay/copy. Never run a pitched file through `MidiPattern` as the canonical import; it has hits/steps, not general note durations. Derived drum previews must remain recognizable as derived from the source, not independently editable competing truths.

### J4 — Practice into performance

Use the same prepared song/material → switch to Perform view → current/queued/next sections, large controls and explicit launch quantization → run linearly or launch sections → leave Perform without resetting the musical position.

A view switch does not change Loop into Song, alter tempo or mix, or start playback. Offer an explicit **Prepare performance** check: source cached, coverage reviewed, desired play mode, mix and count-in confirmed. Content replacement, import and destructive edits are disabled or require an explicit stop while performing. Reuse Concert Mode's presentation/state preservation rather than building a second stage engine.

### J5 — Goal into tomorrow's session

Practice agenda → a Lab task for a song/section → same workspace at that passage → practice and record an optional take → add reflection/update task → session log points back to the material. Practice remains a cross-song agenda and logbook, not a replacement for the musical workspace. Time spent is not a mastery score.

## 5. Domain vocabulary (proposed, not an accepted schema)

| Term | Meaning and current reuse |
|---|---|
| Song | Musical identity and owned/band context; not a MIDI file |
| Section occurrence | A particular position in the song structure, addressed by `Section.id` |
| Source | Original imported bytes or an authored pattern; preserve source provenance |
| Track | A voice/part inside a selected source, identified within the entry by index and channel, not role alone |
| Part | The musical material being worked on: selected track(s) plus a range; initially a selection, not a new collection/class |
| Pattern | A short reusable part; keep legacy drum patterns readable, without forcing pitched notes into the legacy hit representation |
| Alignment | Relation between song-section occurrences and source time; reuse `SectionSpan`/`sectionMap` |
| Practice context | Temporary source, track, range, speed, mix and view; not changes to the song's canonical BPM or arrangement |
| Lab record | Reflection, task, decision, recording or material reference with song/section provenance; retain existing history |

Existing `SongArrangement` means an owned variant of a canonical song. Existing MIDI arrangement means file-to-section alignment/settings. Do not silently merge those concepts because they share a word. No ADR or canonical glossary change is warranted until the owner accepts the direction.

## 6. Smallest implementation sequence

| Slice | Deliverable | Required gate |
|---|---|---|
| 0 — continuity contract | Agree bars/phrases, explicit source identity and view-vs-load semantics; add regression tests for save/navigation boundaries | No silent stale overwrite, no cancelled pending edit on close, unchanged legacy imports |
| 1 — one entry surface | Route Song/Lab/Practice into the existing musical workspace; retain source + section + track and one transport | View switching preserves source, cursor, tempo, mix and playing/queued state |
| 2 — instrument readouts | Reuse drums; add keys and guitar schematic projections of the selected note stream | Polyphony/ranges correct; no guessed fingering; no new clock or implicit mute |
| 3 — safe editing | Reuse `NoteEditorSheet`, `note_edit.dart`, drum grid and edited-note overlays; draft/cancel, duration/velocity where needed | Sustained and off-grid notes survive untouched; cancel changes neither original nor saved overlay |
| 4 — complete learning loop | Section-focused tasks, optional takes and explicit practice-local speed/mix | Reopen intended passage; song BPM and band settings unchanged; no compulsory reflection modal |
| 5 — performance readiness | Integrate the same prepared material/map into existing Concert Mode | All stop paths work; source prepared before launch; no navigation-triggered render; offline/background/device tests |

Ship one verified vertical journey at a time. Do not start with a schema rewrite, generic clip engine, new MIDI parser, replacement transport, cloud AI service, SoundFont dependency or full DAW layout.

## 7. Acceptance scenarios for the design

1. While the backing plays, choose Keys then Guitar: no re-attach/render request, no changed sound, no moved cursor. Explicit solo/mute remains separate.
2. A piano-only MIDI does not become an editable drum pattern. Mixed MIDI can expose a derived drum view without losing pitched tracks.
3. A held key/chord spanning several cells survives simply opening/changing/closing views. A targeted edit outside that note does not quantize it. Before expanding the existing editor, address its current occupied-cell behavior, which removes an entire overlapping note (`note_edit.dart:63-97`); do not describe that as safe note-duration editing.
4. Two same-role guitar tracks remain distinct; a section task points to its occurrence ID, not the first matching name.
5. Coverage mismatch, lead-in and missing section mappings are visible; unconfirmed auto-alignment is never treated as a correct performance map.
6. Slow practice and temporary mute/solo do not overwrite band arrangement settings or saved song BPM. A recorded take records the tempo actually used, rather than pretending it was canonical tempo.
7. Close immediately after an edit or switch song during an async render: no lost save, stale save into another entry, stale render completion or accidental launch.
8. Opening Perform preserves transport/mix; rendering and imports never unexpectedly interrupt a live run. Global/system Stop clears queued commands too.
9. Offline works for prepared/cached material; an uncached source shows a clear unavailable state rather than a promise that every import/save works offline.
10. Existing read-only/demo/band permission boundaries hold, including local preview versus persist; no public share or ownership change during ordinary practice.

## 8. Decisions to validate with the owner

- Is the preferred landing surface song-first, or does a quick free exercise need equal prominence? Recommendation: song workspace plus a retained free-practice shortcut.
- For guitar, are pitch-location hints sufficient initially, or is editable tablature essential? Recommendation: hints first, explicitly no authoritative fingering.
- Are all current section durations intended as bars, phrases, or a mix? This is a migration gate, not a wording-only decision.

Next product step: compare two low-fidelity layouts using J1/J2/J4 with the drummer owner and at least one keys player/guitarist; no implementation of the whole proposal before this check.

## 9. Phase 2 amendments (deeper P30 flow + competitors)

Evidence: `phase2/P30-FLOW.md` (D11–D22), `phase2/COMPETITORS.md` (Moises, Melodics, Yousician, Drumeo), ledger `phase2/ORCHESTRATION.md`.

**New core finding.** The owner's real practice is micro-runs: 51 sessions in 51 min, mostly 5 s–1 min, all on one song at one BPM (D12). Each Play→Stop is logged as a session that has no section, loop, track or source (D13, D14). The app makes the musician restart the transport to repeat a passage, and it forgets what the passage was. All four competitors make **section → loop** a single gesture. Two of them add a count-in on each loop restart (Moises, Yousician).

| # | Change | Because | Slice |
|---|---|---|---|
| A1 | Practice context is logged: song + source + track + section/loop + tempo used. Wire the existing unused `midiEntryId`, and add optional section/loop/track fields additively (no migration). Show restarts of the same loop as reps in one context, not as new sessions. | D12–D14; borrow 3 | 0 |
| A2 | Practice gets **Continue: ‹song · section · part · tempo›** that reopens the workspace at that passage. Homework rows open the passage, not just the Lab. | D12, D15; borrow 3 | 1 |
| A3 | A song opens on the workspace (play/practice). Edit metadata stays one tab away. | D22; L09b | 1 |
| A4 | Transport bar holds **Loop section** (one tap on the map or a pad), **Lead-in count-in on restart**, and **Without me** (mute the selected part). These are explicit controls, separate from view selection (§1). | borrow 1–2; L09b | 1 |
| A5 | Task form gets the section picker that entries already have (`SongTask.sectionId` exists). A take started from the workspace records song/section/tempo at capture. Recorder's after-the-fact "Link to song…" stays for free takes. | D16, D17 | 4 |
| A6 | Per-loop tempo steps reuse the existing Ramp ("+N BPM every K reps"). No accuracy scoring. | borrow 4 | 4 |
| A7 | Concert Mode shows current/next section from the same map. Lyrics scroll follows transport position when sections + BPM are known, and keeps the px/s fallback otherwise. | D19, D20 | 5 |

Not adopted: scoring/"wait to play", AI stem or section detection, lesson catalogs (see COMPETITORS.md). Positioning: none of the four documents bringing your own multi-track MIDI and editing drum/keys/guitar parts against a band's song map. Continuity is the differentiator.

Acceptance additions: (11) Loop a section 10 times → one practice context with 10 reps, and Continue reopens the same section/part/tempo. (12) Selecting Without me changes only the mix, never the view, cursor or saved arrangement. (13) Count-in on loop restart can be turned off and never shifts the loop's bar alignment.
