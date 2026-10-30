# FlowGroove: continuity, effective practice, and a testable repair

Date: 2026-10-23. Status: targeted evidence review and proposed design; no application implementation or learner experiment.

## Progress

- [x] Recover the previous proposal, research method and device evidence.
- [x] Search for primary music-learning and human–computer-interaction research; include disconfirming findings.
- [x] Verify the identifiers, titles, authors and publication details of the nine research papers against Crossref/publisher records.
- [x] Read available full texts and distinguish them from abstract-only evidence.
- [x] Map evidence to a minimal repair and separate observations, inferences and hypotheses.
- [x] Complete the bounded document audit via parent fallback; the delegated Ornith run failed before analysis with HTTP 401, so this is not an independent review.
- [ ] Observe an actual owner practice session and verify the interpretation of the short logs.
- [ ] Test old and proposed workflows with musicians.
- [ ] Implement and test an approved thin slice; measure delayed musical outcomes separately from usability.

## 1. Corrections to the previous synthesis

**The app evidence is not a learning experiment.** The P30 walkthrough was an agent inspecting an interface, not a musician observed practising. Baseline tests were historical execution in that research, not newly run for this review. No hardware, audio, latency or musical performance experiment was run here.

`phase2/P30-FLOW.md`, D12, records the exact interface summary: “Practiced 51 min this week across 51 sessions”, plus a visible list of short recent entries. This means weekly accumulated time, NOT an observed continuous 51-minute practice session. The visible entries do not establish the behaviour of all 51 entries. Stop/start logs could reflect practice, testing, interruptions or other activities. They cannot prove that the owner was repeatedly looping a passage. The categorical interpretation in that file §“What the flow says”, point 1, and in PROPOSAL §9 should be treated as a hypothesis pending observation/interview.

**Loop is not absent.** `EVIDENCE.md` D09 explicitly observes Loop/Quantize controls in an existing MIDI section launchpad. The product hypothesis is to make existing loop functionality discoverable in the relevant journey and preserve its context, not to invent a missing loop engine.

The old document's CODE findings report unpopulated MIDI linkage and missing range/track context in session history, and a task model with a section field not exposed by the task form. Those are integration opportunities, not proof that a unified screen causes better learning. They were recovered from the old evidence, not re-executed/reproduced here.

## 2. Research question and method

Question: what should a song/MIDI practice application preserve and support so that musicians can work deliberately on passages without rebuilding their context, and how can the design be tested?

This is a **targeted, non-systematic desk review**, not an exhaustive systematic review or meta-analysis. Search branches included: self-regulated instrumental practice; practice quality and retention; blocked/interleaved music practice; spacing/consolidation; tempo variability; interruption/resumption cues; split attention; drumming feedback and synchronization. Discovery used multiple search backends through web_search; identifiers and publisher-supplied metadata/abstracts were checked through Crossref. Inclusion favoured original experiments/observations with identifiable tasks, samples and limitations. A professional process model is included separately, not as an efficacy experiment.

Evidence-access labels:
- **FULL:** the relevant full article was retrieved and read.
- **ABSTRACT:** conclusions limited to the author/publisher-supplied abstract; no unreported protocol or effect-size claims.
- **METHOD:** a first-party process description, not experimental evidence of learning gains.

Direct extraction failed because the configured extractor was search-only. Direct publisher retrieval recovered the Frontiers and PLOS articles; the full split-attention paper was recovered from PMC. Several Sage pages were bot-blocked. Their publisher-deposited Crossref abstracts were used transparently rather than claiming access to full papers. Crossref does not always provide article numbers; Carter & Grahn's article 1251 was recovered from the publisher record. Miksza's online-first date is 2013 but the cited journal issue is 2015; Simmons is online 2011, journal issue 2012. An initially attempted Simmons DOI ending in 4797 did not resolve and was discarded; the verified DOI ends in 4798.

The review has no pooled effect estimate or formal risk-of-bias score. Small samples, short follow-up, advanced woodwind/piano tasks and laboratory tasks constrain transfer to everyday drum practice and to a mobile product.

## 3. What the evidence supports — and what it does not

