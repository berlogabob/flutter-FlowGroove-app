---
categories:
- devlog
date: '2026-06-25T19:00:00+01:00'
draft: false
slug: failed-to-load-band-data
summary: "\"Failed to load band data\" — but only after restarting the app. The band was being passed around in memory and didn't survive a relaunch."
tags:
- devlog
- war-story
title: "\"Failed to load band data\" on restart"
---

## What changed

Band screens now reload their data from the band's id, instead of relying on an object
handed to them in memory.

- **Symptom:** open a band, everything's fine. Restart the app on that same screen and
  you get "Failed to load band data."
- **The hunt:** the router was passing the band as an `extra` — a live object carried
  between screens. That's fine while the app's running, but a restart rebuilds the route
  from the URL alone, and the `extra` is gone. The screen got handed null and gave up.
- **The truth:** routes now carry the band's `id` and *reload* the band from it on
  arrival. The id survives a restart because it's in the route; the live object never did.

## Why it matters

Passing rich objects between screens feels convenient and works perfectly right up until
the app cold-starts into a deep route. The URL is the only thing guaranteed to survive a
restart, so anything a screen truly needs has to be reconstructable from it. "Pass the id,
reload the data" is less elegant than "pass the object" — and far more durable.
