---
categories:
- devlog
date: '2026-06-25T18:00:00+01:00'
draft: true
slug: setlists-that-survive-a-coffee-spill
summary: "The whole app started because we lost a paper setlist. So setlists had to be the thing paper never could be — shared, reorderable, and impossible to misplace."
tags:
- devlog
- setlists
title: "Setlists that survive a coffee spill"
---

## What changed

Setlists became first-class: build them, reorder them, attach the songs, and share
them across the whole band.

- Drag songs into order, and that order is the order everyone sees — no more three
  phones showing three different versions.
- Setlists carry real song links (with all that auto-filled metadata) and even an
  event date/time, so "Saturday's set" is a thing the app understands, not a note.
- Getting the flow right took its share of fixes — creation, parsing, back-navigation —
  the unglamorous polish that makes a feature feel solid.

## Why it matters

This is the feature the entire app was born to fix. We lost a paper setlist one too many
times, and paper has no superpowers: it can't sync, can't reorder cleanly, and absolutely
can soak up a spilled drink. A digital setlist that's shared and reorderable isn't a
fancy version of paper — it's the thing paper kept failing to be. Closing that loop felt
like finishing the original sentence.
