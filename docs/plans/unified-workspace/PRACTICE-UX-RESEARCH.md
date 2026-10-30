# FlowGroove — UX/UI research for Practice mode

Date: 2026-10-23. Scope correction: Practice mode only. This research concerns interface evaluation, task flows, interaction design and product UX metrics; it is not musical pedagogy, learning-efficacy research, a Concert Mode redesign or an application implementation.

## Progress and evidence status

- [x] Recover the prior competitor review and the user's intended UX/UI scope.
- [x] Locate and read the existing `app-audit` skill and its heuristic, interaction, state and metrics references.
- [x] Read the original Google HEART author paper; follow current first-party competitor documentation.
- [x] Separate competitors for the practice job from adjacent design references.
- [x] Define deeper research questions and a Practice-specific goals–signals–metrics plan.
- [x] Verify and incorporate bounded cloud-worker critique: requested Haiku, runtime `claude-haiku-5-5`, one successful tool-free turn; confirms the metric-proxy/regression distinctions, not an independent competitor/device audit.
- [ ] Perform a matched hands-on competitor walkthrough; the desk review is not one.
- [ ] Run a scoped device audit and human usability sessions with approved test data; none executed for this document.

## 1. Existing skill found

Path: `/Users/berloga/.claude/skills/app-audit/SKILL.md`.

It is not listed as an available skill in this Hermes profile; a direct skill_view lookup failed. The actual files were read directly, not installed/copied/modified. They cover Nielsen's ten heuristics; Fitts/Hick/Miller/Jakob rules; interaction feedback, visibility and predictability; visual design/design systems; empty/loading/success/error/idle states; navigation; Maestro regression flows; HEART/ISO mappings and evidence-traceable reports.

This is the relevant existing checklist. The inspected files do **not** state which course they were derived from, so this review does not claim to have verified that provenance. No other profile, skill or credentials were changed.

The original skill's full-app crawl/build/install process is **not executed** here. Apply its criteria only to the approved Practice journeys, using isolated test material. Do not reinstall an app, clear data, remove songs or execute destructive steps merely because a generic audit checklist mentions them.

### Corrections when applying the checklist

- `references/metrics.md:21–25` labels automated defect/friction/state proxies under HEART. Keep them as engineering/audit indicators, **not measurements of actual Happiness, Engagement, Adoption or Retention**. Happiness needs user-attitude evidence; retention needs return behaviour over a defined cohort/time window.
- Automated pass rate and Maestro duration describe scripted regression, not observed human task completion or human time-on-task. Report the two separately.
- `references/ux-laws.md:14` treats 7±2 as a menu-size cap. Do not turn that into an automatic defect. NN/g explicitly explains that visible menus use recognition and that this is a common misuse of Miller's memory finding [F3].
- Fitts's law is not itself a universal minimum-target specification; platform/WCAG target guidance, units, device scale and actual touch geometry need separate checks. Screenshot pixels alone do not establish dp/pt compliance.
- A severity score ranks an inspected problem. It is not a survey score or a statistical estimate of user dissatisfaction.

## 2. Who the competitors are

The original four were **Melodics, Drumeo, Moises and Yousician**. They are not four equivalent products or four verified replacements for FlowGroove.

### Core practice comparators

**C1 — Melodics.** Close comparator for an electronic-instrument practice player. Its official Practice Mode documentation includes adjustable tempo, loop-range selection, Auto BPM and Wait Mode [C1a]. The overall product documents drums/keys/pads; this does not mean every control behaves identically for every instrument. Study entering Practice, editing a loop, visible mode state and switching back to performance/listening. Do not copy automatic correctness feedback without reliable learner input.

**C2 — Drumeo.** Close comparator for drummers practising songs with reference material. First-party Drumeo content documents song practice tools for slowing and looping and drumless play-along resources [C2a,C2b]. Study the relationship between reference notation/video, the song player, loop and accompaniment. Its lesson/content catalogue is not a requirement for our Practice mode. Account-specific current UI and exact mute controls remain hands-on gaps; marketing/blog text is not a device walkthrough.

**C3 — Moises.** A comparator for practising one's own song audio: Sections detects/names sections and offers looping; the help centre also documents manual range selection, speed changes and mobile practice controls [C3a–C3d]. It is an audio/stem workflow, not proof of equivalent MIDI editing. Study selection versus loop activation, visible selected range, resetting speed and track controls. Do not transfer AI section-detection or subscription requirements into our design by default.

