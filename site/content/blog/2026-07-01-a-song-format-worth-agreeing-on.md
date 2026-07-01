---
categories:
- devlog
date: '2026-08-19T06:00:00+01:00'
draft: true
slug: a-song-format-worth-agreeing-on
summary: "Before an AI can fill your library, it needs to know the shape of a song. So I wrote one down."
tags:
- devlog
- feature
title: "A song format worth agreeing on"
---

## What changed

FlowGroove now has a documented, versioned **Song JSON** format — and prompts that make
any AI speak it.

- **The format:** title, artist, key, BPM, and sections with chords-over-lyrics (ChordPro).
  One page, one worked example, a version number.
- Export any song to it and paste it back — the importer validates and previews before
  anything is saved.
- The app can hand you a **ready-made prompt**: copy it, paste into ChatGPT / Claude /
  Gemini, and the model returns an importable song. FlowGroove spends no AI tokens; you use
  whatever assistant you already pay for.

## Why it matters

"Add AI" usually means "add an AI bill." Writing a stable format instead means the
intelligence lives in whatever model the user brings, and FlowGroove just has to read and
write one clean shape. A documented contract is boring — and it's exactly what lets the next
features (paste-import, prompts, and a full agent endpoint) all reuse the same ~250 lines.
