---
categories:
- devlog
date: '2026-06-25T12:00:00+01:00'
draft: false
slug: the-iframe-that-froze-the-app
summary: Embedding the help docs inside the web app seemed obvious. It quietly froze the entire interface — here's why, and what I did instead.
tags:
- devlog
- war-story
title: The iframe that froze the whole app
---

## What changed

In-app help no longer tries to embed the docs site inside the running web app. It
opens them in a new tab instead.

- **Symptom:** open the docs panel on web and the whole app stops responding — taps
  do nothing, nothing crashes, no error. Just frozen.
- **The hunt:** I bypassed the embedded view as a diagnostic, and the app came
  straight back to life. So the panel content wasn't the problem; the *way* it was
  embedded was.
- **The truth:** Flutter web renders to a canvas, and dropping an
  `HtmlElementView`/iframe into that canvas fights the renderer for input and
  freezes interaction. There's no clever fix — you don't embed foreign HTML in a
  Flutter web canvas. External content gets a new tab.

## Why it matters

"Just embed it in an iframe" is the instinct from a decade of web work, and on
Flutter web it's a trap. The lesson cost an afternoon: the platform you *think*
you're on (the browser) isn't the platform you're actually on (a canvas pretending
to be one). When in doubt, link out.
