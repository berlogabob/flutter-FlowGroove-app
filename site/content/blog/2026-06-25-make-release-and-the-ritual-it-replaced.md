---
categories:
- devlog
date: '2026-06-25T20:30:00+01:00'
draft: false
slug: make-release-and-the-ritual-it-replaced
summary: "Releasing used to be a sequence of steps I'd half-remember at midnight. Now it's one command — and a hook that stops me leaking secrets."
tags:
- devlog
- deploy
title: "`make release` and the ritual it replaced"
---

## What changed

Cutting a release became a single command instead of a fragile manual checklist.

- `make release` builds the Android artifacts (APK and app bundle) and cuts the GitHub
  Release in one go — no more remembering the order of six steps at midnight.
- A pre-commit hook guards the dangerous parts: it blocks `google-services.json` and any
  stray `AIzaSy…` API keys from being committed, so a tired solo dev can't accidentally
  publish a secret.
- Version bumping is automated too, so the build number and the tag never drift out of
  sync the way they did when I did it by hand.

## Why it matters

Every manual release step is a place to make a mistake when you're tired — and releases
happen exactly when you're tired. Codifying the ritual into one command doesn't just save
time; it removes the *judgment* from a moment where my judgment is worst. The hook that
blocks secrets is the same idea: don't trust future-me to remember, make the system
remember for him.
