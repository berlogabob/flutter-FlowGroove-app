---
categories:
- devlog
date: '2026-06-25T08:00:00+01:00'
draft: true
slug: instant-first-beat
summary: "Hit play and the very first beat was a hair late. Fixing it meant doing the slow work before you ever press the button."
tags:
- devlog
- metronome
title: "Instant first beat"
---

## What changed

The first beat now fires the instant you hit play, instead of arriving slightly late.

- **Symptom:** every beat after the first was perfectly on time, but beat one lagged.
  In a metronome, the very first beat is the one you're counting in on — so it's the
  worst one to get wrong.
- **The cause:** spinning up the audio engine and loading the sound took a few
  milliseconds, and that cost landed *on* the first tick because the engine warmed up
  when you pressed play.
- **The fix:** pre-initialize the audio before it's needed. By the time you tap start,
  the engine is already warm and the sound is already loaded, so beat one is as tight
  as the rest.

## Why it matters

Latency you can predict, you can move. The trick wasn't making startup faster — it was
making startup happen *earlier*, off the critical path, so the user never pays for it.
A lot of "feels instant" is really "did the slow part before you asked."
