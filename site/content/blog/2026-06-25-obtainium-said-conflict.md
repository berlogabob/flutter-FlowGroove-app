---
categories:
- devlog
date: '2026-06-25T21:00:00+01:00'
draft: false
slug: obtainium-said-conflict
summary: "Users updating the app through Obtainium kept hitting \"Conflict.\" The cause was that every CI build signed itself with a different random key."
tags:
- devlog
- war-story
title: "Obtainium said \"Conflict\""
---

## What changed

App updates install cleanly now. For a while, users updating via Obtainium got a
"Conflict" error and had to uninstall first.

- **Symptom:** "Conflict" on update — Android's polite way of saying "this APK is signed
  by someone other than whoever installed the one you have."
- **The hunt:** I wasn't signing with a stable key. CI was building with a *randomly
  generated debug signature* each run, so every build looked, to Android, like a different
  developer's app. Of course it refused to update over the previous one.
- **The truth:** a dedicated upload keystore, used consistently, with CI gated so it only
  signs for real when the key is present. Same key every build, no more conflict (one final
  reinstall to switch onto the stable key, then smooth forever).

## Why it matters

Android's signing model is unforgiving on purpose: a stable signature is how the OS knows
an update is *really* from you. Random debug signing is invisible until the first update,
then it breaks every existing install at once. Signing is infrastructure you have to get
right before you have users, because the bug only appears once you do.