### 3.1 Goal → strategy → attempt → evaluation, not minutes alone

**[S1, ABSTRACT] Miksza (2015):** 28 collegiate wind players were randomly assigned to practice-strategy instruction alone or the same strategies plus self-regulation instruction. Video instruction ran over five days. Both groups improved; the self-regulation group made greater performance gains on day 5 when day-1 gains were controlled. The added instruction included goal selection, planning, concentration, self-evaluation and rest/reflection. This tests a teaching intervention, not an application interface and not long-term drum outcomes.

**[S2, ABSTRACT] Duke, Simmons & Cash (2009):** an observation of 17 advanced piano students working on a short passage found no significant relationship between next-day performance ranking and total practice time/trial count. Accuracy-related practice measures were associated with ranking. This is a small observational study, not proof that time never matters or that preventing errors causes learning.

**Design inference:** make it easy to name a specific goal, choose a passage, listen/try, inspect or self-evaluate, then decide the next action. A goal can be one short optional note, not a mandatory questionnaire. Count elapsed practice and performed attempts honestly; neither is mastery. A completed playback is not necessarily a correct human performance. Recordings and musician/teacher judgement can provide feedback before any scoring system exists.

### 3.2 Repetition and interleaving are tools, not competing religions

**[S3, FULL] Carter & Grahn (2016):** ten advanced clarinetists compared blocked practice (12 minutes per piece) with interleaving (alternating three-minute blocks to equal total time). Recordings were assessed at practice end and the following day. Some assessments favoured interleaving, but results differed by rater and musical material; the authors describe modest evidence. This does not establish universal superiority, an optimal three-minute timer or a schedule for drum novices.

**Design inference:** retain ordinary loops for isolating a difficulty. Offer a small, explicitly chosen queue of passages so that a learner can return to A after B, instead of forcing endless A repetition. Preserve each passage's context. Do not randomly switch material mid-performance or impose a schedule. Practice alternation is a pedagogical choice; navigation-induced loss of state is a software fault. They must not be confused.

### 3.3 Verify what remains later, not just what felt fluent now

**[S4, ABSTRACT] Simmons (2012):** 29 non-pianist musicians learned a short piano sequence in sessions separated by five minutes, six hours or 24 hours. Accuracy improvement at session 2 occurred only in the 24-hour group; speed results differed across sessions/intervals. This task supports examining consolidation/spacing but cannot separate every sleep/time-of-day explanation or prescribe a universal reminder interval.

**Design inference:** preserve the passage, target and last-used settings for later return. Offer an optional future revisit and a first-attempt recording before more repetition. Compare performance after a delay, not only the last fluent loop. An initial next-day check is an evaluation-protocol choice, not an established optimum for all users.

### 3.4 Slowdown and tempo progression should remain controllable

**[S5, FULL] Caramiaux et al. (2018):** 48 complete novices learned short piano sequences under different tempo sets and random/nonrandom schedules. Timing transfer showed little practice-condition effect; motor-variability results favoured the smaller tempo set and nonrandom ordering. The finding is a counterexample to the claim that more variation/randomness is always better. It does not test the exact proposed Ramp feature or establish an ideal BPM increment.

**Design inference:** allow a comfortable speed, deliberate returns to target tempo, and optional progression. Do not label a fixed “+N BPM every K loops” rule scientific or automatically infer readiness from loop count. A practice-local speed must not silently rewrite song or band BPM.

### 3.5 Keep musical context visible and recoverable

**[S6, ABSTRACT] Ratwani & Trafton (2010):** interruption conditions differed in whether relevant primary-task cues remained visible. The visible-primary-task condition was least disruptive; the result concerns cue association, not a proof that every activity belongs on one screen.

**[S7, FULL] Skulmowski (2023):** two anatomy-learning experiments (125 and 152 participants) found worse retention with spatially separated labels than integrated labels. Realism effects were mixed. Transfer to an interactive musical interface is indirect: this does not prove realistic drum skins help or that combining all panels is beneficial.

