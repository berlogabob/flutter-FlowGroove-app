---
categories:
- devlog
date: '2026-06-25T18:45:00+01:00'
draft: true
slug: the-join-link-that-did-nothing
summary: "Tap the invite link, the app opens, and… nothing happens. The fix was all about timing — the app was ready before the user was logged in."
tags:
- devlog
- war-story
title: "The join-by-link that did nothing"
---

## What changed

Invite links now actually join you to the band, even from a cold start.

- **Symptom:** someone taps a join link, the app opens, and nothing happens. No band,
  no error, just the normal home screen. Try it again with the app already open and it
  works fine.
- **The hunt:** "works warm, fails cold" points at startup ordering. The join logic ran
  the moment the app launched — but on a cold start, Firebase hadn't finished restoring
  the signed-in user yet. So the redirect fired against a not-yet-authenticated app and
  quietly gave up.
- **The truth:** wait for auth to restore before acting on the deep link. Once the join
  redirect runs *after* the user is known, the link does what it says.

## Why it matters

Race conditions are the cruelest bugs because they're real and invisible — the code is
"correct," it just runs a beat too early. Deep links are a magnet for them: they smash
two slow things (cold launch, auth restore) into one moment and dare you to order them
right. The lesson is to never act on a link until the app actually knows who you are.
