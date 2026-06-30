---
categories:
- devlog
date: '2026-08-14T06:00:00+01:00'
draft: true
slug: the-band-that-took-too-long-to-create
summary: "A real user created a band, set the phone down waiting, and forgot it existed. Four round trips became one."
tags:
- devlog
- war-story
title: "The band that took too long to create"
---

## What changed

Creating a band is now basically instant.

- **Symptom:** a tester made a band, it spun long enough that he put the phone
  down — and forgot the band had been created at all. There's no worse first
  impression.
- **The hunt:** creating a band was a queue of waits, one after another: generate
  an invite code, ask the server "is this code already taken?", write the band to
  the global collection, write it *again* to the user's own list, then wait on an
  analytics ping. Five steps, each its own network round trip, all blocking the
  spinner.
- **The fix:** the invite code is 6 characters from a 36-letter alphabet — about
  two billion combinations. Checking for a collision first was guarding against a
  once-in-a-lifetime event at the cost of a round trip *every single time*, so I
  dropped it. The two writes became one batched write. Analytics stopped blocking
  the UI. Roughly four sequential waits collapsed into one.
- And no — the earlier "joining a band is faster now" work never touched
  *creating* one. Different code path entirely; the slow create just hid behind it.

## Why it matters

The slowest code is often the most cautious code. A guard against a collision that
statistically won't happen in this app's lifetime was making everyone wait, every
time. Most "it feels slow" bugs aren't the algorithm — they're round trips lined
up nose to tail when they could have gone together, or not happened at all.
