# Evidence and verification

2026-10-23. Repository: `/Users/berloga/Documents/GitHub/flutter_repsync_app`, branch `second01`, initial clean working tree. Baseline HEAD observed at session start: `e01797d8`; no app code was edited. Android target selected explicitly by serial `XPH0219904001750` (Huawei ELE-L29 / P30); another Android device was connected and not used.

## Evidence labels

- **DEVICE:** directly observed on this P30 during this run.
- **CODE:** read in current source; not necessarily exercised live.
- **TEST:** executed test result from this run.
- **HYPOTHESIS:** needs a focused test or user validation.

Installed package `com.flowgroove.app`: versionName `0.28.0`, versionCode `367`. `pubspec.yaml:4` declares the same version. Matching declared versions does **not** prove the installed APK corresponds byte-for-byte to HEAD. No reinstall/build was done.

## P30 walkthrough

| ID | Evidence | Observed path / result | Screenshot |
|---|---|---|---|
| D01 | DEVICE | Songs library → Back to Black opens song Edit view, with Sheet and Lab as sibling tabs | `evidence/p30-song.png` |
| D02 | DEVICE | Lab → Entries shows `btb_piano_8bars.mid`, `btb_midifind_3trk.mid`, `AUD_CT1445.mid`; Add/Import MIDI and task/history-oriented controls | `evidence/p30-lab.png` |
| D03 | DEVICE | Song menu → Metronome; Backing tracks is below the initial visible practice controls and was reached by scrolling | `evidence/p30-practice-lower.png` |
| D04 | DEVICE | Backing tracks lists Drum pattern separately plus all three MIDI files; each file initially says “hidden, tap to show” | `evidence/p30-backing.png` |
| D05 | DEVICE | Drum pattern opens Drums: the piano-only item is disabled; a mixed-MIDI drum pattern is selected; sync/speed and schematic kit visible | `evidence/p30-drums.png` |
| D06 | DEVICE | Pencil beside mixed MIDI → Edit pattern: 4 bars, paged 1–64 steps, lane grid, velocity cycling, Play/Save | `evidence/p30-editor.png` |
| D07 | DEVICE | Song Structure is presented in phrases: examples Pause 1 phrase and Solo 4 phrases; no direct practice-part link visible in inspected section cards | `evidence/p30-map-lower.png` |
| D08 | DEVICE | Lab → piano MIDI opens Mixer with Grand Piano / keys, mute, volume, solo; no keyboard schematic or visible transport in that sheet | `evidence/p30-keys-midi.png` |
| D09 | DEVICE | Temporarily Show piano MIDI through Backing tracks → section launchpad. Header says “MIDI 123 BPM · 8 bars” and “Covers 8 of 23 bars”; repeated Solo pads and Loop/Quantize controls visible | `evidence/p30-launchpad-lower.png` |
| D10 | DEVICE | MIDI overflow → Hide MIDI, then reopen Backing tracks; restored three hidden entries. Hide is a session-only presentation flag in source, not deletion | `evidence/p30-hidden-verified.png` |

No notes, sections, mix settings or files were edited, saved, imported or deleted. The grid was opened and exited without editing; Play was not pressed. One session-only MIDI visibility flag was temporarily changed to inspect the launchpad and then restored/read back. Opening panels can still select/attach preview material; the original runtime selection is not claimed to have been restored exactly. Saved composition data was not intentionally changed. Navigation itself is not evidence that the musical data persisted unchanged in the backend; no database audit was run.

Important nuance: the device's hidden MIDI state explains why its initial practice view looked like a plain metronome. The app does have a MIDI section launchpad; this research does **not** claim that feature is missing.

## Current source map and reuse opportunities

