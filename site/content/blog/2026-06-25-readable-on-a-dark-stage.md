---
categories:
- devlog
date: '2026-06-25T08:30:00+01:00'
draft: true
slug: readable-on-a-dark-stage
summary: "Stages are dark and you're looking from three meters away. The metronome's visual polish is really about being readable at a glance."
tags:
- devlog
- design
title: "A metronome you can read on a dark stage"
---

## What changed

The metronome got a visual pass built for the place it's actually used: a dim stage,
glanced at from a distance, between songs.

- A central tempo circle that pulses with the beat — something you can read from your
  peripheral vision without staring at the screen.
- Visual polish tuned for contrast, not decoration. Dark theme isn't a black
  background; it's making the important thing pop when the room is dark and your eyes
  are on the audience.
- Big, glanceable state: am I running, what's the tempo, where's the downbeat —
  answerable in half a second.

## Why it matters

Nobody wants a flashlight on stage. The constraint that shaped every visual decision
is that the user isn't sitting at a desk — they're performing, in low light, with
their hands full. "Looks nice" came second to "can I read this without breaking eye
contact with the crowd." Design for the room, not the mockup.
