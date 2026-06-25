---
categories:
- devlog
date: '2026-06-25T19:15:00+01:00'
draft: false
slug: permission-denied-on-a-new-account
summary: "Brand-new accounts crashed the moment they touched a band. The culprit was a user document that was supposed to exist and didn't."
tags:
- devlog
- war-story
title: "Permission denied on a brand-new account"
---

## What changed

Creating or joining a band on a fresh account works now, instead of throwing a
permission error.

- **Symptom:** sign up, try to create or join a band, and it blows up with
  permission-denied. Existing accounts were fine; only new ones broke.
- **The hunt:** the role check read a `users/{uid}` document to figure out what you're
  allowed to do. For a brand-new account that document didn't exist yet, so the lookup
  failed — and the security rules, reasonably, denied an action it couldn't authorize.
- **The truth:** two fixes. Harden the Firestore rules so the failure mode is sane, and
  make sign-in *ensure* the user document exists before anything tries to read it. No
  doc, no role; no role, no access.

## Why it matters

The empty state is the state you forget to test, because you live in your own already-
set-up account. New users land in a world where nothing exists yet, and code that assumes
"of course there's a user document" greets them with a crash. Building for the very first
second of an account's life is its own discipline — and skipping it means your worst bug
hits your newest user.
