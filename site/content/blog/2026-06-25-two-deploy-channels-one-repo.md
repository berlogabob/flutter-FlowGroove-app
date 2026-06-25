---
categories:
- devlog
date: '2026-06-25T20:00:00+01:00'
draft: false
slug: two-deploy-channels-one-repo
summary: "One repo, two destinations: a scrappy dev build on GitHub Pages and the real thing on flowgroove.app. Keeping them straight is its own small discipline."
tags:
- devlog
- deploy
title: "Two deploy channels, one repo"
---

## What changed

The project ships to two places on purpose: a development channel and a production one.

- **Dev:** the GitHub Pages build (the `docs/` output) — where I push freely and check
  things in the open without touching what users see.
- **Prod:** `flowgroove.app`, deployed over FTP via dedicated `make` targets
  (`deploy-stable` for the app, `deploy-hugo` for site-only changes).
- Keeping them separate means I can break the dev channel all day and production stays
  exactly as stable as the last intentional release.

## Why it matters

A solo dev with one channel is a solo dev who experiments in production. The split is
cheap insurance: a place to be reckless and a place that's sacred. The only cost is
remembering which command points where — and getting *that* wrong is its own category of
mistake, which is exactly why the deploy targets are named, scripted, and boring. Boring
deploys are good deploys.
