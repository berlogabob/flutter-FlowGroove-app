---
categories:
- devlog
date: '2026-06-25T07:45:00+01:00'
draft: false
slug: silent-on-bluetooth
summary: "Plug in Bluetooth headphones mid-session and the click goes laggy or silent. The audio engine bound to your speaker once and never looked again."
tags:
- devlog
- war-story
title: "It's dead silent on Bluetooth headphones"
---

## What changed

Switching audio routes — speaker to Bluetooth, headphones in or out — no longer
breaks the metronome.

- **Symptom:** start the click on the phone speaker, connect Bluetooth headphones,
  and it goes laggy or silent. The beat was playing to a device that was no longer
  there.
- **The hunt:** the low-latency engine binds to an audio device *once*, at init, for
  speed. Great for latency, terrible for the real world where players swap headphones
  mid-rehearsal. There was no route-change handling at all.
- **The truth:** the engine now listens for route changes and rebinds — without
  spuriously "recovering" into a phantom start, and restoring haptics on the new route
  so the silent-but-buzzing fallback still works.

## Why it matters

Hardware doesn't sit still. The first version assumed the audio output you start with
is the one you finish with, and rehearsal rooms laugh at that assumption. Handling the
messy physical reality — devices appearing and vanishing — is the difference between a
demo and a tool you'd actually trust on stage.
