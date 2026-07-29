---
categories:
- devlog
date: '2026-07-18T09:00:00+01:00'
draft: true
slug: the-test-suite-that-lied-to-me
summary: "Two pull requests claimed 'full suite green.' Three tests were failing the whole time. The culprit was one pipe character — and the deeper lesson is about what a green checkmark actually proves."
tags:
- devlog
- war-story
- testing
title: "S9E4 — The test suite that lied to me"
---

## The confession

Two of my UX-fix pull requests went out with the words "full suite green" in
the description. Three tests were failing in both of them. I didn't lie — I
was lied to, by a shell pipe I wrote myself.

## The one-character bug

To keep logs short I was running the suite like this:

```bash
flutter test 2>&1 | tail -3
```

A pipeline's exit code is the exit code of its **last** command. `tail`
always succeeds. So the command reported success no matter what the tests
did — and the three lines `tail` showed me were, on close inspection, the
*failing tests list*, which I happily read as a progress log.

The fix is one line older than I am:

```bash
set -o pipefail
flutter test 2>&1 | tail -3; echo "REAL EXIT: $?"
```

The moment I added it, three failures surfaced that had been shipping for two
phases. All three were the same class: tests asserting go_router's reported
URI after a `pushNamed` — which, it turns out, goes stale for pushed routes.
The *navigation* was correct (I had verified it on a real phone); only the
assertions were checking a signal that doesn't update.

## The deeper version of the same bug

A few days later the same lesson came back at a higher level. The bottom-bar
redesign passed **1,942 tests**. Then I installed it on the phone and opened
a song: the bar was in the wrong mode entirely. go_router's
`currentConfiguration.uri` — the thing my runtime detection *and* my tests
trusted — never updates for intra-branch pushes. The tests were green because
they trusted the same broken oracle the code did.

A green checkmark proves your code agrees with your assumptions. It says
nothing about whether your assumptions agree with the phone in your hand.

## The protocol that came out of it

- `set -o pipefail` on every piped test run, and the real exit code printed
  where I can't unsee it.
- Every "this failure is pre-existing/unrelated" claim gets re-verified —
  during one phase, two agents each blamed the other's files for a failure
  caused by neither.
- Nothing ships on tests alone. Every phase ends with the APK on a real
  device and a finger (well, adb) pressing the actual buttons.

Both PRs got a public correction comment. The suite now passes with a real
exit code — and I know that because the exit code says so, not because the
last three lines looked friendly.

*Next: S9E5 — Everything at your thumbs.*
