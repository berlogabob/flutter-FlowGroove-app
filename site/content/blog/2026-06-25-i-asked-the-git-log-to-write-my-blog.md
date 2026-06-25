---
categories:
- devlog
date: '2026-06-25T23:00:00+01:00'
draft: false
slug: i-asked-the-git-log-to-write-my-blog
summary: "This whole series is mined from the git history by a small pipeline. Here's the machine behind the curtain — the one that turned 876 commits into episodes."
tags:
- devlog
- meta
title: "I asked the git log to write my blog"
---

## What changed

The blog you're reading has a backend: a pipeline that turns the project's git history into
a source of truth, and that source into posts.

- A script reads the full git log into a structured history file — every real change, with
  what shipped and why — while collapsing the 235 auto-deploy commits into a tidy version
  timeline.
- From that, it renders a human changelog, and an editorial "series bible" lays out the
  episodes: seasons, hooks, and which commits each one draws from. Every post in this series,
  including this one, was pulled from that map.
- Going forward, new commits get stub entries automatically, so the history — and the
  backlog of things to write about — keeps itself current.

## Why it matters

The hardest part of devlogging isn't writing; it's remembering what you did and why, months
later, under 235 commits of noise. Treating the history as *data* — queryable, structured,
honest — means the stories are already there waiting to be told. The series explains the app;
this post explains the series; and the script explains them both. Turtles, but useful ones.
