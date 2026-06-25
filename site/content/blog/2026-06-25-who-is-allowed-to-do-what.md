---
categories:
- devlog
date: '2026-06-25T18:30:00+01:00'
draft: false
slug: who-is-allowed-to-do-what
summary: "Letting clients write band membership directly is how you end up with someone adding themselves as admin. Membership moved to the server, where it belongs."
tags:
- devlog
- bands
title: "Who's allowed to do what"
---

## What changed

Band membership and roles became server-authoritative. The client asks; the server
decides.

- Joining a band, leaving it, removing a member, changing a role — none of it is a
  direct client write anymore. It goes through Cloud Functions that enforce the rules.
- The list still updates in real time, but the *authority* for "who is in this band and
  what can they do" lives in one trusted place, not scattered across whatever each
  client felt like writing.
- Even band-level things like the avatar moved server-side, dropping a fragile rule that
  tried to coordinate permissions across services and kept getting it subtly wrong.

## Why it matters

Anything a client can write directly, a client can write *wrongly* — by bug or by hand.
Membership is exactly the kind of data where "trust the client" turns into "someone made
themselves admin." Pushing those decisions to the server costs a round trip and buys you
a system where the rules are actually rules, not suggestions. For multiplayer, that
trade is non-negotiable.
