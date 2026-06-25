---
categories:
- devlog
date: '2026-06-25T10:00:00+01:00'
draft: false
slug: why-the-metronome-slowly-drifted
summary: "The FlowGroove metronome used to slide off the beat over a long song. The fix was about 50 lines of stdlib and no new dependency — here's what was actually wrong."
tags:
- devlog
title: "Why the metronome slowly drifted — and the 50-line fix"
---

## What changed

The metronome now keeps time against a wall clock instead of trusting a repeating
timer. A new `WallClockScheduler` tracks an *absolute* target for each tick and
schedules the delay to the next target every time it fires — so any jitter gets
corrected on the spot instead of piling up.

- Old way: a periodic timer re-armed relative to *when the last tick actually
  fired*. Every few milliseconds of lateness carried into the next interval.
- New way: a monotonic `Stopwatch` plus `nextTarget += interval`. The next delay
  is "target minus now", so the click is always steering back toward true time.
- About 50 lines, pure Dart `dart:async`, no new dependency.

## Why it matters

A periodic timer is fine for a few beats. But over a five-minute song that tiny,
constant lateness accumulates, and the click slowly slides off the beat — exactly
when you need it most. A metronome that can't hold time is worse than no
metronome, because you trust it and it lies to you.

Anchoring to a monotonic clock fixes the whole class of problem: errors stop
compounding because every tick is measured against where it *should* be, not
against the last one that was already a hair late. Boring, stdlib, and it just
stays in time now.
