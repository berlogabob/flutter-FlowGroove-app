---
categories:
- devlog
date: '2026-08-20T06:00:00+01:00'
draft: true
slug: connect-your-own-ai
summary: "An MCP endpoint so your assistant can read and add songs directly — behind a key you own, on a format you can read."
tags:
- devlog
- feature
title: "Connect your own AI — and I don't pay for it"
---

## What changed

You can now point your own AI agent at FlowGroove over **MCP** and manage your songs by chat.

- Create an API key in the app (read, or read + write), run a small local server, and add it
  to Claude / ChatGPT / Gemini. Your assistant gets tools: list, get, validate, create and
  update songs.
- It's built on the Song JSON format from the last post — every write is validated and lands
  **only in your own library**. No mass-delete, no touching the shared catalog.
- Security first: the key is shown once and only its **hash** is stored; it's revocable and
  scoped; demo accounts can't mint keys.
- And the whole point: **your AI, your tokens.** FlowGroove runs the gate, not the model.

## Why it matters

The user who reshuffled my roadmap said it plainly: *"I don't want to fill anything by hand
— I want to say what to do and have it done."* MCP is exactly that, without turning
FlowGroove into an AI company with an AI company's costs. A stable format plus a key you own
turns "type every field" into "tell your assistant."
