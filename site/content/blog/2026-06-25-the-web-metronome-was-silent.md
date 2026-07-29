---
categories:
- devlog
date: '2026-06-25T07:00:00+01:00'
draft: true
slug: the-web-metronome-was-silent
summary: "The metronome worked perfectly on Android and made zero sound on the web. The audio library simply had no web in it."
tags:
- devlog
- war-story
title: "The web metronome was silent"
---

## What changed

The web build of the metronome makes sound now. For a while it was completely
silent, with no error to explain it.

- **Symptom:** beautiful ticking beat on Android, dead silence in the browser. Same
  controls, same code, no exception.
- **The hunt:** I'd reached for `flutter_soloud` for low-latency native audio —
  exactly right on phones. But it has no web implementation. On web it doesn't crash;
  it just produces nothing, which is the most confusing possible failure.
- **The truth:** the web needs its own engine — the Web Audio API, synthesizing the
  click directly in the browser. So the metronome now picks its sound engine by
  platform: native low-latency on mobile, Web Audio on the web.

## Why it matters

"Cross-platform" hides seams, and audio is one of the deepest. A library can support
"Flutter" and still not support *your* Flutter target. The fix wasn't a workaround —
it was accepting that one piece of the app genuinely needs two implementations, and
choosing between them at runtime.
