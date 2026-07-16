---
categories:
- devlog
date: '2026-07-17T09:00:00+01:00'
draft: true
slug: six-songs-five-showing
summary: "A setlist said 6 songs, the editor showed 5. I fixed the number — in the wrong direction. The real bug underneath: an editor that silently deleted your data every time you saved."
tags:
- devlog
- war-story
- bug
- data
title: "S9E3 — Six songs, five showing"
---

## The symptom

My oldest test setlist, "testo tiras". The card on the Setlists tab said
**6 songs**. Opening it showed **5**. A band-coordination app whose numbers
disagree with itself is an app you stop trusting immediately — this was a P0
in the audit.

## The first fix (wrong)

Easy, right? The card counted raw entries; one entry pointed at a song that no
longer existed in the library; the editor dropped it. So I made the card count
only entries that *resolve*. Card says 5, editor says 5, consistent, done,
shipped.

Then the actual user of the app — me, wearing the other hat — looked at it and
said: *there are six songs in that setlist.* The sixth entry isn't noise. It's
a song that got deleted from the library while the setlist still references
it. The setlist has six entries. Showing 5 didn't fix the lie; it just made
both numbers lie in agreement.

## The real bug

Digging into every consumer of a setlist turned up something much worse than a
wrong number. The editor didn't just *hide* unresolvable entries —
**it deleted them on save**. Open a setlist, change the name, hit Save, and
any entry whose song had been deleted was silently gone forever. The metronome
refused to play the whole setlist if *one* entry didn't resolve. And the
duplicate-merge tool rewrote one copy of the song list but not the other, so
its own fix got reverted by the next save.

Three consumers, three different opinions about what an orphaned entry means.
That's not a display bug. That's a data model nobody ever agreed on.

## The principle

One sentence fixed all of it: **an unresolvable entry is still an entry.**

- The card counts entries. Six means six.
- The editor shows all six — the orphan renders as an "Unavailable song" row
  you can see, reorder, or swipe away yourself (with Undo, naturally).
- Saving round-trips orphans untouched. The app never deletes your data
  because it couldn't find something.
- The metronome plays the five songs it can resolve instead of refusing to
  play six.

On the phone, the card now says 6, and opening the setlist shows six numbered
rows — number two politely admitting it's unavailable, exactly where it always
was.

## The lesson

The first fix made the numbers consistent. The second fix made them *true*.
Those are different bugs, and the difference was one deleted song away from
being someone's lost setlist the night before a gig.

*Next: S9E4 — The test suite that lied to me.*
