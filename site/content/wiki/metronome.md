---
title: "Metronome"
---

# Metronome

Practice to a steady beat.

- Set the tempo (BPM) and time signature with the two dot rows.
  - **Top row, main beats:** one dot per beat of the bar (the top number of
    the time signature, 1–12). `−` and `+` change how many beats.
  - **Bottom row, subdivision:** how many clicks each beat is split into
    (1 = just the beat, 2 = eighths, 3 = triplets, 4 = sixteenths).
  - Dot `i` of the bottom row sits under beat `i` of the top row.
- Change the tempo by dragging the white knob on the dial, with the −5 / −1 / +1 / +5 buttons, or by tapping the BPM number to type it. Tapping elsewhere on the ring does nothing, so a stray touch cannot change a song's tempo.
- Tap accents to emphasize beats.
- **Menu (⋯)** in the bottom bar holds Sound, Count-in, Ramp, Haptics and the
  save-to-song actions; toggles flip right inside the sheet.
- Unloading the current song can be undone from the snackbar.
- On the web, audio uses the Web Audio engine automatically.

## Backing tracks and the launchpad

Load a song that has a MIDI file in its Lab and the metronome shows one **pad**
per section (Intro, Verse, Chorus…). Tap a pad to play that section; the click
and the backing always play from one clock, so they stay in time.

- **Play / Stop** — one button. Stop ends the click and the backing; hold it to
  stop the backing at the end of the bar and keep the click going.
- **Mode** — what a pad does when its section ends:
  - **Once** plays the section one time, then stops the backing.
  - **Loop** repeats the section until you tap another pad or Stop.
  - **Song** plays on through the following sections to the end of the song.
    The highlighted pad follows the section being played.
- **Quantize** — when a tapped pad starts:
  - **Beat** on the next beat, **Bar** on the next bar.
  - **Block** after the section that is playing has finished, so the next block
    starts exactly where the previous one ends. With nothing playing it starts
    at the next bar.

A pad that is waiting shows what it is waiting for ("Next bar", "Next block").

The MIDI file of a song is kept on your phone after the first time it loads, so
the launchpad also opens with no network. Open each gig song once while online.
