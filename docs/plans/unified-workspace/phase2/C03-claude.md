| ID | Verdict | Evidence file:line | Note (<=20 words) |
|---|---|---|---|
| D13 | TRUE | `lib/providers/data/metronome_provider.dart:841-885`; `lib/models/metronome_session.dart:48-60` | Session stores song, setlist, BPM, bars. No section, loop or track fields. `midiEntryId` exists but is unset (D14). |
| D14 | TRUE | `lib/models/metronome_session.dart:32,89,106`; `test/midi/session_midi_link_test.dart:25,66` | Only `fromJson`/`copyWith` pass-through and tests set it. No `lib/` caller. Graphify not verified. |
| D16 | PARTLY | `lib/screens/songs/song_lab_screen.dart:907-925`; section picker at `:787-800` is entries-only | Task sheet has an assignee dropdown for band songs, so "text + due date" omits it. `SongTask.sectionId` exists, unpicked. |
| D21 | TRUE | `lib/screens/songs/song_lab_screen.dart:165-169,582-584`; `lib/widgets/midi/midi_import_flow.dart:55-63,66-86` | Picker opens first, preview before save. Save runs only from `onSave`; cancelled pick returns early. |