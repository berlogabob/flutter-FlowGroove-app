---
categories:
- devlog
date: '2026-06-25T09:45:00+01:00'
draft: false
slug: the-song-structure-editor-that-vanished
summary: "A whole feature — the song structure editor — quietly disappeared in a release. Nobody removed it on purpose, which is what made it scary."
tags:
- devlog
- war-story
title: "The song structure editor that vanished"
---

## What changed

The song structure editor — the "scheme" where you lay out intro / verse / chorus /
bridge — came back after silently going missing in a release.

- **Symptom:** users noticed the section-by-section structure they'd built was just…
  gone from the song form. No error, no migration, no announcement.
- **The hunt:** nobody deleted it deliberately. It got dropped in a release during a
  refactor of the song form — the kind of loss that doesn't show up in any test because
  no test asserted "this UI still exists."
- **The truth:** the fix was to restore the structure sections back into the song form
  where they belonged. The deeper fix was the lesson: features can evaporate in a diff
  and leave no trace.

## Why it matters

The worst regressions aren't crashes — they're *absences*. A crash screams; a missing
feature just isn't there, and you only find out when a user does. This one taught me to
treat "what should still be on this screen" as something worth pinning down, not
something I'll obviously notice if it breaks. I didn't.
