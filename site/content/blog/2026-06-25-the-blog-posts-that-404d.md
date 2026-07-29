---
categories:
- devlog
date: '2026-06-25T11:00:00+01:00'
draft: true
slug: the-blog-posts-that-404d
summary: "I shipped a blog, clicked a post, and got a 404 — from a one-line rule I'd written months earlier and forgotten."
tags:
- devlog
- war-story
title: "The blog posts that 404'd"
---

## What changed

The site now actually serves its blog pages. The bug wasn't in Hugo or in the
hosting — it was in `.gitignore`.

- **Symptom:** every blog post and the Flutter app folder returned 404 on GitHub
  Pages, but worked perfectly when I built locally.
- **The hunt:** if it works locally and 404s in production, the files never made
  it into the repo. `git status` showed nothing wrong — which is the tell. The
  files weren't *changed*, they were *ignored*.
- **The truth:** a bare `index.html` line in `.gitignore`, added long ago for some
  build artifact, was silently swallowing every `index.html` Hugo generates — which
  is *every page*. The fix was to negate it for the published sections.

## Why it matters

The most expensive bugs are the ones where the tool tells you nothing is wrong. A
green `git status` felt like proof, and it was the opposite. Now the rule is
scoped, the pages ship, and I have a new reflex: when production is missing files
that exist locally, suspect `.gitignore` before anything else.
