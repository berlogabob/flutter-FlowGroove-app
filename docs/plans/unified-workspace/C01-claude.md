**Answer:** One MIDI song is reached through three surfaces that route and gate it differently. Drum patterns sit outside the entry model. The clearest data-loss path is a 600 ms debounce cancelled on dispose, plus whole-entry saves from stale snapshots. I read only the four assigned files, so anything about `labRepository`, `DrumPracticePanel` or `MidiSongPanel` is unverified.

**Evidence (code read)**

Fragmentation points:
1. **Two lists for one entry type.** `backing_sheet.dart:24-29` filters `labEntriesProvider` to MIDI entries. `song_lab_screen.dart:638-646` opens `MidiSongPanel` directly on tap. Same entry, different panel.
2. **Panel chosen by data shape.** `backing_sheet.dart:73-75` opens `ArrangementSheet` when `sectionMap` is empty and `MidiSongPanel` otherwise. The launchpad menu (`launchpad_view.dart:514-535`) offers edit, add and hide. The Lab offers "Edit" on any entry, MIDI included (`song_lab_screen.dart:684`), and that edit uses the title/body form.
3. **Drums are a separate world.** `backing_sheet.dart:45-51` pushes `DrumPracticePanel` with no entry reference. Nothing in the four files links drum patterns to the Lab or the launchpad.
4. **Three import entry points, three gates.** `backing_sheet.dart:78` uses `canImportMidi`. `song_lab_screen.dart:580` uses `bandId != null || canEditProvider` and `!kIsWeb`. `launchpad_view.dart:540` uses `canImportMidi`.
5. **Platform split.** `launchpad_view.dart:142` and `:173-174` render nothing on iOS. The Lab hides the MIDI tap on web (`song_lab_screen.dart:638`). The backing sheet has no platform gate.

Data-loss risk (highest):
- `launchpad_view.dart:71-74` cancels `_saveDebounce` in `dispose`. Leaving the launchpad within 600 ms of a console change or edit drops that write silently (`:96-100`).
- Whole-entry saves from snapshots: `song_lab_screen.dart:132-135` and `:204-206` save `existing.copyWith(...)` from list snapshots. `arrangement_sheet.dart:53-62` saves `widget.entry.copyWith(...)` from the sheet's open-time copy. `launchpad_view.dart:89-101` writes its own copy. Last writer wins on the whole entry. If `saveEntry` is a full `set()`, a Lab title edit can revert a MIDI arrangement. Check `labRepository` before relying on this.

Live-performance risk:
- Arrangement save → entry stream → `didUpdateWidget` → `_scheduleAttach` (`launchpad_view.dart:131-137`, `:149-169`). That path re-attaches without the resume logic in `_reRender` (`:107-118`). Editing an arrangement during playback likely stops or drops playback. Needs a device test.
- iOS shows no launchpad (`:173-174`), yet the metronome sheet still offers MIDI panels. Pick one behaviour before gigs.

**Proposal (not verified)**
- **Shared workspace:** one screen keyed by `(songId, bandId)`. A segmented instrument selector (Drums / Keys / Guitar / Bass / Other) shows that instrument's backing entry, either MIDI or drum pattern. Practice = launchpad. Learn = Lab entries filtered by instrument. This replaces the backing-sheet list and the Lab MIDI tap.
- **One gate:** a single `canImportMidi` check for every import button.
- **One writer per entry:** flush the debounce in `dispose`. Route arrangement and console edits through one update that merges `midiSong` fields, or re-read before writing.
- **Keep separate:** the Lab journal (decisions, tasks, versions, different history), the MIDI data model and import pipeline, the drum grid, the audio transport and click engine, and arrangement editing (it changes timing, not just display).