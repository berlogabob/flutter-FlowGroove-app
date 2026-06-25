---
categories:
- devlog
date: '2026-06-25T20:15:00+01:00'
draft: false
slug: landing-page-and-app-shipping-apart
summary: "The marketing site and the app are different beasts with different release rhythms. Splitting them apart let each move at its own speed."
tags:
- devlog
- deploy
title: "Landing page and app, shipping apart"
---

## What changed

The public landing page and the Flutter app became two things that deploy independently.

- A Hugo-built landing page (with a custom MonoPulse-style theme) handles the marketing
  site, blog, and docs — fast, static, no app build required to tweak a headline.
- The Flutter app is its own deploy. A copy-fix on the homepage no longer means rebuilding
  and reshipping the entire application.
- This dual-deploy split is also why the blog you're reading and the in-app help can share
  the same Markdown without dragging the app's build pipeline into every word change.

## Why it matters

When your landing page and your app are welded together, every typo fix is an app release
and every app release risks the landing page. Pulling them apart sounds like extra
infrastructure, but it actually *removes* coupling: marketing moves at marketing speed,
engineering moves at engineering speed, and neither holds the other hostage. The best
architectures are often just two things that used to be one.
