---
categories:
- devlog
date: '2026-06-25T21:45:00+01:00'
draft: true
slug: the-buttons-i-accidentally-deleted
summary: "A user reported that the next and previous buttons were gone after an update. I hadn't meant to remove them — a refactor took them out from under me."
tags:
- devlog
- war-story
title: "The next/prev buttons I accidentally deleted"
---

## What changed

The next and previous buttons came back after a refactor quietly removed them.

- **Symptom:** a user wrote in — "after the last few updates you deleted the next and prev
  buttons." They were right, and I had no memory of doing it.
- **The hunt:** the buttons weren't deleted on purpose; they fell out during a refactor of
  the surrounding screen. Nothing flagged it, because the build still compiled — until I
  checked the build errors that *had* crept in and traced back through what that area's
  rewrite had touched.
- **The truth:** restore the controls, and treat "the user noticed before I did" as the
  real bug. Compiling is not the same as complete.

## Why it matters

This is the sibling of the vanished structure editor: a feature lost in a diff, invisible
to the compiler, surfaced by a user instead of a test. Two of these in one project is a
pattern, and the pattern says refactors silently drop UI. The takeaway isn't "be more
careful" — it's that "still builds" tells you nothing about "still does what it did." Your
users are not supposed to be your regression suite.