**Design inference:** keep song, section/range, part and current mode visible around the active task; show note/instrument cues together when they need to be interpreted together. Put detailed editing and Lab notes in task-focused views, with shared context. Provide explicit resume cues. Less navigation is not an end in itself; an overloaded dashboard can still be worse.

### 3.6 Feedback can be useful; fabricated precision cannot

**[S8, ABSTRACT] Tsuji & Nishitaka (2006):** a drum-support system was evaluated with 24 inexperienced drummers; the abstract reports performance improvement from rhythm feedback. It does not establish the learning efficacy of our unbuilt UI or a generic percent-correct score.

**[S9, ABSTRACT] Fujii et al. (2011):** 15 professional drummers synchronized a basic drum-kit pattern at several tempi. Mean synchronization offsets differed by limb and tempo, and limb timing was interrelated. This is descriptive synchronization research, not a grading rule or a study of expressive groove.

**Design inference:** imported MIDI is reference material, not evidence of what the learner actually played. Initially support recording, replay and focused human assessment. Any later automatic timing feedback requires real performance input, validated matching, instrument mapping, clock/latency handling and disclosed limitations. Do not grade every limb against a single supposedly universal zero-offset threshold or infer fingering/limb use from ordinary note-only MIDI.

## 4. The minimal repair I recommend

This is a product hypothesis informed by the papers, not a result of those papers.

### 4.1 One shared context, not one enormous screen

Reuse the existing song, source, section identity, note material and transport. Preserve a small selection across relevant views:

```text
song + source/MIDI entry + selected track/part
+ section occurrence / exact range
+ practice speed + mix + cursor
```

Opening a view should not reload backing, mutate mix, move the cursor, write an arrangement or restart playback. An explicit source replacement is a different operation. Reopening the application restores a ready-but-stopped context; it must not unexpectedly start audio. Switching views during deliberate ongoing playback should not stop it.

Agree the meaning of phrases versus bars and verify source-to-section alignment first. An eight-bar MIDI does not become full-song coverage by spreading it across a larger map. Keep immutable source material and explicit edit drafts/overlays; preserve long/held/off-grid notes. Do not begin with a new transport, parser or generic plugin framework.

### 4.2 Distinguish the learning episode from transport actions

Use these as UX/domain terms initially, not a demand for new persisted classes:

- **Practice session:** the deliberately started/continued activity, ended explicitly or confirmed later.
- **Focus:** source + part + passage + goal currently being worked on.
- **Attempt:** one try within that focus, including a clearly marked partial attempt where applicable.

Stop stops audio immediately; it need not finalize the whole practice episode. Automatic full-loop counting must exclude count-in and distinguish partial playback, pauses and skips. Changing focus can create a new segment inside the same session. Do not silently merge historical entries using a time heuristic; preserve raw history and mark any inferred grouping as such. Confirm the owner's preferred session boundaries before choosing persistence rules.

### 4.3 The first vertical journey

Use existing drums and one real song before adding new instrument diagrams:

1. Open a song on its play/practice surface; metadata remains accessible.
2. Explicitly choose material, a section/range and the drum part.
3. Set an optional goal such as maintaining a clean transition into the chorus.
4. Audition, loop, adjust practice speed, optionally mute the reference part.
5. Record an optional take; attach it and any task to that passage at capture.
6. Stop and leave; Continue later restores the same passage/settings without auto-playing.

Keep quick songless metronome practice available. For free recordings and tasks, linkage is optional, not a requirement to invent a song.

After this journey works, add an optional passage queue/interleaving, revisit reminders and richer keys/guitar projections. Performance should share prepared material/context, but remove practice prompts and unsolicited switching. Whole → difficult passage → whole is a useful candidate workflow, not a separately established winner in this review: S1's intervention bundled several techniques and cannot isolate each technique's effect.

## 5. How to find out whether this actually helps

### 5.1 Product method

Continue the existing lightweight **Double Diamond** [M1]: observe and define, compare alternatives, then deliver/test a thin slice. It is a process framework, not scientific proof of a particular interface.

