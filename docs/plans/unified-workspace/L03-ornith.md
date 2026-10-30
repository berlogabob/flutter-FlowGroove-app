**Eight prioritized failure/acceptance scenarios**

1. **Original preservation (highest).** Editing a draft must never mutate the source song. Acceptance: "save copy" produces a versioned copy; original checksum unchanged; draft edits operate only on the copy. Failure: user edits draft, original overwritten or corrupted.

2. **Live safety during performance.** Section launches must be deterministic and never stall mid-set. Acceptance: launches are pre-buffered with no I/O during playback; no crash, hang, or dead air. Failure: lookup/network stall causes silence on stage.

3. **Song vs. practice tempo.** Slowing for practice must not alter pitch or the song's canonical tempo. Acceptance: time-stretch preserves pitch; practice tempo is session-local; song tempo is unchanged on export. Failure: slow playback shifts pitch; practice tempo leaks into the recorded take.

4. **Section edit scoping.** Edits must be confined to the selected section and reversible. Acceptance: edit is section-scoped, undoable, and diff-able against the saved copy. Failure: edit bleeds into adjacent sections.

5. **Repeated/looped sections.** Loop points must seam cleanly; repeat counts must hold. Acceptance: sample-accurate loop with no boundary click; section repeat count respected across takes. Failure: gap/click at loop boundary; repeat count resets unexpectedly.

6. **Instrument switching.** Switching instruments mid-section must not drop notes or stall. Acceptance: switch is instant, voice assignment updates, no audible gap. Failure: dropout or wrong timbre on the next section.

7. **Offline operation.** Full practice must work with no network. Acceptance: all assets cached; no blocking calls during import, playback, or loop. Failure: MIDI import or playback stalls offline.

8. **Alignment & role mapping.** Imported multitrack MIDI roles must align to the song map. Acceptance: roles correctly assigned, alignment holds post-import; misalignment flagged. Failure: roles swapped or drift from the map.