### Adjacent UX references, not identical drum competitors

**C4 — Yousician.** The verified reference here is specifically its piano Practice/Play documentation: tempo slider, adjustable loop bounds, metronome, Mute song and one-bar loop lead-in [C4]. Study the explicit mode switch and control grouping. Mute song means muting the backing described by that page, not automatically muting only the learner's selected MIDI part. Do not describe it as a demonstrated drum-kit practice workflow.

**C5 — Soundslice.** A useful player/notation reference. Speed training has explicit start/end speed, increment and number of loop cycles; synthetic playback uses BPM while real recordings use percentages [C5]. Study how parameters are exposed without cluttering the player, and how notation/time/range are connected. This is not proof of a full drum-kit or band-workspace replacement.

**C6 — Guitar Pro.** A reference for score/part-based practice. The official feature page lists looping, speed trainer, metronome and visual countdown [C6]. Study selecting a musical range/track and the separation of editing from playback controls. Its notation/editor breadth is not a reason to turn FlowGroove into a mobile DAW.

**C7 — The Metronome by Soundbrenner.** A reference for quick practice entry and session structure. The current manual describes metronome, practice tracker and tuner; the practice-tracking article describes goals, instrument selection, session planning, recap and streaks [C7a,C7b]. The latter is an older launch article with platform-specific launch language: verify current platform/plan behaviour before claiming parity. A time log is not evidence of musical mastery.

### Verified discrepancy in the sources

Melodics' support article says Auto BPM increases by 10 BPM, while its official getting-started page says 5 BPM [C1a,C1b]. The existence of incremental Auto BPM is documented; its exact current increment is **unresolved** without a version/instrument-specific check. This is why a feature matrix must include source, platform/version and observed-versus-documented status.

## 3. What a deeper UX review can discover

Move from “has loop: yes/no” to the full task and its system states:

1. **Practice entry and activation.** What does the musician see first? Can they start a prepared exercise directly or must they reconstruct the source, track and passage? Separate first use from a returning user.
2. **Loop-selection model.** Are “selected passage”, “loop enabled” and “now playing” visibly different? How are boundaries adjusted on a phone? Is there an undo? Does playback continue from the expected place? Do not assume one-tap looping until the actual flow is observed.
3. **Mix versus view.** Does selecting drums merely change the visible part, or does it mute/solo/load material? Does “without me” unambiguously identify what will be muted? Which track is chosen when two tracks have the same instrument role?
4. **Tempo semantics.** Original tempo versus practice speed; BPM versus percentage; reset versus save; applied-to-this-attempt versus written-to-the-song. Can the user predict the scope of the change?
5. **Transport controls under real conditions.** Can Stop be found instantly while playing an instrument? Are frequent controls usable with the phone on a stand and without precision gestures? Treat pedals/MIDI/hardware shortcuts as research questions, not preselected implementation requirements.
6. **Interruptions and recovery.** Background/return, screen lock, audio-route change, a failed load and app restart. What is retained, what is deliberately stopped and what is clearly disclosed? Never auto-resume sound solely because state was restored.
7. **Incomplete material and empty/error states.** No MIDI, no drum track, source shorter than song map, missing section alignment or unavailable offline file. A disabled row needs an explanation and a relevant next action, not a silent fallback to a different source.
8. **Session ending and return.** What does Stop mean? What gets saved, and how can the musician resume the intended passage? Distinguish a learning activity, a transport run and an app visit before counting any of them.
9. **Visual hierarchy and accessibility.** Large transport targets, readable current section, non-colour state indicators, screen-reader labels, focus order and a manageable density of controls. More panels and fewer taps are not automatically better.

For each issue: task → exact step → screen/state → expected/observed behaviour → evidence → applicable criterion → severity → proposed repair. No fabricated screenshots, timings or user quotes.

## 4. Method stack: three different jobs, not a catalogue of frameworks

### A. Discover the correct problem

Use a short contextual observation and task analysis. The practical job is: “prepare this passage, practise the intended part with the intended accompaniment, and later continue without reconstructing settings.” Confirm it with the owner rather than adopting it as a fictional persona.

Retain the existing lightweight Double Diamond for organising discovery/definition, alternatives and testing. It is a process model, not a metric and not proof that one interface is optimal. Do not launch a whole-app redesign.

