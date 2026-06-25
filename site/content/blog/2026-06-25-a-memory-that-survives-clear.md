---
categories:
- devlog
date: '2026-06-25T22:00:00+01:00'
draft: true
slug: a-memory-that-survives-clear
summary: "Working with an AI assistant that forgets everything between sessions is exhausting. So I gave it a memory that lives in files and persists."
tags:
- devlog
- ai
title: "A memory that survives /clear"
---

## What changed

The AI assistant I build with got a persistent, file-based memory — facts that survive
clearing the conversation.

- Every session used to start from zero: re-explaining the deploy channels, the signing
  setup, the quirks I'd already debugged once. Groundhog Day, but with a chatbot.
- Now there's a memory system (with a "Mr. Memory" agent to tend it) that writes durable
  notes to files: one fact per file, indexed, recalled when relevant. The hard-won lessons
  from these very war stories live there.
- Next session, it already knows that web needs `putData`, that the metronome goes silent on
  Bluetooth, that membership is server-authoritative.

## Why it matters

An assistant with no memory makes *you* the memory, and that doesn't scale past a small
project. Persisting knowledge — the gotchas, the decisions, the "we tried that, it didn't
work" — turns a tool that resets every day into one that compounds. The interesting part
isn't the AI; it's that writing down what you learned, in a form something else can reload,
is leverage whether the reader is a model or a human.
