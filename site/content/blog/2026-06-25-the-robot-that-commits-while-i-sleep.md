---
categories:
- devlog
date: '2026-06-25T20:45:00+01:00'
draft: true
slug: the-robot-that-commits-while-i-sleep
summary: "My git history is full of commits I didn't write. There's a loop that auto-commits and deploys my working-tree edits — convenient, and occasionally confusing."
tags:
- devlog
- deploy
title: "The robot that commits while I sleep"
---

## What changed

A background loop watches the working tree, auto-commits edits as
`Release x.y.z+N`, and deploys them.

- The upside is real: changes go live without me babysitting a release every time, which
  for a solo project means momentum instead of a chore.
- The downside is a git history where most commits are the robot bumping build numbers,
  and a `git status` that can look inconsistent because something committed underneath me
  between one command and the next.
- It's the direct reason this whole blog series needed a history *pipeline* — separating
  the 235 robot commits from the ~635 real changes (a story I told in its own post).

## Why it matters

Automation that commits and deploys for you is a Faustian little bargain: you trade a tidy,
intentional history for never having to think about shipping. For a hobby project shipped
by one person, that's often the right trade — but it means your version control stops being
a clean narrative and becomes a firehose. Worth knowing before you wire one up, because you
can't easily un-know it when reading your own log.
