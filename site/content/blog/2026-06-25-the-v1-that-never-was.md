---
categories:
- devlog
date: '2026-06-25T16:00:00+01:00'
draft: false
slug: the-v1-that-never-was
summary: "I tagged v1.0.0, started a big refactor, and then rolled the version number all the way back. Here's why going backwards was the right call."
tags:
- devlog
- war-story
title: "The v1.0.0 that never was"
---

## What changed

The app's version went *down*. I shipped `v1.0.0`, then reverted to `0.11.2+68`
and kept building from there.

- **Symptom:** "1.0" felt like a finish line, so I crossed it — and immediately
  started a major refactor on top of a release I'd just blessed as done.
- **The hunt:** there wasn't a single bug; there was a bad signal. Calling it 1.0
  told everyone (including me) the foundation was settled, right when I was about to
  tear into it. Before the refactor I tagged a "last good version" as an escape
  hatch.
- **The truth:** I reverted the version. 1.0 is a promise about stability, and I
  wasn't ready to make it. Better an honest `0.11` under active surgery than a `1.0`
  that's quietly a construction site.

## Why it matters

Version numbers are communication, not vanity. The escape-hatch tag turned out to
matter more than the milestone — when a refactor goes sideways, "here's the last
thing that definitely worked" is the most valuable commit in the repo. Now I tag
that *before* I start, every time.
