---
categories:
- devlog
date: '2026-06-25T09:15:00+01:00'
draft: true
slug: canonical-songs-and-the-duplicate-problem
summary: "Once songs fill themselves in from a database, you get a new problem: ten slightly different copies of the same song. Here's the dedupe story."
tags:
- devlog
- songs
title: "Canonical songs and the duplicate problem"
---

## What changed

Songs now resolve to a *canonical* version instead of every band re-adding their own
near-identical copy.

- The moment lookups got easy, the library started filling with duplicates: the same
  song with slightly different titles, casing, or release metadata.
- The save logic gained duplicate detection — before writing a new song, it checks
  whether a canonical one already exists and links to it rather than spawning a twin.
- That meant a canonical library with its own write/migration tooling and callable
  functions to ensure entries exist, so the dedupe runs server-side and consistently.

## Why it matters

Convenience creates mess. Auto-filled metadata made adding songs frictionless, and
frictionless input is exactly how a shared library turns into a junk drawer of
duplicates. Deduplication isn't glamorous, but it's the difference between a song
catalog that gets more useful as it grows and one that gets more confusing. The feature
that fills data in needs a partner that keeps it clean.
