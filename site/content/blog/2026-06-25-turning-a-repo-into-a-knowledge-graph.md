---
categories:
- devlog
date: '2026-06-25T22:30:00+01:00'
draft: true
slug: turning-a-repo-into-a-knowledge-graph
summary: "Reading files one at a time tells you what each does. Turning the whole repo into a graph tells you how it's actually shaped — and where the surprises hide."
tags:
- devlog
- ai
title: "Turning a repo into a knowledge graph"
---

## What changed

I started turning the codebase into a queryable knowledge graph instead of only ever
reading it file by file.

- The graph models the repo as nodes and connections — which providers, screens, and
  services actually reference each other — so you can *ask* it questions instead of grepping
  and guessing.
- It surfaces "god nodes" (the things everything depends on) and clusters of related code,
  which is how I found that one provider quietly wired into thirty places it shouldn't have.
- You can trace a path between two pieces of code and get an explanation of how they connect
  — coupling made visible rather than inferred.

## Why it matters

Past a certain size, a codebase has a *shape* you can't perceive by scrolling. You can know
every file and still be blind to the structure they form together. A graph view answers the
question that actually predicts bugs — "what touches what?" — which is different from, and
more useful than, "what does this function do?" As FlowGroove grew, that shift in question is
what kept it understandable.
