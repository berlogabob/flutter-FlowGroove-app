---
categories:
- devlog
date: '2026-06-25T09:30:00+01:00'
draft: true
slug: band-songs-are-copies-not-links
summary: "When you add a song to a band, you get your own copy — not a link to a shared original. That was a deliberate call, and it has consequences."
tags:
- devlog
- songs
title: "Band songs are copies, not links"
---

## What changed

A song added to a band is an independent copy, not a pointer back to a shared master.

- Your band wants *its* arrangement: your key, your BPM, your structure notes. If
  every band edited one shared original, you'd be fighting each other's changes.
- So a band song is a real, separate document. Edit it freely without touching anyone
  else's version of the same tune.
- The consequence surfaced in editing: to change a band song you need the band's
  context — the edit route has to carry the `bandId`, or it edits the wrong thing (or
  nothing). A subtle bug hid there until the routing made the ownership explicit.

## Why it matters

"Copy vs. link" looks like a tiny data-modeling choice and quietly shapes the whole
collaboration model. Copies mean autonomy and a few extra duplicates; links mean
sharing and constant edit conflicts. For bands — who each play a song their own way —
autonomy won. But every copy you make is a decision you have to keep honoring in the
plumbing.
