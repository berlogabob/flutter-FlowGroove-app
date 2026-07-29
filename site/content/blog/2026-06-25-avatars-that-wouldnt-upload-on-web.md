---
categories:
- devlog
date: '2026-06-25T14:00:00+01:00'
draft: true
slug: avatars-that-wouldnt-upload-on-web
summary: "Profile photo upload worked on Android and silently failed on the web. One method call was the whole difference."
tags:
- devlog
- war-story
title: "Avatars that wouldn't upload on web"
---

## What changed

Uploading a profile photo now works on the web, not just on Android.

- **Symptom:** pick a photo on the web build, hit save, nothing lands. Same code,
  same flow, worked fine on the phone.
- **The hunt:** the upload used `putFile` — which takes a file path. On the web
  there's no filesystem path; the image is bytes in memory. So the call had nothing
  real to point at and quietly did nothing.
- **The truth:** web needs `putData` (raw bytes), not `putFile`. While I was in
  there, two more web-only gotchas surfaced: the storage bucket needed CORS set so
  the uploaded image would actually *display*, and photos imported from another
  service had to be mirrored server-side rather than hotlinked.

## Why it matters

"Write once, run everywhere" is mostly true with Flutter — until you hit the
platform seams, and file handling is a big one. The phone has files; the browser
has bytes. Most cross-platform bugs I've hit live exactly on that line, and they
fail quietly, which is the worst way to fail.
