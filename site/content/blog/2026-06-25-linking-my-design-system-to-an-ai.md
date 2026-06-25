---
categories:
- devlog
date: '2026-06-25T22:45:00+01:00'
draft: true
slug: linking-my-design-system-to-an-ai
summary: "An AI that doesn't know your design system invents its own. I connected mine so the help it gives stays on-brand instead of generically off."
tags:
- devlog
- ai
title: "Linking my design system to an AI"
---

## What changed

I wired my existing theme and design system into the AI design tooling, so generated UI
follows *my* rules instead of inventing new ones.

- Left to its own devices, an assistant produces reasonable-but-generic UI — the wrong
  spacing, off-palette colors, components that don't match anything else in the app.
- Connecting the design system (via a design MCP connector) gives it the real tokens: the
  colors, type, and components the app actually uses, so suggestions land on-brand.
- It came with a comprehensive design-system audit and a round of fixes, because you can't
  hand over a system that's inconsistent with itself and expect consistent output.

## Why it matters

Consistency is the whole point of a design system, and an AI that doesn't share it is a
fast way to erode that consistency one well-meaning suggestion at a time. The fix isn't to
keep the AI away from the UI — it's to give it the same constraints a new teammate would
get on day one. Tools produce on-brand work when they know what the brand *is*; otherwise
they average toward the templated default everyone recognizes.
