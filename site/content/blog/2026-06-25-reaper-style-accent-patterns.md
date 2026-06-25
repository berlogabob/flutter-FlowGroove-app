---
categories:
- devlog
date: '2026-06-25T07:15:00+01:00'
draft: false
slug: reaper-style-accent-patterns
summary: "A metronome that only goes \"tick tick tick\" is useless for anything in 7/8. Stealing the accent grid from a DAW fixed that."
tags:
- devlog
- metronome
title: "Reaper-style accent patterns in a phone metronome"
---

## What changed

The metronome stopped being a flat pulse and learned to emphasize the right beats.

- A plain click can't tell you where "one" is. For odd time signatures or a song
  with a strong backbeat, that's the whole game.
- I modeled the accent editor on what DAWs like Reaper do: a grid of beats you tap
  to set strong, normal, or silent — so the bar actually *sounds* like the song's feel.
- Subdivisions and Tap BPM landed alongside it: tap a tempo in by feel, then split
  each beat into eighths or triplets to practice tight passages.

## Why it matters

Musicians don't think in "BPM 120." They think in "the chorus hits hard on 2 and 4."
A metronome that can express accents speaks the same language as the people using it.
Borrowing the interaction from tools players already trust meant zero learning curve —
it just felt familiar the first time they opened it.
