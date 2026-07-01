---
categories:
- devlog
date: '2026-08-18T06:00:00+01:00'
draft: true
slug: autofill-that-actually-fills
summary: "Type a title, get BPM and key for free — and why I didn't seed a catalog of 5,000 songs to do it."
tags:
- devlog
- feature
title: "Autofill that actually fills"
---

## What changed

Search a song title and FlowGroove can fill in its **BPM and key** from Spotify — no
manual entry.

- Spotify is now a search source alongside your library and MusicBrainz. Pick a result
  and its tempo and key drop into the form.
- The tempting alternative was to pre-load a big "common songs" catalog. I didn't — and
  the reason is the interesting part.
- FlowGroove already has a "canonical songs" layer, but it stores *identity*, not tempo
  or key (those fields are blank). Seeding 5,000 generic songs would've been 5,000 empty
  shells — and a cover band's catalog should be the songs its bands actually play, which
  the app fills in on its own as people add them. Spotify, which *does* know tempo and key,
  is the real autofill.
- Songs you write yourself stay first-class — nothing forces an original into a catalog.

## Why it matters

The obvious fix — seed a big list — would've added maintenance, licensing questions and
noise, *without even solving the problem*, because the data I wanted wasn't in it. The
boring question "where does this value actually come from?" pointed straight at Spotify and
saved a whole subsystem I'd have had to feed forever.
