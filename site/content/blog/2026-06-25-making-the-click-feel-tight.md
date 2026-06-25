---
categories:
- devlog
date: '2026-06-25T08:15:00+01:00'
draft: true
slug: making-the-click-feel-tight
summary: "A metronome that's mathematically on time can still feel loose. Tightness is partly perception — vibration, focus, and what your body feels."
tags:
- devlog
- metronome
title: "Making the click *feel* tight"
---

## What changed

Beyond the raw timing, the metronome got the touches that make it *feel* locked-in.

- **Vibration sync:** the haptic buzz lands with the audio, so even with the sound
  down you can feel the beat — useful on a loud stage or with one earbud out.
  Different beats get differentiated haptics so the downbeat feels different.
- **Focus manager:** the app holds audio focus properly so a stray notification or
  background sound doesn't duck or stutter the click.
- These shipped with a drift test, because "feels tight" needs a number behind it —
  perception is the goal, measurement is the proof.

## Why it matters

Timing is half math, half feel. You can be perfectly on the grid and still feel loose
if the haptics drift from the audio or the OS keeps interrupting you. Tightening the
*experience* of the beat — not just its timestamp — is what makes players stop noticing
the metronome and start trusting it.