| Finding | Evidence |
|---|---|
| Lab already owns both legacy drum patterns and full MIDI metadata; they are not outside the entry model | `lib/models/song_lab.dart:64`, `:146-171` |
| A single import may store a full MIDI song and a derived legacy drum pattern on the same entry | `lib/services/midi_song_import.dart:48-71` |
| Drum panel lists every MIDI entry, but enables selection/editor only when the legacy `midi` field is present; explains disabled piano row | `lib/widgets/metronome/drum_practice_panel.dart:285-339` |
| Drums, keys and guitar roles already exist; general MIDI notes carry tick, duration, pitch and velocity | `lib/models/midi_song.dart:3-17`, `:32-43` |
| Track overrides, edited notes, program, mute and volume already exist | `lib/models/midi_song.dart:114-174` |
| Legacy `MidiPattern` has step/note/velocity hits and no per-note duration; it is not a general pitched-event replacement | `lib/models/midi_pattern.dart:1-18`, `:21-64` |
| Pitched editing is already implemented, not absent: `NoteEditorSheet` branches on drums versus pitch rows, uses a working note copy and Apply/Reset | `lib/widgets/practice/note_editor_sheet.dart:39-47`, `:140-179` |
| Existing cell editing has an important limit: toggling an occupied cell removes entire overlapping notes, including a sustained note extending outside the cell | `lib/services/audio/midi/note_edit.dart:63-97` |
| Song Edit/Sheet/Lab are retained in a stack, so reuse this state-retention pattern rather than replacing every screen | `lib/screens/songs/song_page_screen.dart:395-449` |
| Backing sheet chooses different panels based on whether a MIDI section map exists | `lib/widgets/metronome/backing_sheet.dart:67-76` |
| A real shared backing engine/transport already exists, including metronome clock hooks on web | `lib/providers/data/backing_transport_provider.dart:26-42`, `:97-158` |
| Android/web drum playback routes through the same transport; other native platforms retain a separate implementation | `lib/providers/data/drum_practice_provider.dart:59-63`, `:83-111` |
| Attach is not a harmless selection: it clears/re-renders the engine; song attach also clears a drum pattern | `lib/providers/data/backing_transport_provider.dart:167-187`, `:235-266` |
| The active backing selector picks the first nonhidden file-backed entry, not an explicitly chosen source | `lib/screens/metronome_screen.dart:454-471` |
| Hidden MIDI IDs are session-local and do not remove Lab records | `lib/providers/data/midi_hidden_provider.dart:3-10` |
| Structure duration is described ambiguously in the model and labeled phrases in the constructor; backing fallback consumes it as bars | `lib/models/section.dart:39-40`; `lib/screens/songs/components/song_constructor/widgets/section_card.dart:75`; `lib/providers/data/backing_transport_provider.dart:243-256` |
| MIDI alignment is already per entry through sectionMap/SectionSpan, with explicit startBar and bars | `lib/models/midi_song.dart:229-257`; `lib/models/section_span.dart:3-18` |
| Arrangement editor independently prefills MIDI bars across song sections, rather than proving their musical correspondence | `lib/widgets/midi/arrangement_sheet.dart:115-125` |
| Lab records and tasks can already link to section IDs; session history has a `midiEntryId` field but **no `lib/` code writes it** (phase 2 D14), and it has no track/section range | `lib/models/song_lab.dart:123-124`, `:204-225`; `lib/models/metronome_session.dart:3-19` |
| Practice is currently a cross-song dashboard, homework and logbook. Homework taps route to Lab, not the exact playable passage | `lib/screens/practice_screen.dart:14-17`, `:44-88`, `:165-170` |
| Concert Mode is explicitly a presentation over the existing metronome state, kept mounted beneath the root route | `lib/screens/concert_mode_screen.dart:12-20`, `:53-77` |
| Tuner already has instrument/tuning metadata useful to a fretboard; do not confuse that string-oriented `Instrument` type with MIDI role or track identity | `lib/models/instrument.dart:1-3`, `:8-28`, `:50-62` |
| Parser records notes and the program at first note; other channel messages such as CC/pitch bend are consumed but not stored as general events | `lib/services/audio/midi/smf_song_parser.dart:124-145` |

### Reliability gates before deeper integration

- **CODE / unexercised failure scenario:** launchpad cancels its 600 ms pending persistence timer on dispose (`lib/widgets/practice/launchpad_view.dart:70-100`). Do not claim this was reproduced as user data loss; add a close-immediately-after-edit test.
- **CODE / concurrency risk:** repository uses `set(..., merge: true)` (`lib/repositories/firestore_lab_repository.dart:63-70`), **not** a nonmerge whole-document replacement. However callers pass snapshots containing existing supplied fields/arrays; merge does not prevent an older supplied value from overwriting a newer one. Field-scoped updates/version checks need a focused design/test, not merely “turn merge on.”
- **CODE / HYPOTHESIS:** arrangement changes can trigger launchpad reattachment (`lib/widgets/practice/launchpad_view.dart:127-165`); this differs from `_reRender`'s resume path (`:103-118`). Do not test by editing a user's live arrangement. Protect this boundary in an isolated fixture/device run.
- **CODE:** iOS launchpad path returns no view (`lib/widgets/practice/launchpad_view.dart:171-174`), while Android/web use the shared transport. Do not advertise uniform platform parity.

## Graphify evidence

Existing `graphify-out/graph.json` was queried, not rebuilt. It reports 12,394 nodes; broad queries were truncated and treated as navigation hints, not proof of completeness. Vocabulary was checked for song, lab, midi, drum, practice, arrangement, transport, instrument, launchpad and section.

Qualified `lib/providers/data/backing_transport_provider.dart::BackingTransportNotifier` exposes EXTRACTED references to `metronomeProvider`, `drumPracticeProvider`, `backingEngineProvider`, `midiSongProvider` and `BackingTransportState`. These were verified in current source above. Unqualified symbols were ambiguous; a directed DrumPracticePanel → SongLabEntry path was not found. Absence of a graph path was **not** treated as absence of a code/data relationship. Source reads found the linkage.

The installed Graphify CLI auto-refreshed installed skill copies during its first query. No graph rebuild or application mutation was requested/performed; subsequent calls disabled auto-refresh. Graph line metadata is not assumed current; report citations use source reads.

## Executed baseline tests

Command:

```sh
flutter test test/models/midi_arrangement_test.dart test/models/song_lab_midisong_test.dart test/midi/midi_pattern_test.dart test/providers/backing_transport_test.dart test/midi/drum_panel_editor_entry_test.dart test/services/midi_song_import_test.dart test/midi/session_midi_link_test.dart --reporter expanded
```

**TEST: exit 0, 56 tests passed.** Output includes an analytics warning about no default Firebase app in the test environment; this did not fail the tests. Existing tests demonstrate a reusable baseline, not that the proposed workspace exists or is verified.

Not run: full Flutter suite/analyzer/build; new instrument widgets; actual keyboard/guitar hardware; new latency/acoustic capture; offline/background/Bluetooth regression; iOS/web device walkthrough; live recording and performance; learner usability tests. Historical `docs/plans/launchpad/DEVICE_PASS.md` was read only and not counted as a current pass.
