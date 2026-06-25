---
categories:
- devlog
date: '2026-06-25T15:00:00+01:00'
draft: true
slug: the-provider-that-touched-everything
summary: "I turned the codebase into a graph to ask a simple question — why does one provider connect to thirty other things? — and found coupling I couldn't see by reading files."
tags:
- devlog
- war-story
title: "The provider that touched everything"
---

## What changed

I started untangling hidden coupling — the kind you can't spot by scrolling
through files one at a time.

- **Symptom:** small changes near the band and metronome screens kept causing
  surprises in unrelated places. Nothing looked wrong in any single file.
- **The hunt:** I built a knowledge graph of the whole repo and asked it which
  nodes connect to what. One provider lit up linked to ~30 others across screens
  that shouldn't have known about each other. The coupling was real; it was just
  invisible at file scale.
- **The truth:** the fix is the same one every time — pull the shared thing out and
  give it a clean seam. The first concrete cut: extracting the metronome engine and
  decoupling it from the platform `MethodChannel`, so the audio logic stops dragging
  UI and platform plumbing along with it.

## Why it matters

You can read every file in a project and still not see its *shape*. A graph makes
coupling visible, and once it's visible it's fixable. As FlowGroove grew, "what
connects to what" became a more useful question than "what does this file do."
