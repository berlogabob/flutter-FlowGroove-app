---
categories:
- devlog
date: '2026-07-16T09:00:00+01:00'
draft: true
slug: the-robot-that-audited-my-app
summary: "Before widening the beta I pointed the review guns at my own app: an agent drove my actual phone, took 105 screenshots, and three old-school UX frameworks turned them into 32 findings — five of them bad enough to lose a new user in their first session."
tags:
- devlog
- ux
- audit
- ai
title: "S9E1 — The robot that audited my app"
---

## The setup

FlowGroove was about to go to a wider beta, and I know exactly how much I can
be trusted to judge my own UI: not at all. I've watched every screen a thousand
times. I don't *see* them anymore.

So I didn't review the app. I had it reviewed.

An agent drove my real Android phone over adb — tap, screenshot, look at the
screenshot, decide the next tap. Hard safety rules: never touch Delete, never
send an invite, never sign out. Two sessions later (one interrupted by my
laptop rebooting mid-run) there were **105 screenshots** covering every screen,
menu, bottom sheet and dialog in the app, each one indexed with a description.

## The frameworks

Screenshots aren't findings. To grade them I used three lenses that have been
around longer than most JS frameworks:

- **Nielsen's 10 heuristics** — the classic usability checklist, each violation
  scored 0–4.
- **Google HEART** — not a checklist but a metrics framework: what would we
  *measure* to know if this app is working?
- **Fitts's Law** — the geometry of touch: how far, how big, how expensive is
  every tap target on a 20:9 phone.

The result: 5 findings that could lose a new user in their first session,
12 high-value fixes, 15 polish items.

## The findings that hurt

The worst one scored a 4 out of 4 on Nielsen's severity scale: **pressing the
system back button exited the app** from the Tuner — and from the Join Band
screen, which is literally the first screen an invited bandmate ever sees.
Your drummer taps your invite link, presses back once, and the app vanishes.
Great first impression.

The count on a setlist card disagreed with the setlist itself. Members without
a display name rendered as blank rows. The key filter offered twelve sharp
major chips while my own library contained songs stored as "Ab" and "em" —
filtering by key silently *lost songs I knew I had*.

And Fitts's Law had one loud thing to say: the two most-used controls on every
screen — back and the ⋮ menu — sat in the two most expensive corners of the
screen, while the bottom third, where a thumb actually lives, held nothing but
a nav bar.

## What happened next

Every finding got a severity, a screenshot reference, and a suggested fix in
one honest document — including the corrections where the audit itself turned
out to be wrong (that's a later episode; a "dead button" was nothing of the
sort). Then the fixing started: six phases, six pull requests, every one
verified on the same physical phone the audit ran on.

The next episodes are the war stories from those phases. The first one starts
with that back button.

*Next: S9E2 — The back button that quit my app.*
