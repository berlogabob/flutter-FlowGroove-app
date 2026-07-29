---
categories:
- devlog
date: '2026-08-15T06:00:00+01:00'
draft: true
slug: chords-over-the-right-syllable
summary: "A guitarist told me he couldn't actually play from the app. So songs got lyrics with chords above the words — on screen and on paper."
tags:
- devlog
- feature
title: "Chords over the right syllable"
---

## What changed

A song can now hold lyrics with chords sitting above the exact syllable they land
on — and you can play from it full-screen or print it.

- **The blocker:** a cover-duo guitarist tried FlowGroove and was blunt — without
  chords aligned over the words, he can't follow a song. Tuner, metronome,
  setlists: all secondary to that one thing.
- **The format:** instead of inventing something, I used **ChordPro** — the
  decades-old standard where you write `[Am]Twinkle [F]little [C]star` and each
  chord renders above the syllable it precedes. One small parser turns that into
  the on-screen layout, drives transpose, and feeds the PDF.
- **The view:** a stage-readable performance screen that keeps the display awake
  (he'd complained the web screen dimmed mid-song), with one-tap transpose up or
  down for "our key."
- **The paper:** because bands still play from a binder, an Export-PDF button
  prints the same chords-over-lyrics sheet at the current transpose.

## Why it matters

I'd been building tools *around* songs — tempo, tuning, lists — when the thing a
musician needs most is the song itself: readable, in our key, on a stand or on
paper. Choosing a thirty-year-old text format over a clever custom editor meant a
single parser does the screen, the transpose *and* the print, and it round-trips
with anything else that speaks ChordPro. "Digital first, paper always" turned out
to be a feature, not a fallback.
