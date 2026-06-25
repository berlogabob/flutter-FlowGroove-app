---
categories:
- devlog
date: '2026-06-25T09:00:00+01:00'
draft: true
slug: pulling-bpm-and-key-from-musicbrainz
summary: "To fill in song details automatically, the app needed a real music database behind it. Here's wiring up MusicBrainz and a suggestion layer."
tags:
- devlog
- songs
title: "Pulling BPM and key from MusicBrainz"
---

## What changed

Autocomplete got a real brain: a MusicBrainz integration plus a song-suggestion
service feeding the add-song form.

- MusicBrainz is an open music encyclopedia — start typing a title and it returns
  real releases, artists, and metadata instead of you guessing.
- A suggestion service sits on top, ranking and shaping results so the dropdown
  surfaces the version you actually mean, not a wall of obscure pressings.
- It's wired straight into the add-song screen, so the lookup happens where the work
  is, not in some separate "import" mode you'd forget existed.

## Why it matters

The promise from the last post — "type the title, get the data" — needs a source of
truth, and standing up your own song database is a non-starter for a solo dev. Leaning
on an open, community-maintained one meant the autocomplete could be genuinely useful on
day one. The hard part wasn't the lookup; it was choosing *which* result to trust, which
is the next post.
