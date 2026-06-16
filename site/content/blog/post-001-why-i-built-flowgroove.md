---
title: "Why I Built FlowGroove Between Rehearsals"
date: 2026-04-15T10:00:00+01:00
draft: false
tags: ["indie-dev", "solo-developer", "band-life", "flutter"]
categories: ["developer-journey"]
summary: "The story of how 10 years in cover bands led me to build FlowGroove as a solo developer, one late night at a time."
featuredImage: "images/blog-001-cover.svg"
---

# Why I Built FlowGroove Between Rehearsals

Hi, I'm a solo developer who's played in cover bands for 10 years.

And every single rehearsal was the same chaotic mess.

## The Problem That Wouldn't Go Away

You know the drill:

- Paper setlists that got coffee-stained or lost
- Someone forgetting to write down the BPM for "Wonderwall"
- Arguing over key changes ("Was it F#m or Gm?")
- Switching songs taking 5 minutes while the band stood around
- No sync between my phone, the guitarist's tablet, and the drummer's laptop

The chaos was killing our vibe. We spent more time organizing than playing music.

I tried existing solutions. They were either:
- Too complex (needed a degree to set up)
- Too expensive (monthly subscriptions for a hobby?)
- Too buggy (crashed mid-rehearsal, great)

## The Breaking Point

One Tuesday night, after our third rehearsal in a row was derailed by someone losing the setlist, I had enough.

I'm a developer. I build things for a living. Why couldn't I build something for my band?

So I did.

## Building FlowGroove

I built FlowGroove between rehearsals and my day job. Late nights. Weekends. Lots of coffee.

My requirements were simple:

✅ **3 seconds to add a song** — If it takes longer, it's too slow  
✅ **Auto-detect BPM & key** — No more manual entry  
✅ **Real-time sync** — Change on my phone, update on everyone's devices  
✅ **Works offline** — Basement rehearsals have no WiFi  
✅ **Dark mode** — Don't blind the band during gigs  
✅ **Free for indie musicians** — Because we're all broke  

## The Tech Stack

I chose **Flutter** because:
- One codebase for web, iOS, and Android
- Fast development cycle
- Beautiful UI out of the box
- Firebase integration for real-time sync

**Firebase Firestore** handles the sync. Changes propagate in <500ms. Tested on 3G, WiFi, and everything in between.

## What I Learned

Building a product solo is hard. But it's also rewarding.

**Technical lessons:**
- Real-time sync is trickier than it sounds
- Offline-first architecture is a must for musicians
- Dark mode isn't just black background — it's contrast

**Business lessons:**
- "Free" doesn't mean "no value" — it means "different value"
- Musicians will donate on Ko-fi if you're authentic
- Launch on platforms like TinyLaunch matters for indie makers

## Where We Are Now

FlowGroove is live. It's free. And it works.

- **Real-time sync:** <500ms delay across devices
- **Auto BPM detection:** Type the song, get the data
- **Offline mode:** Full functionality without internet
- **Stage-ready dark mode:** High-contrast for dim venues

## What's Next

- iOS app (working on the Apple Developer License)
- More integrations (Spotify, YouTube for auto-metadata)
- Advanced setlist features (transposition, capo support)
- Band collaboration tools (shared libraries, comments)

## Support the Journey

If this story resonates with you, or if FlowGroove helps your band, consider supporting development on Ko-fi.

[**Support the Dev on Ko-fi**](https://ko-fi.com/flowgroove)

Every donation keeps the servers running and the coffee flowing.

---

**Thanks for reading. Now go make some music.** 🎸

*Have questions? [Email me](mailto:hello@flowgroove.app) or [report issues on GitHub](https://github.com/berloga/flutter_repsync_app/issues).*
