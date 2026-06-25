---
categories:
- devlog
date: '2026-06-25T21:15:00+01:00'
draft: false
slug: the-release-that-crashed-on-launch
summary: "The debug build ran fine. The release build crashed instantly on launch. The difference came down to initializing Firebase twice."
tags:
- devlog
- war-story
title: "The release that crashed on launch"
---

## What changed

Release builds start up instead of crashing the moment they open.

- **Symptom:** debug builds worked perfectly; the release build died on launch. The worst
  split there is — the version your users get is the only one that's broken.
- **The hunt:** the crash was a Firebase initialization conflict. Something was calling
  `initializeApp` when an app instance already existed, and in the release configuration a
  key mismatch turned that double-init into a hard crash instead of a shrug.
- **The truth:** guard the initialization — only initialize Firebase if no app exists yet
  (`Firebase.apps.isEmpty`). Initialize once, never twice, and the release build launches
  like it should.

## Why it matters

"Works in debug, crashes in release" is a special kind of dread, because debug is where you
live and release is where your users live. The gap is usually configuration — different
keys, different optimizations, different assumptions about what's already set up. The fix
was one guard clause; the lesson was to actually run the release build before trusting it,
every time, because it is a genuinely different program.
