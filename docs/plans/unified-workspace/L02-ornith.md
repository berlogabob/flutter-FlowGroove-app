## Instrument-View Matrix

Four data dimensions drive every view: **pitch**, **tick** (start time), **duration**, **velocity**.

| View | Pitch | Tick | Duration | Velocity |
|------|-------|------|----------|----------|
| Drums kit diagram | kit piece (mapped) | — | — | pad intensity |
| Drums step grid | kit column | grid position | step width | bar height |
| Keys keyboard | key position | play cursor | — | key color |
| Keys piano roll | vertical row | horizontal axis | bar width | color/height |
| Guitar fretboard | string × fret (one voicing) | play cursor | — | hit intensity |
| Guitar note editor | vertical row | horizontal axis | bar width | color/height |

**Shared layer:** song map (section markers: intro/verse/chorus), a single playback cursor synced across all views, and imported MIDI as the source of truth for pitch/tick/duration/velocity.

## Ambiguity (what views must NOT claim)

- **Hands / fingers:** MIDI stores notes, not hands or fingers. The piano roll and keyboard cannot show which hand plays a note; no view should assert a fingering. For drums, left/right stick is likewise unencoded.
- **Guitar string / fret:** a single pitch maps to many string×fret positions. The fretboard therefore shows a *candidate* voicing, not the performed one. If the imported part carries no string/fret data, render that cell as ambiguous (outlined, not solid) and never label it "the fingering."

## Manual correction

Any edit in any view writes back to the shared MIDI model and propagates to every other view and to playback. Editing the fretboard may *constrain* a voicing (pin a string/fret) but must not fabricate string/fret data for notes that lack it.

## Minimum editing

Auto-map drum kit names to pads and auto-suggest a fretboard voicing, both clearly marked as suggestions. Only change what is genuinely wrong; leave correct data untouched.

## 3 acceptance checks

1. **Fidelity:** after importing a known MIDI, every note's pitch, tick, duration, and velocity matches the source within tolerance across all six views.
2. **Propagation:** editing a note in one view reproduces the identical change in all other views and in playback.
3. **No invented truth:** for a pitch with multiple valid voicings, the fretboard displays a candidate and never asserts a single string/fret as the correct fingering.