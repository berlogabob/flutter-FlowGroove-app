---
categories:
- devlog
date: '2026-06-25T18:15:00+01:00'
draft: true
slug: real-time-sync-on-bad-wifi
summary: "I change the setlist, everyone sees it — even in a venue with WiFi held together by hope. Real-time sync sounds simple and absolutely is not."
tags:
- devlog
- sync
title: "Real-time sync on a venue's terrible WiFi"
---

## What changed

Change something on one device and it shows up on everyone else's, fast, even on a
flaky venue connection.

- Firestore does the heavy lifting: edits propagate to every band member's screen
  almost immediately, and the list stays in sync as members join, leave, or reorder.
- Offline-first isn't a bonus, it's the baseline. Rehearsal rooms and stages eat WiFi
  for breakfast, so the app works offline and reconciles when the connection comes back.
- Plenty of small fixes went into making the list updates *feel* live and the offline
  indicator honest about where you stand.

## Why it matters

"It syncs" is easy to say and sneaky to build. The naive version works great on your
home WiFi and falls apart the moment you're in a concrete-walled venue with one bar of
signal — which is precisely when a band needs it most. Designing for the bad connection
first, instead of bolting offline on later, is the difference between a tool you trust on
stage and a demo you trust at your desk.
