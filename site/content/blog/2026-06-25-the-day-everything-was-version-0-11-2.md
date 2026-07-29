---
categories:
- devlog
date: '2026-06-25T17:00:00+01:00'
draft: true
slug: the-day-everything-was-version-0-11-2
summary: "My git history has 233 releases and 235 of the commits just say \"Release\". A robot makes them while I sleep — and cleaning up that mess is why this whole blog series exists."
tags:
- devlog
- meta
title: "The day everything was version 0.11.2+68"
---

## What changed

I stopped trusting my own git log — and built something that could be trusted
instead.

- **Symptom:** the history is 876 commits, but 235 of them just say
  `Release x.y.z+N`. A background loop auto-commits and deploys my working-tree
  edits, so the timeline is mostly the robot bumping build numbers, with the real
  story buried underneath.
- **The hunt:** to write *anything* about how the app was built, I first had to
  separate signal from noise — the ~635 changes that actually shipped a feature or
  fixed a bug, from the version-bump churn.
- **The truth:** I wrote a small script that reads the git log into a structured
  history file, collapses the 235 release commits into a compact version timeline,
  and renders a human changelog. The noise becomes one tidy list; the real changes
  become the story.

## Why it matters

This is the post that explains the others. Every devlog in this series is mined
from that generated history — including this one. The robot keeps shipping; the
script keeps the record honest; and now there's a source of truth I can turn into
words instead of squinting at `git log`.
