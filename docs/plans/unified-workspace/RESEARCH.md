# Research: a unified musical workspace

2026-10-23 · Primary-source desk research + P30 walkthrough + code inspection. This is a design recommendation, not validated learning efficacy or a finished implementation.

## Method selected

Use a lightweight **Double Diamond**: observe the existing journeys → define the continuity problem → compare a few alternatives → test one thin slice. Design Council explicitly separates Discover, Define, Develop and Deliver [S1]. Do not turn this into a process platform or a months-long redesign.

For this project:
1. **Discover:** the P30 walkthrough and source map in EVIDENCE.md. Next, observe the owner doing a real practice session, plus a keys player and guitarist; an agent inspecting screens is not a substitute.
2. **Define:** the job is “help me understand, isolate, change, rehearse and perform this musical part without reconstructing my context.” It is not “put every feature on one screen.”
3. **Develop:** compare (A) everything inside Lab, (B) a new DAW-like editor, (C) one song workspace with task-focused views. Recommend C; retain A's contextual history and B's useful musical timeline, without their navigation/data-model costs.
4. **Deliver:** an instrument-view selector over existing MIDI/transport, then a narrow end-to-end practice journey. Expand only after the continuity checks pass.

Evaluate each journey with a **cognitive walkthrough**: is the next action discoverable, understandable, and followed by visible progress? This is an inspection method, not user testing [S2]. Measure route changes, lost context, accidental playback/mix changes, and completion without help. Do not optimize tap count at the expense of musical clarity or safety.

## Relevant products: borrow principles, not their entire UI

| Primary source | Verified pattern | Application here | Do not copy |
|---|---|---|---|
| Ableton Live 12, Live Concepts [S3] | Session and Arrangement share tracks; changing the visible view does not itself change playing clips | Instrument diagram, song map and editor should be projections of the same selected material and transport | Two independent arrangements, full device/routing system, desktop-sized Session grid |
| Guitar Pro 8 MIDI import [S4] | Track selection, instrument/tuning configuration, quantization choices and preview before import | One reviewed import path; correct roles and alignment before use; do not silently quantize original material | Full notation engraving or pretending inferred tablature is source truth |
| Guitar Pro 8 quick start [S5] | Fretboard/keyboard input, tuning/capo configuration, relative/fixed/progressive playback speed | Instrument-specific visual surfaces over common note material; practice speed separate from song identity | Automatic fingering asserted as certain, or a new playback engine for each instrument |
| Soundbrenner app manual [S6] | Metronome, song/setlist library, tuner and practice tracking coexist | Preserve useful quick-start and session-history entry points around the shared workspace | Merely bundling tools behind a menu and calling it seamless |
| MIDI Association message overview [S7] | Notes, velocity, pitch bend, program changes and controllers are distinct message types | State the actual import/render fidelity; note-only edits are not lossless MIDI round trips | Claiming piano sustain, guitar expression or all source events survive the current model |

These are documented workflows, not a hands-on competitor benchmark. No paid subscriptions were bought or external apps installed.

## Why this combination fits

- A song workspace solves **continuity**, while the existing Lab remains a journal and the existing Practice page remains an agenda/logbook.
- A section-first map gives every instrument the same place in the song; the instrument view answers what *my part* is doing there.
- One shared transport protects the timing work already present. Changing what is visible must not mean changing what plays.
- Start with faithful read-only instrument diagrams. Complex score generation, automatic guitar voicing, grading and audio transcription are separate bets, not prerequisites.
- A short practice loop can connect goal → listen → isolate → repeat → capture → reflect using current tasks, MIDI and recording concepts. The proposal does not claim this alone proves better learning outcomes.

## Sources

Retrieved/searched on 2026-10-23. Search results were followed to first-party pages; some full HTML fetches were output-truncated, so this report limits itself to the passages available in official page/search content. No claims depend on inaccessible middle sections.

- **S1:** Design Council, The Double Diamond — https://www.designcouncil.org.uk/resources/the-double-diamond/
- **S2:** Nielsen Norman Group, Evaluate Interface Learnability with Cognitive Walkthroughs — https://www.nngroup.com/articles/cognitive-walkthroughs/
- **S3:** Ableton, Live Concepts, Reference Manual 12 — https://www.ableton.com/en/live-manual/12/live-concepts/
- **S4:** Arobas Music, Importing MIDI in Guitar Pro 8 — https://www.guitar-pro.com/docs/gp8/import-export/import/import-midi
- **S5:** Arobas Music, Guitar Pro 8 Quick Start Guide — https://www.guitar-pro.com/docs/gp8/basics/intro/quick-start
- **S6:** Soundbrenner, Manual The Metronome app — https://www.soundbrenner.com/pages/manual-the-metronome-app
- **S7:** MIDI Association, About MIDI, Part 3: MIDI Messages — https://midi.org/about-midi-part-3midi-messages

Agent reviews are drafts, not external authorities. See ORCHESTRATION.md for corrections made by the orchestrator.

## Phase 2 addendum: competitor flows

See `phase2/COMPETITORS.md` (Moises, Melodics, Yousician, Drumeo; first-party sources in `phase2/sources/`, quotes checked as literal substrings). Method is unchanged: this is still Discover → Define in the Double Diamond. The new Define input is the observed micro-run practice pattern (phase2 D12), which makes *section loop + resume* the job to design for first.
