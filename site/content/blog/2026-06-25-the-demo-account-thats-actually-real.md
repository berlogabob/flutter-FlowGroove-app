---
categories:
- devlog
date: '2026-06-25T19:30:00+01:00'
draft: false
slug: the-demo-account-thats-actually-real
summary: "\"Try Demo\" doesn't drop you into an empty shell. It drops you into a real band with real songs and setlists — because an empty demo sells nothing."
tags:
- devlog
- product
title: "The demo account that's actually real"
---

## What changed

The "Try Demo" button signs you into a fully populated account — a real band, real
cover songs, real setlists — not a blank slate.

- An empty app can't sell itself. A new visitor who lands on "you have no songs" has no
  idea what the thing is *for*.
- So the demo account is seeded with actual content: a band, a catalog of cover songs
  with their metadata, setlists ready to play. You see the app doing its job in the first
  five seconds.
- It's paired with a safe demo config for builds, so the demo path needs no secrets and
  ships cleanly through CI.

## Why it matters

The fastest way to lose a curious user is to show them an empty room and ask them to
furnish it. Demos have to demonstrate, and that means populated, opinionated, real-looking
data — the app at its best, not its emptiest. Seeding that takes work nobody sees, but
it's the difference between "I get it" and "I'll set it up later" (which means never).
