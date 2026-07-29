---
categories:
- devlog
date: '2026-08-17T06:00:00+01:00'
draft: true
slug: the-cyrillic-song-that-gate-crashed-my-search
summary: "Search for \"hit the road jack\" and a Russian-titled track topped the list. One source wasn't playing by the scoring rules."
tags:
- devlog
- war-story
title: "The Cyrillic song that gate-crashed my search"
---

## What changed

Add-song search now returns the song you actually searched for.

- **Symptom:** a tester typed "hit the road jack" and the top autofill suggestion
  was a Cyrillic-titled track — not the Ray Charles song.
- **The hunt:** every suggestion source scored each candidate against your query and
  dropped the weak matches — *except* MusicBrainz, which dumped every result in with a
  flat, high score. So its noisiest hits (foreign covers, same-title oddities) rode
  straight to the top.
- **The fix:** score MusicBrainz results the same way as every other source, and filter
  the weak ones out. A Cyrillic title scores near-zero against a Latin query, so it's gone.

## Why it matters

Consistency is a feature. The bug wasn't a bad algorithm — it was one code path that
skipped the rules the others followed. When every source plays by the same scoring, the
ranking just works, and the fix is *deleting a special case*, not adding cleverness.
