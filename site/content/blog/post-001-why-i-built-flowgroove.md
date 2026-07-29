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

I've played in cover bands for about ten years, and I write software for a living. For the longest time those two lives never touched — until one of them got annoying enough to fix with the other.

## The problem that wouldn't go away

You know the drill:

- Paper setlists that got coffee-stained or lost
- Nobody remembering the BPM for "Wonderwall"
- The eternal "was it F#m or Gm?" debate
- Five minutes lost between songs while we found the right version
- My phone, the guitarist's tablet, and the drummer's laptop all showing something different

We spent more time organizing than playing. And the tools that were supposed to help? Either too complicated to set up, too expensive for a hobby, or buggy enough to crash mid-rehearsal. Cool.

## The breaking point

One Tuesday night, our third rehearsal in a row got derailed because someone lost the setlist. Again. And it hit me: I do this for a living. I build things. Why was I putting up with this?

So I stopped putting up with it.

## Building it

FlowGroove got built the way side projects always do — late nights, weekends, and a lot of coffee. My rules for it were simple:

- **A song should take seconds to add.** Slower than that and the band won't bother.
- **BPM and key should fill themselves in.** Manual entry is where good intentions go to die.
- **It has to sync in real time.** I change it, everyone sees it.
- **It has to work offline.** Rehearsal rooms eat WiFi for breakfast.
- **Dark mode.** Nobody wants a flashlight on stage.
- **Free for indie musicians.** Because we are not a wealthy people.

## The tech, briefly

I went with **Flutter** — one codebase for web, iOS, and Android, fast to iterate on, and decent-looking without much fighting. **Firebase Firestore** does the heavy lifting on sync: change something and it shows up on everyone else's screen almost immediately, even on a wobbly venue connection.

## What I learned

Building a product alone is hard, and also kind of great.

On the technical side: real-time sync is sneakier than it looks, offline-first isn't optional for musicians, and "dark mode" is really about contrast, not just a black background.

On the not-technical side: "free" doesn't mean "worthless," it means the value shows up somewhere else. And people will support an honest solo project on Ko-fi if you're actually honest with them.

## Where it's at now

FlowGroove is live, it's free, and it does the job:

- Real-time sync across devices, fast enough to feel instant
- Auto BPM and key — type the song, get the data
- Full offline mode
- A dark theme built for dim venues

## What's next

No dates, just the list: an iOS build, more metadata sources (Spotify, YouTube), transposition and capo helpers, and proper band collaboration with shared libraries and comments.

## Support the journey

If any of this rings true, or if FlowGroove ends up saving your band a few headaches, you can support it on Ko-fi.

[**Support the dev on Ko-fi**](https://ko-fi.com/flowgroove)

Every bit keeps the servers running and the coffee flowing.

---

**Thanks for reading. Now go make some music.** 🎸

*Questions? [Email me](mailto:hello@flowgroove.app) or [open an issue on GitHub](https://github.com/berlogabob/flutter-FlowGroove-app/issues).*
