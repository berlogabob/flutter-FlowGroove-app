---
categories:
- devlog
date: '2026-06-25T13:00:00+01:00'
draft: false
slug: two-faces-one-user
summary: The same user showed up with a Google face on one screen and a Telegram face on another. Picking one "source of truth" for an avatar was sneakier than it sounds.
tags:
- devlog
- war-story
title: Two faces, one user
---

## What changed

Your avatar is now the same everywhere — whatever you chose on your profile wins,
on every screen.

- **Symptom:** the home screen showed a user's Google account photo while the
  profile screen showed their Telegram avatar. Same person, two faces, depending on
  where you looked.
- **The hunt:** each screen was reading the photo from whatever auth provider it
  happened to have handy, instead of from one agreed place. There was no single
  answer to "what is this user's picture?"
- **The truth:** sign-in providers each carry their own photo, and an avatar needs
  one authoritative source — the user's profile choice. That also meant fixing the
  plumbing: uploading via `putData` so it works on web, importing external photos
  server-side, and handling the "removed photo" case so it didn't fall back to a
  stale provider image.

## Why it matters

Identity bugs feel small and read as broken. If the app can't agree on what you
look like, why would you trust it with your setlist? One source of truth for the
avatar, decided by the user, fetched the same way everywhere — boring, and exactly
right.