- Observe the owner using a normal practice task. Ask what the short log entries represented; do not infer intention from counters.
- Map the actual actions and state transfers: song → source → passage → edit/listen → practise → task/recording → resume.
- Compare a small contextual panel added to the current design with a dedicated workspace. Do not make “rebuild all screens” the only alternative.
- Do an inspection/cognitive walkthrough before user sessions: will the musician know the next action, find the control, understand its effect and recognize the result? This screens obvious problems; it does not replace user testing.

### 5.2 Formative usability comparison

Use the current and proposed flow with the same realistic task types. Counterbalance order and use matched examples so that familiarity with the first condition does not become the explanation for the second condition's speed. Start with the owner, then musicians using other intended instruments. Such an initial sample finds design problems; it does not establish population-wide efficacy.

Tasks:
1. Find a specified song passage, choose the part, listen, loop and practise without that part.
2. Open notes/editor and return without losing the selected range or changing playback/mix unintentionally; cancel an edit safely.
3. Capture a take or task for that passage, leave, and resume it later at the intended settings.

Measure unaided completion, time to the intended ready-to-play state, context reconstruction actions, mistaken source/part/section, accidental stops/loads/mix changes, edit loss and user explanation of what will play. Record taps as a diagnostic, not the success metric.

Non-negotiable acceptance gates: no data loss; no surprise audio; no implicit mix/source replacement on a view switch; correct passage and tempo restored. Exact numeric speed targets should be set after baseline observation, not fabricated now.

### 5.3 Musical outcome comparison (a separate experiment)

A faster interface is not proof of better musical learning. For a learning claim, compare matched passages with baseline ability and practice dose accounted for; randomize/counterbalance conditions where feasible. Record immediate performance and a delayed first attempt, using the same target tempo and comparable accompaniment conditions. A teacher/evaluator unaware of condition can judge agreed rhythm/transition criteria. If measuring input automatically, validate it first.

Assess retention/transfer, not only minutes, app engagement or maximum BPM. Do not call a before/after result from one repeatedly practised passage a causal controlled experiment. Sample size and follow-up for a confirmatory efficacy study require a separate study design; this review does not supply an invented power calculation.

## 6. Bounded document audit — parent fallback

The requested independent Ornith audit did not execute: its provider rejected authentication with HTTP 401 (one API call; no findings). No credential/configuration changes or retry were attempted. The parent completed the review of RESEARCH, EVIDENCE, PROPOSAL, PLAN, phase2/P30-FLOW and phase2/COMPETITORS. This is a self-review, not independent corroboration.

Additional claims to temper in the old documents:

- `phase2/COMPETITORS.md:25` infers an actual drummer stopping/restarting to loop a fill. D12's weekly summary and sampled entries do not establish that behaviour.
- That document's matrix distinguishes Moises count-in before playback from Yousician's explicit loop-restart lead-in. Do not claim both sources establish a count-in on every loop restart without further source evidence.
- Claims that competitors' paths/logs all retain a specific practised passage need row-level verification; a documented lesson/song history is not automatically a section/track/range resume mechanism.
- The absence of a workflow in the sampled competitor pages is not proof that no competitor supports it. Treat own-MIDI plus band-map continuity as a positioning hypothesis, not demonstrated market uniqueness.
- `RESEARCH.md:10,15`, `PLAN.md` pending validation and `EVIDENCE.md:86` already acknowledge that device inspection and selected baseline tests are not user testing, hardware validation or proof of the unimplemented workspace. Preserve those distinctions.

The three usability tasks and metrics in §5 remain proposals; none was executed during this review.

## 7. Priority decision

**First repair continuity for one drum-practice journey, then evaluate learning supports.** The scientific case is strongest for supporting purposeful, monitored practice and measuring retention rather than equating repetition/time with progress. Evidence for exact interleaving/tempo schedules is conditional. Evidence for the precise FlowGroove workspace is currently absent and must come from our own usability and learning studies.

No application code, migrations, saved songs or device state was changed for this review. No new application test suite or user experiment was run. The delegated document audit failed on authentication; its parent fallback and limitations are recorded in §6. The source checks and conclusions above were performed directly by the parent researcher.

## References and access

### Original research

