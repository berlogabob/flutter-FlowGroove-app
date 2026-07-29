---
categories:
- devlog
date: '2026-06-25T06:15:00+01:00'
draft: true
slug: one-codebase-three-screens
summary: "A solo dev can't maintain three apps. Picking Flutter was less about love and more about math."
tags:
- devlog
- flutter
title: "One codebase, three screens — betting on Flutter"
---

## What changed

The very first real decision wasn't a feature — it was the bet that one codebase
would run on web, Android, and (eventually) iOS.

- The band's gear is mixed: my phone, the guitarist's tablet, the drummer's laptop.
  Whatever I built had to show up the same on all of them.
- A solo dev maintaining three separate native apps is a solo dev who ships nothing.
  The honest constraint was *one* thing to keep alive.
- Flutter gave one Dart codebase, fast iteration, and a UI that looks intentional
  without fighting the framework. Firebase handled the sync so I didn't have to run
  a backend.

## Why it matters

Tooling choices for a side project aren't about what's coolest — they're about what
you can still maintain at 11pm after a rehearsal. The whole app exists because I
picked the stack that let one person cover three platforms. Every later feature is
downstream of that one math problem.