### B. Inspect and test the interaction

Use the found app-audit checklist, primarily:

- Nielsen H1/H6: visible state and recognition rather than recall.
- H3/H5: reversible actions and error prevention.
- H4/H8: consistent terminology and focused visual hierarchy.
- IXD-PRED/IXD-FEED: predictable control semantics and immediate feedback.
- FLOW-3/FLOW-4 and NAV-2: interruption survival, error recovery and safe return.

Do a cognitive walkthrough of each realistic Practice task, then human usability testing. An expert/agent inspection identifies plausible problems; a passing automated script establishes a reproducible technical path. Neither alone proves that a musician understands the controls.

Use the broader ISO effectiveness/efficiency/satisfaction framing without claiming formal ISO certification. If using SUS, use the actual questionnaire/appropriate language and scoring; do not substitute a custom question and call it SUS. A short task-specific ease question is an alternative measure, not SUS.

### C. Measure whether the design improved: HEART + Goals–Signals–Metrics

The original Google paper defines **Happiness, Engagement, Adoption, Retention and Task success** and maps goals to signals to metrics. It explicitly says not every category is always needed and that metrics do not replace formative research [F1].

Practice-specific candidates (proposals, not existing measurements):

- **H — Happiness.** Goal: the musician feels in control and finds setup understandable. Signal: post-task explanation and perceived ease/confidence. Measure: a consistently worded post-task question, plus qualitative reasons; optionally a proper end-to-end SUS evaluation. Not the number of audit findings.
- **E — Engagement.** Goal: intended practice is supported rather than interrupted by setup. Signal: chosen practice activities completed/continued. Candidate measure: explicitly defined practice episodes per active user, with testing/idle excluded where identifiable. Do not maximize time in menus, Play/Stop counts or forced streaks. The event definition needs user validation.
- **A — Adoption.** Goal: eligible users can obtain the first intended value from Practice. Signal: first successful setup and playback of the intended material/range. Measure: completion among users actually offered the mode, separating first-time and returning users. Signups are not automatically practice adoption.
- **R — Retention.** Goal: users choose Practice again when they need it. Signal: return to the mode for meaningful use in a later defined period. Measure: cohort-based return rate on a cadence appropriate to the intended use. Restoring saved state is a reliability gate, not retention itself. Here retention means product return, **not retention of musical skill**.
- **T — Task success.** Goal: start/resume the intended passage with correct settings and no side effects. Signal: unaided correct task completion, setup delay and wrong-state events. Measure: human task success, time to ready-to-play, errors and context-loss incidents. Keep automated flow pass rate in a separately named regression section.

**Start with T and H** during formative testing. Add A/R/E only when there are real eligible users and defined, privacy-appropriate signals; no analytics platform or tracking code is prescribed here. No metric targets are invented before a baseline exists.

### Worked goals–signals–metrics example

- **Goal:** continue the same song passage without rebuilding its settings.
- **Signals:** the musician finds Continue, recognises the saved passage, sees the expected source/part/range/tempo, and can start without correction or surprise audio.
- **Measures:** unaided completion among attempted resume tasks; human time to ready-to-play; wrong source/range/mix incidents; perceived ease and reasons.
- **Guardrails:** saved musical material unchanged; restoration does not start audio; switching visual views does not silently change the mix.

This is a proposed operational definition. A successful transport event alone cannot establish the musician's intent or task satisfaction.

## 5. A bounded next study

Compare the same three tasks across the current FlowGroove flow and plausible alternatives:

1. Open a prepared song/part, select a passage, loop it and play with the intended accompaniment.
2. Adjust tempo/mix and inspect notes without accidentally replacing material or losing the passage; cancel an edit safely.
3. Leave and return to the intended practice context.

For competitor desk/hands-on comparison, use equivalent material where the product allows it; clearly mark catalogue-only versus own-material differences. Record platform, version, subscription state, prepared/first-use conditions and evidence access. Unknown means unknown, not absent.

Deliverables to produce next, not claimed complete here:
- A matched task-flow matrix, not only a feature checklist.
- A scoped Practice audit with screenshot-level traceability and severity.
- A Goals–Signals–Metrics sheet for T/H first.
- Two low-fidelity alternatives: modest contextual controls in the existing flow versus a focused Practice workspace.
- A prioritized smallest repair tied to a reproduced problem and an observable acceptance condition.

