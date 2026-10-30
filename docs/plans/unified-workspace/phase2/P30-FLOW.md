# P30 walkthrough, phase 2: the real user flow

2026-10-23 · device `XPH0219904001750` (Huawei P30, `com.flowgroove.app` 0.28.0/367) · HEAD `e01797d8` · read-only.
Phase 1 covered Song → Lab → Backing → Drums → Pattern editor → Launchpad (see `../EVIDENCE.md` D01–D10). This pass covers the surfaces around it: Home, Practice, Recorder, Rehearsals, Concert Mode, Setlists, Lab tasks and Import.
Navigation used `uiautomator` text dumps (exact UI strings below) plus screenshots in `evidence/`.

## What a session actually looks like (D11–D21)

| ID | Kind | Observation | Evidence |
|---|---|---|---|
| D11 | DEVICE | Home = weekly stats + Quick Actions (Add song/band/setlist, Audio note) + **Tools**: Tuner, Metronome, Rehearsals, Recorder, Practice. Five separate tiles; the song is not the entry point. | `p2-home.png` |
| D12 | DEVICE | Practice: "Practiced 51 min this week across 51 sessions". Recent sessions: 5 s, 11 s, 24 s, 37 s, 1 min, 3 min… all "Back to Black · 123 BPM". Rows are not tappable. | `p2-practice.png` |
| D13 | CODE | Each Play→Stop is one `MetronomeSession` (`metronome_provider.dart:841-885`): song, setlist, BPM, bars. No section, loop, track or MIDI entry. | source |
| D14 | CODE | `MetronomeSession.midiEntryId` exists and round-trips in `test/midi/session_midi_link_test.dart`, but **nothing in `lib/` writes it** (grep: model + test only). Graphify has no path either. This corrects phase 1's EVIDENCE line that history "already stores MIDI entry ID": the field exists, but nothing populates it. | grep, graphify |
| D15 | DEVICE | Practice → Homework: "Nothing open. Open a song, then its Lab tab, to add tasks." | `p2-practice.png` |
| D16 | DEVICE+CODE | Lab → Tasks → Add task (personal song): text + due date. Band songs also get an assignee dropdown (`song_lab_screen.dart:907-925`, C03). `SongTask.sectionId` exists in the model, but the task form has no section picker. The picker exists only for Lab *entries* (`:787-800`). | `p2-add-task-form.png` |
| D17 | DEVICE | Recorder: takes named "Take · 17/7" etc., with `Trim & notes…`, `Link to song…`, `Delete`. Takes are linked to a song after the fact; no section or tempo. | `p2-recorder.png` |
| D18 | DEVICE | Song card → Metronome: tempo dial dominates; loaded song + "Backing tracks" at the bottom edge; no song map visible. | `p2-song-metronome.png` |
| D19 | DEVICE | Concert Mode: title, big BPM, Play, ±1/±5. Lyrics & chords: Verse labels, transpose, **auto-scroll in px/s (35 px/s)**, which is independent of BPM/sections. No current/next section, no backing state. | `p2-concert*.png` |
| D20 | DEVICE | Setlist → Open in metronome: prev/next arrows and "testo tiras • 1 / 2" (setlist lists 6 songs; cause of 1/2 not investigated). Same metronome screen; no sections. | `p2-setlist-metronome.png` |
| D21 | DEVICE+CODE | Lab → Import MIDI opens the system picker directly. Code shows a `MidiImportScreen` preview *after* picking and before save (`midi_import_flow.dart:55-88`). Not picked, nothing imported. | `p2-import-step1.png` |
| D22 | DEVICE | Song opens on the **Edit** tab (metadata form + Save Changes); Sheet and Lab are siblings. | live dump |

Side effects: none saved. Setlist → metronome replaced the *runtime* loaded song; Back to Black was then reloaded from its song card and confirmed (123 BPM, "Back to Black • Personal"). One accidental Back from Home exited to the launcher, and a tap landed in Google Messages. It was left immediately via Home, with no interaction. No app data was involved.

## What the flow says

1. **Practice is micro-runs.** 51 sessions in 51 min means start/stop loops of seconds. That is what a section loop looks like when the app has no loop context. The log can't say *what* was looped, so the next day can't resume it. This is the strongest real-flow signal for J1/J5.
2. **Five tools, no shared context.** Metronome, Recorder, Practice, Tuner and Lab each start from zero. Recorder takes, tasks and sessions are linked to a song afterwards or not at all.
3. **Perform = metronome + setlist arrows.** Concert Mode and lyrics scrolling don't know sections or the backing. The launchpad (phase 1 D09) knows sections but isn't the Concert surface.
4. **Song opens as a form.** A musician's first screen on a song is metadata editing, not "play/practice this".
5. **Linkage fields exist but are unused** (`midiEntryId`, `sectionId` on tasks in the model, the task form without a section). The cheapest wins are wiring, not new models.
