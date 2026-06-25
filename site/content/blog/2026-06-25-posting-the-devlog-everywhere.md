---
categories:
- devlog
date: '2026-06-25T21:30:00+01:00'
draft: false
slug: posting-the-devlog-everywhere
summary: "Writing a devlog is half the work; getting it seen is the other half. A tiny CLI pushes posts to Telegram, and a Devvit bot crossposts to Reddit."
tags:
- devlog
- tooling
title: "Posting the devlog everywhere at once"
---

## What changed

Publishing a post can fan it out to where readers actually are, without manual reposting.

- A small poster CLI takes a finished devlog and pushes it to Telegram. It's deliberately
  tiny — a handful of files — and I've fought the urge to grow it into a "platform."
- Reddit crossposting moved into a Devvit app (`r/FlowGroove`), after the older
  library-based path got blocked. Different platform, different rules, so it gets its own
  purpose-built tool instead of being crammed into the CLI.
- Each channel does one job. Nothing tries to be the universal "post anywhere" abstraction
  that would rot the moment one platform changed its API.

## Why it matters

A blog nobody finds is a diary. Distribution matters as much as writing, but the trap is
building a grand cross-posting framework that's more maintenance than the writing itself.
The lazy-on-purpose move is small, single-purpose tools per channel — easy to fix when one
platform inevitably breaks, and impossible to over-engineer because there's nothing in them
to over-engineer.
