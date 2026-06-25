---
categories:
- devlog
date: '2026-06-25T22:15:00+01:00'
draft: false
slug: lazy-on-purpose
summary: "The best code is the code you never write. A philosophy of aggressive laziness, applied to a real codebase audit, kept this project from drowning in cleverness."
tags:
- devlog
- ai
title: "Lazy on purpose"
---

## What changed

I started running the codebase against a deliberately lazy reviewer — one whose whole job
is to ask "does this need to exist at all?"

- The ladder is simple: skip it if it's speculative, use the standard library, use a native
  platform feature, use a dependency you already have, write one line, and only then write
  more. Stop at the first rung that holds.
- Run as an audit, it flags reinvented stdlib, abstractions with one implementation, and
  config for values that never change — the bloat that accumulates when you build for an
  imagined future.
- Concrete payoff in this very project: the history pipeline is one script and a wrapper,
  the poster tools are a few files each, and the metronome drift fix was ~50 lines of
  stdlib instead of a scheduling library.

## Why it matters

Solo projects die two ways: never shipping, or over-building until every change is scary.
Aggressive laziness is the antidote to the second. "What's the least I can write that
actually works?" isn't cutting corners — it's refusing to maintain code that didn't need to
exist. Every line you don't write is a line that can't break at the worst possible time.
