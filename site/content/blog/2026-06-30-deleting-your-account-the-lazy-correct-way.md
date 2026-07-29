---
categories:
- devlog
date: '2026-08-13T06:00:00+01:00'
draft: true
slug: deleting-your-account-the-lazy-correct-way
summary: "Google Play requires in-app account deletion. Doing it on the server let me skip the entire re-authentication flow."
tags:
- devlog
- war-story
title: "Deleting your account, the lazy-correct way"
---

## What changed

You can now delete your FlowGroove account — and everything tied to it — from
inside the app.

- **The requirement:** Google Play makes in-app account deletion (plus a public
  web link) mandatory for any app with sign-in. No delete path, no listing.
- **The trap:** the obvious client-side call, `user.delete()`, throws
  `requires-recent-login` unless you signed in moments ago. So the textbook
  implementation is a re-authentication screen *before* you're allowed to delete.
- **The move:** do it on the server instead. A Cloud Function running with the
  Admin SDK deletes the auth user directly — that path isn't bound by the
  recent-login rule, so there's no re-auth screen at all. It detaches you from
  every band (dissolving empty ones, handing admin to a remaining member if you
  were the last one), wipes your songs, setlists and profile data, then removes
  the account *last* so a half-finished delete is safe to retry.

## Why it matters

The rule "every account needs a delete button" is good for users and
non-negotiable for the store. The interesting part is that the simplest *correct*
implementation was also *less* code: moving the work across one boundary — from
the phone to the server — deleted an entire re-authentication flow I'd otherwise
have had to build, style and test. Skipping a whole screen by moving one line of
responsibility is the good kind of lazy.
