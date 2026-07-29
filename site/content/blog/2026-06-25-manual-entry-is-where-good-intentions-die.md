---
categories:
- devlog
date: '2026-06-25T08:45:00+01:00'
draft: true
slug: manual-entry-is-where-good-intentions-die
summary: "The fastest way to make sure a band never logs its songs properly is to ask them to type in the BPM by hand."
tags:
- devlog
- songs
title: "Manual entry is where good intentions die"
---

## What changed

The whole approach to adding a song flipped: the app should already know most of it.

- Ask a band to fill in tempo, key, and metadata for every song and they'll do it for
  three songs and then stop forever. Manual entry has a half-life measured in days.
- So adding a song became "type the title, get the data." The BPM, the key, the
  details fill themselves in — the human supplies intent, the app supplies the rest.
- The rule I set early on: a song should take *seconds* to add. Slower than that and
  the band won't bother, and an app nobody fills in is an empty app.

## Why it matters

Every data-entry feature is really a bet on human patience, and that bet almost always
loses. The features in the next few posts — MusicBrainz lookups, canonical songs,
dedupe — all exist to honor one promise: you shouldn't have to type what a computer can
already look up. Friction is the enemy of adoption.
