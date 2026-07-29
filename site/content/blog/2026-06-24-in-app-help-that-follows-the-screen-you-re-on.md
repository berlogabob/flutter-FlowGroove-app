---
categories:
- devlog
date: '2026-06-24T10:00:00+01:00'
draft: false
slug: in-app-help-that-follows-the-screen-you-re-on
summary: Per-screen help pages now live inside FlowGroove — open the wiki panel and you get docs for exactly the screen you're looking at, not a generic manual.
tags:
- devlog
title: In-app help that follows the screen you're on
---

## What changed

FlowGroove now has built-in help that's aware of where you are. The same Markdown
pages that power the docs site are bundled into the app, and on desktop a wiki
panel opens beside what you're doing and shows the page for that exact screen.

- Help docs are written once as Hugo Markdown and reused — site and app read the
  same source, so they can't drift apart.
- On desktop the builder splits into two columns: your work on the right, the
  relevant help page rendered on the left, with overlays kept out of your way.
- Front-matter is stripped and each screen maps to its own page, so opening help
  from the metronome gives you metronome docs, not a table of contents to dig through.

## Why it matters

The thing I always hated in band apps: you're mid-rehearsal, you tap "help," and
you land on a generic FAQ that has nothing to do with the button you were poking
at. Now the help knows the screen. Less hunting, more playing.