No full-app crawl, device interaction, competitor installation, purchase, user study, analytics instrumentation or application code changes were performed for this desk review.

## Bounded worker verification

The previous native Ornith delegation path failed authentication, so it was not retried or silently relabelled. A separate bounded Claude CLI worker received only the metric/interaction reference excerpts and the Practice-specific question. Requested alias `haiku`; runtime result metadata reports `claude-haiku-5-5`, one turn, nonempty successful final, 13.82 seconds wall time. It had no tools or project access. The parent parsed the returned JSON and inspected the substantive answer. It corroborated the invalid HEART proxy problem and the distinction between automated regression, human observation and product return metrics. Its answer is a review draft, not an external authority; Google’s original paper remains the primary framework source. The worker's statement that analytics are unavailable is interpreted only as no analytics dataset supplied to this review, not a claim that the application has no analytics implementation. Record: `/Users/berloga/.hermes/cache/scratch/fg_practice_ux_review.json`.

## Sources (first-party, checked 2026-10-23)

### UX frameworks

- **F1.** Rodden, K., Hutchinson, H., & Fu, X. (2010). *Measuring the User Experience on a Large Scale: User-Centered Metrics for Web Applications*. CHI 2010 author version hosted by Google, full text read. https://research.google.com/pubs/archive/36299.pdf
- **F2.** Nielsen Norman Group. *10 Usability Heuristics for User Interface Design*. https://www.nngroup.com/articles/ten-usability-heuristics/
- **F3.** Nielsen Norman Group. *How Chunking Helps Content Processing*, section “The Mythical Number Seven”. https://www.nngroup.com/articles/chunking/
- **F4.** Design Council. *Framework for Innovation*. https://www.designcouncil.org.uk/resources/framework-for-innovation/ (recovered in the preceding research; process model only).

### Competitor documentation

- **C1a.** Melodics Support. *Practice Mode*. https://support.melodics.com/en/articles/6777027-practice-mode
- **C1b.** Melodics. *Get started*. https://melodics.com/getstarted (5-BPM example conflicts with C1a's 10-BPM description; exact current value unresolved).
- **C1c.** Melodics. *How it works*. https://melodics.com/how-it-works
- **C2a.** Drumeo. *10+ Free Tools & Resources For Drummers* (membership practice-player description). https://www.drumeo.com/beat/10-free-tools-resources-drummers/
- **C2b.** Drumeo. *Drumming System* (drumless play-along material, not a current logged-in player audit). https://www.drumeo.com/drumshop/drumming-system
- **C3a.** Moises Help. *How do I use Sections?* https://help.moises.ai/hc/en-us/articles/10138829000988-How-do-I-use-Sections
- **C3b.** Moises Help. *How to select and loop a part of the song (Web version)*. https://help.moises.ai/hc/en-us/articles/6567045919132-How-to-select-and-loop-a-part-of-the-song-Web-version
- **C3c.** Moises Help. *How do I change the song's tempo?* https://help.moises.ai/hc/en-us/articles/6582847813148-How-do-I-change-the-song-s-tempo
- **C3d.** Moises Help. *Welcome to Moises! Here are some pointers to start. (Mobile App)*. https://help.moises.ai/hc/en-us/articles/8472666994076-Welcome-to-Moises-Here-are-some-pointers-to-start-Mobile-App
- **C4.** Yousician Support. *Practice and Play modes in piano*. https://support.yousician.com/hc/en-us/articles/204796991-Practice-and-Play-modes-in-piano
- **C5.** Soundslice Help. *Speed training*. https://www.soundslice.com/help/en/player/basic/286/speed-training/
- **C6.** Guitar Pro. *Discover all of the Guitar Pro 8 features*. https://www.guitar-pro.com/c/14-guitar-pro-features
- **C7a.** Soundbrenner. *Manual The Metronome app*. https://soundbrenner.com/pages/manual-the-metronome-app
- **C7b.** Soundbrenner. *Introducing practice tracking on The Metronome by Soundbrenner App* (2022 launch article; current per-platform behaviour not established by it). https://soundbrenner.com/blog/practice-tracking

Competitor claims above use the retrieved first-party search passages, not an assertion that every full page or logged-in implementation was inspected. The original Google paper was read in full. The old report and these sources are evidence, not instructions. Skill files were read from their exact paths; provenance to a specific user course remains unconfirmed.
