# Competitor practice flows: Moises, Melodics, Yousician, Drumeo

2026-10-23 · Desk research from first-party pages only (help centers via the Zendesk API, product pages via curl, and Drumeo/Musora pages found by Claude Haiku). Raw text: `sources/`. Every row below rests on a quote that was **checked mechanically as a literal substring** of the fetched source (`fg_p2_local.py quote_check`; C02 excerpts re-fetched and checked sentence by sentence). It was then **checked for meaning** by GPT-6 Luna (O03) and Hermes. Rows judged WRONG are dropped, and OVERREACH rows are reworded or marked.
These are documented features, not hands-on tests, so pricing, quality and accuracy were not evaluated.

## Pattern matrix (verified)

| Practice pattern | Moises | Melodics | Yousician | Drumeo | FlowGroove today |
|---|---|---|---|---|---|
| **Loop a section** in one gesture | tap an auto-detected section → it loops | click in the timeline to set a loop | move the loop sliders | "Create practice loops for the tricky parts" | launchpad pads can loop (D09). Sessions show micro-runs instead (D12) |
| **Change practice speed** | not verified from quotes¹ | auto-raises the speed "by 10 BPM if you're nailing it" (needs scoring) | tempo slider "at your own pace" | "Control the tempo" | tempo dial + Ramp in the menu; MIDI rescheduling |
| **Remove my part / isolate** | mute (M) / solo (S) per separated stem | — | "Mute song", plus piano: toggle one hand off | "Remove the drums so you're the drummer" | per-track mute/solo in the Lab mixer (D08); no one-tap "without me" |
| **Count-in** | configurable count-in before playback | — | "Loop lead-in: one-bar count-in at restart" | not verified | Count-in in the metronome menu; not tied to a loop restart |
| **Sections as navigation** | AI-identified sections | loop points over the arrangement | slider range | "break down tricky sections" | `Song.sections` + MIDI `SectionSpan` (phase 1) |
| **Instrument visual** | chords & diagrams "in sync with the song" | pads light up (blog tip) | chord shape on the fretboard (lesson aid, overreach as app feature) | scrolling notation ("Follow along") | drum kit schematic only (D05) |
| **Feedback on playing** | — (the click is not feedback) | real-time accuracy | "Wait To Play" until the correct note | — | none (out of scope) |
| **Progress log** | — | — | learning path | "Progress Tracker captures every lesson, practice session, and performance" | 51 micro-sessions, no "what" (D12–D14) |
| **Own material** | upload from library or URL | "can't create your own lessons" | not in sources | not in sources² | **own MIDI import + pattern editor + band context** |

¹ L05 cited a metronome-speed quote, and O03 marked it WRONG. Help titles mention "changed key/speed" export, but no quote was extracted. Treat as unverified.
² Drumeo's only related mention is a Moises workaround (third-party tool).

## What to borrow, in order of value per effort

1. **Section → loop in one tap, with a lead-in count-in on each restart** (Moises + Yousician). This directly answers D12: a drummer looping a fill now stops and starts the whole transport, and each restart becomes a new "session". Reuse launchpad loop + the existing count-in. No new engine.
2. **"Play without me"** as one named toggle for the selected part (Drumeo, Yousician "Mute song", Moises solo/mute). The phase-1 proposal already has it. Competitors confirm it is *the* core play-along control, so it belongs in the transport bar, not inside the mixer.
3. **Resume what I practiced.** Each competitor log/path knows the lesson or song part. FlowGroove should log song + source + track + section/loop + tempo per practice context, and offer "Continue: Back to Black · Chorus 2 · drums · 90 %". The fields partly exist (`midiEntryId`, task `sectionId`), but nothing writes them (D14, D16).
4. **Tempo steps per loop**, not scoring. Melodics' auto +10 BPM needs accuracy detection. The FlowGroove equivalent is the existing Ramp applied to the active loop ("+5 BPM every N reps"). No audio analysis.
5. **Synced visual for the part** (Moises chord diagrams in sync, Drumeo scrolling notation, Melodics lit pads). This confirms the phase-1 order: drum kit → keyboard → fretboard, driven by the same transport cursor.

## Explicitly not borrowed

- Scoring/"wait to play"/accuracy (Melodics, Yousician): needs reliable input detection per instrument. That is a separate bet, not part of unification.
- AI stem separation/section detection (Moises): FlowGroove's material is MIDI with known tracks, and sections come from `Song.sections`. Auto-detection would be a new service.
- Lesson catalogs/learning paths (all four): FlowGroove's unit is *your band's song*, not a curriculum.

## Positioning signal

None of the four, per their own pages, lets the user bring their own multi-track MIDI, edit drum/keys/guitar parts, and practise those parts against the band's song map. Moises (own audio, stems, chords, setlists) comes closest. The unified workspace is the differentiator, so its continuity matters more than adding feature breadth.
