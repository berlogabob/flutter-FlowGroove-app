---
categories:
- devlog
date: '2026-06-25T07:30:00+01:00'
draft: true
slug: the-tone-matrix
summary: "Accents tell you which beats are loud. The Tone Matrix lets each beat have its own voice — and it's the feature I'm quietly proudest of."
tags:
- devlog
- metronome
title: "The Tone Matrix"
---

## What changed

The metronome went from "loud beat / quiet beat" to per-beat *tone* control.

- An accent only changes volume. But a real click track often wants different
  *sounds* — a high blip on one, a low thud on the downbeat, a tick on the
  subdivisions — so your ear can lock on without thinking.
- The Tone Matrix is a grid where each cell is a beat (or subdivision) with its own
  pitch/tone. You're not setting a pattern of louder and softer; you're composing the
  click itself.
- It shipped with unit tests, because once a feature has this many states, "looks
  right" stops being good enough.

## Why it matters

This is the feature where the metronome stopped being a utility and became an
*instrument setting*. The difference between practicing to a click you tolerate and
one you actually want on is whether it gives your ear something to grab. The Tone
Matrix is that grab.
