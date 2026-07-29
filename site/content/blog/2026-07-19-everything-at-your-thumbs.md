---
categories:
- devlog
date: '2026-07-19T09:00:00+01:00'
draft: true
slug: everything-at-your-thumbs
summary: "Fitts's Law called the top corners the most expensive pixels on a phone — and that's exactly where my Back and Menu buttons lived. So the whole app moved south: Menu tab, bottom Back, undo snackbars, and eventually no top bar at all."
tags:
- devlog
- ux
- design
- navigation
title: "S9E5 — Everything at your thumbs"
---

## The finding

Run Fitts's Law over a 20:9 phone and it says something blunt: the top
corners are the most expensive places you can put a control. Maximum distance
from the thumb, grip change or second hand required. My audit found exactly
two controls living there — on *every screen*: back (top-left) and the ⋮ menu
(top-right). The ⋮ was the **only** route to core features like the
performance sheet and CSV import.

Meanwhile the bottom of the screen — the cheapest real estate on the device —
held five nav tabs, one of which was Profile, a screen you visit roughly once
a month.

There was one more wrinkle: FlowGroove also runs as an installable web app,
and a standalone PWA has **no browser chrome**. No system back at all. The
in-app back button wasn't redundant chrome; for web users it was the only
exit. It just lived in the worst possible spot.

## The redesign

The bottom bar now has two states:

- **On a main screen:** `Home · Songs · Bands · Setlists · Menu (⋯)`. The Menu
  slot took Profile's place and opens a bottom sheet — the current screen's
  actions, a header naming the screen, and a Profile row. A little dot on the
  Menu icon tells you the screen has actions.
- **On any opened screen:** `← Back · screen title · ⋯ Menu`. Same bar,
  everywhere — song editor, band pages, metronome, tuner. Back finally sits
  where the thumb already is, and it works on the web where no system back
  exists.

And the audit's other severity-3 hole — *no undo anywhere* — got the Material
answer instead of more chrome: deleting a section, a setlist, or unloading the
practice song now shows a snackbar with **Undo** for five seconds, right in
the thumb zone. (Removing a band member still asks first — that's a
server-side action no client can take back.)

## The part that fought back

The shell decides which bar state to show by asking "is something pushed on
top of this tab?" — and go_router's reported location, it turns out, **never
updates for pushes inside a tab**. Nineteen hundred green tests didn't catch
that; installing the build on my phone did, in about four seconds. The fix
watches the actual navigators (counting pages, ignoring popups — otherwise
the menu sheet itself would flip the bar behind its own back), OR'd with the
URL for deep links. Then the first version notified mid-build and blew up
forty tests at once. Post-frame callbacks: not optional.

## What it bought

A follow-up phase deleted the top bar entirely — the title had become a
duplicate of the tab label sitting in a dead 56-pixel row. Today the top 15%
of every screen contains exactly zero controls and zero chrome. Content
starts where your eyes start.

Whether the bets paid off isn't a matter of opinion anymore either — the app
now quietly counts `back_used` and `undo_used` (with a consent switch, and
only if you leave it on). The beta will answer with data.

*Next: S9E6 — Deleting the top of my app.*