- **S1 — ABSTRACT.** Miksza, P. (2015). The effect of self-regulation instruction on the performance achievement, musical self-efficacy, and practicing of advanced wind players. *Psychology of Music, 43*(2), 219–243. https://doi.org/10.1177/0305735613500832 . Publisher-deposited abstract and metadata via Crossref; publisher full text blocked. Online first 2013, issue 2015.
- **S2 — ABSTRACT.** Duke, R. A., Simmons, A. L., & Cash, C. D. (2009). It's Not How Much; It's How: Characteristics of Practice Behavior and Retention of Performance Skills. *Journal of Research in Music Education, 56*(4), 310–321. https://doi.org/10.1177/0022429408328851 . Publisher-deposited abstract and metadata; publisher full text blocked.
- **S3 — FULL.** Carter, C. E., & Grahn, J. A. (2016). Optimizing Music Learning: Exploring How Blocked and Interleaved Practice Schedules Affect Advanced Performance. *Frontiers in Psychology, 7*, article 1251. https://doi.org/10.3389/fpsyg.2016.01251 . Full text: https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2016.01251/full .
- **S4 — ABSTRACT.** Simmons, A. L. (2012). Distributed Practice and Procedural Memory Consolidation in Musicians’ Skill Learning. *Journal of Research in Music Education, 59*(4), 357–368. https://doi.org/10.1177/0022429411424798 . Publisher-deposited abstract; online first 2011, issue 2012.
- **S5 — FULL.** Caramiaux, B., Bevilacqua, F., Wanderley, M. M., & Palmer, C. (2018). Dissociable effects of practice variability on learning motor and timing skills. *PLOS ONE, 13*(3), e0193580. https://doi.org/10.1371/journal.pone.0193580 . Full text: https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0193580 .
- **S6 — ABSTRACT.** Ratwani, R., & Trafton, J. G. (2010). An Eye Movement Analysis of the Effect of Interruption Modality on Primary Task Resumption. *Human Factors, 52*(3), 370–380. https://doi.org/10.1177/0018720810374195 . Publisher-deposited abstract; PubMed identifier 21077561.
- **S7 — FULL.** Skulmowski, A. (2023). Realistic details impact learners independently of split-attention effects. *Cognitive Processing, 24*(2), 187–198. https://doi.org/10.1007/s10339-022-01123-z . Full text: https://pmc.ncbi.nlm.nih.gov/articles/PMC10110660/ .
- **S8 — ABSTRACT.** Tsuji, Y., & Nishitaka, A. (2006). Development and evaluation of drum learning support system based on rhythm and drumming form. *Electronics and Communications in Japan (Part III: Fundamental Electronic Science), 89*(9), 11–21. https://doi.org/10.1002/ecjc.20275 . Publisher-deposited abstract; no claim of a full-text review.
- **S9 — ABSTRACT.** Fujii, S., Hirashima, M., Kudo, K., Ohtsuki, T., Nakamura, Y., & Oda, S. (2011). Synchronization Error of Drum Kit Playing with a Metronome at Different Tempi by Professional Drummers. *Music Perception, 28*(5), 491–503. https://doi.org/10.1525/mp.2011.28.5.491 . Publisher-deposited abstract.

### Process, not learning-efficacy evidence

- **M1 — METHOD.** Design Council. Framework for Innovation / Double Diamond. https://www.designcouncil.org.uk/resources/framework-for-innovation/ . First-party process description retrieved 2026-10-23.

### Verification and procedural provenance

Bibliographic identifiers/metadata were checked at `https://api.crossref.org/works/{doi}`. Local retrieval snapshots and records used during this review are temporary research material at `/Users/berloga/.hermes/cache/scratch/flowgroove-science/`; the references above, not those temporary paths, are the durable sources. No user/project data was sent in literature-search requests.

Citation verification used the citation-management procedural skill from Scientific Agent Skills. This is research tooling, not evidence for any music-learning recommendation: Kassis, T., Agarwal, V., He, Y., Patel, D., & Brueckner, A. M. (2026). *Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents*. arXiv:2609.00065. https://doi.org/10.48550/arXiv.2609.00065 . The live arXiv record was checked; it currently reports v2. Author metadata was independently checked before the report's finalization.
