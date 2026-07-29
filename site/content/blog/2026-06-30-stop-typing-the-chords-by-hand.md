---
categories:
- devlog
date: '2026-08-16T06:00:00+01:00'
draft: true
slug: stop-typing-the-chords-by-hand
summary: "\"I don't want to set anything up by hand — I want to say what to do and have it done.\" So: paste, preview, import."
tags:
- devlog
- feature
title: "Stop typing the chords by hand"
---

## What changed

You can paste a block of lyrics-and-chords and FlowGroove turns it into a song —
sections and all.

- **The ask:** the same guitarist put it perfectly — "I just want to paste the
  text and have it ready." Manual, section-by-section entry is where good
  intentions go to die.
- **How it works:** paste ChordPro or plain lyrics with `[chords]`; lines like
  `[Verse 1]` or `Chorus:` split it into sections, chord lines stay chord lines,
  and stray metadata is ignored. A live preview shows exactly what you'll get
  before you hit import.
- **The bigger plan:** this is step one toward prepping a song in whatever AI you
  already use — paste its output, import, done — without FlowGroove ever paying
  for AI tokens. A proper MCP connector comes later, built on this same format.

## Why it matters

The fastest data entry is the data entry you don't do. Reusing the ChordPro format
I'd already built for *display* meant "import" was mostly a smart text-splitter,
not a new subsystem. And it sets up the real prize — point your own assistant at
FlowGroove — without committing to a heavy integration before the format
underneath it is solid.
