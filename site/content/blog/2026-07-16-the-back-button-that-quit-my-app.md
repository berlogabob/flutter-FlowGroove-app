---
categories:
- devlog
date: '2026-07-16T18:00:00+01:00'
draft: true
slug: the-back-button-that-quit-my-app
summary: "Press back in the Tuner: app gone. Press back on the join screen your bandmate just opened from your invite link: app gone. The universal 'get me out of here' button was an ejector seat — and the fix was about where routes live, not what they do."
tags:
- devlog
- war-story
- navigation
- flutter
title: "S9E2 — The back button that quit my app"
---

## The symptom

Open the Tuner from Home. Press the system back button. The app doesn't go
back — it *exits*, straight to the Android launcher. To a user that's
indistinguishable from a crash.

Now the worse version: your bandmate taps the invite link you sent them. The
app opens on the Join Band screen. They press back — maybe just to peek at
something — and the app is gone. That screen is the **first thing every
invited user ever sees**. The audit scored this a 4 out of 4, and it earned it:
this bug sat directly on top of the app's growth loop.

## The hunt

Nothing in the Tuner's code was wrong. The bug lived in the *router
configuration*. FlowGroove's five tabs are branches of a shell navigator —
and the Tuner and Metronome had been parked in a hidden sixth branch that no
tab pointed to. Navigating there *replaced* the stack instead of pushing onto
it. An empty branch stack means system back has nothing to pop, so Android
does the only thing left: close the activity.

Join Band had the same disease for a different reason — it was a branch-root
route reached by replacement, plus a deep-link cold start where the join
screen is the only route in the entire stack.

Bonus symptom, same root cause: while inside the Tuner, the bottom bar
highlighted **Home**. The shell clamped "branch index 5" down to 0 rather
than admit the branch didn't exist.

## The fix

Where routes live, not what they do:

- Tuner, Metronome (and later Practice, Join Band) became **pushed routes on
  the root navigator** — there is always a screen underneath to return to.
- Every call site switched from "replace" navigation to "push".
- Join Band got one extra guard for the cold-start case: if back has nothing
  to pop (the deep link *is* the stack), send the user Home instead of out.
- The hidden sixth branch was deleted, and the wrong-tab highlight died with
  it — not patched, made impossible.

## The proof

An adb script on the real phone: open Tuner → back; open Metronome → back;
force-stop, launch from the actual `https://flowgroove.app/join?code=…` link →
back. Before the fix: two out of three exits to the launcher. After: zero out
of three, with the join case landing on Home.

The emergency exit is supposed to be the safest control in the room. Now it is.

*Next: S9E3 — Six songs, five showing.*
