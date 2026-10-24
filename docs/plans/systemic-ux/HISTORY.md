# Activity history — append only

## 2026-10-23T22:49:32.657885+00:00 — planning baseline

- Перенесены 9 UX findings, 14 открытых GitHub issues и 8 областей неполного покрытия.
- Ничего из них не объявлено исправленным. Прежние результаты сохранены, не переписаны.
- Studio /models отвечает; 35b chat probe завершился length/empty-final — открытый OPS-LAN, не успех.
- Запрошено первичное native delegate review; его успешность не предполагается.
- Новые дефекты, изменения приоритетов/решений, возвраты из review, verification и commits добавлять отдельными событиями с ID.

## 2026-10-23T23:01:37.466939+00:00 — NEW-001 added

Graphify: проверить частичное извлечение linux header и границы покрытия

Source: docs/plans/systemic-ux/graph-update.json

Release remains blocked; final verification invalidated.

## 2026-10-24T00:02:02.014390+01:00 — gate and graph verification

- Stdlib registry/gate regression checks: 13 tests passed. Missing registry, cycles, no evidence, self-verification, optimized Python and publication targets are fail-closed.
- Checks CI adjusted so an intentional release hold does not prevent normal development checks. No bypass flag added.
- Graphify code extraction completed; structured task graph initially lost may_edit links across canonical ID remapping. Re-exported merged canonical endpoints; all task relationships checked. This was a tooling correction, not a product UX fix.
- Partial linux header/unsupported extraction coverage is open NEW-001; not silently declared healthy.
- No Dart/audio/data fix, deploy, version bump, GitHub issue closure or push performed.

## 2026-10-24T00:05:20.982895+01:00 — planning checkpoint accepted

- Current registry: 32 open records, 59 tasks (34 Ornith). OPS-LAN blocked; no UX fix task closed.
- Real registry check and 13 gate tests passed; actual make -n release failed with RELEASE BLOCKED before recipes. See verification.json.
- Code + 293 registry relationships indexed, 108 dependencies checked; other semantic/label coverage remains qualified.
- Safe planning/guard/documentation files prepared for a scoped local commit; no push/tag/deploy. Commit identity is recorded by Git itself.

## 2026-10-24T00:07:21.907293+01:00 — delayed native-worker failure, OPS-LAN

- Native delegate deleg_ed32697f returned HTTP 401 (invalid/expired API key), one API call; no review output accepted.
- This is separate from the direct Studio LAN length/empty-final result. OPS-LAN remains blocked; no task closed and no automatic model/provider substitution or credential change.
- Late notification recorded without restarting remediation or altering the existing release hold.

## 2026-10-24T04:00:47.909446+01:00 — OPS-LAN restarted, OPS-LAN-20261024-040047

New user-authorised bounded experiment with adequate final budget and read-only tool access. Prior 401/empty-final failures retained; no global credentials/provider changes and no force-cancel of another active model job.

## 2026-10-24T04:07:22.462281+01:00 — OPS-LAN verified

Existing Pi studio client / exact Ornith 35b completed real read-only tool cycle, exit 0, 9.69 s, two source names independently checked. Native delegate 401 unchanged. Initial inherited-stdin launch timed out with zero events; corrected distinct probe used stdin=DEVNULL. Raw logs remain private. See verification/OPS-LAN.json.

## 2026-10-24T04:09:54.507290+01:00 — OPS-RUNNER verified

Isolated fix/systemic-ux worktree at e198a54d; offline Flutter dependencies resolved, Git state clean. Existing Pi invocation, per-task explicit tool sets, parent allowlist/diff checks and bounded timeout; not an OS sandbox. Old runner, destructive clean/checkout and automatic fallback are not used.

## 2026-10-24T04:12:27.140207+01:00 — UX-007-R verified

Ornith source review confirmed the missing tooltip. Parent corrected one invented line reference and added explicit semantics setup to the proposed regression test. No code/device execution credited to the worker. Next: RED → bounded Ornith production edit → GREEN.

## 2026-10-24T04:20:09.183988+01:00 — UX-007 root cause expanded after real failed test

The one-line tooltip edit did not satisfy rendered FAB label: full SongsListScreen file showed 19 passes and the new semantics assertion failed. Flutter Tooltip uses RawTooltip.semanticsTooltip; Icon has a separate semanticLabel. Added UX-007-S (one shared production file); UX-007-I blocked until it passes. Do not weaken the assertion or credit the issue as fixed.

## 2026-10-24T04:28:50.203871+01:00 — UX-007-I/S code verified

Ornith performed each of the two single-file production edits. Parent corrected its own test accessor/lifecycle, repeated a real 3-variant matrix (original fails; tooltip-only fails; both pass), then all 20 SongsListScreen tests passed. Analyze/format checks passed with two unchanged baseline diagnostics. Code commit d842fa36674a6a4a008ac413203bf939603c836b. Device/TalkBack and issue closure remain pending.

## 2026-10-24T03:28:58.210062+00:00 — NEW-002 added

Проверить и подписать create FAB в Setlists, Band Setlists и Rehearsals

Source: lib/screens/setlists/setlists_list_screen.dart:201; lib/screens/bands/band_setlists_screen.dart:218; lib/screens/bands/rehearsals/rehearsals_list_screen.dart:42

Release remains blocked; final verification invalidated.

## 2026-10-24T04:33:14.667045+01:00 — UX-007 slice integrated and rechecked on second01

Feature commit d842fa36674a6a4a008ac413203bf939603c836b cherry-picked as efef7ca4240751b6fe6f0208ae6b09610f39db85. Four related screen files: 47 tests passed on second01. Analyze/format checks passed with the same two baseline diagnostics; no new errors. Device/TalkBack not performed and UX-007 remains open. No bump, install, tag, push or deploy.

## 2026-10-24T04:35:19.465496+01:00 — Graphify and registry checkpoint

Current code and 310 literal activity relationships refreshed; 33 issue and 62 task nodes present, no dangling endpoints, UX-007 query checked. Five tasks verified; all 33 problems still open pending their full acceptance. Private logs remain ignored; full semantic/label extraction is still qualified by NEW-001.

## 2026-10-24T04:37:16.023189+01:00 — UX-006-R queued for bounded LAN source review

Next high-priority task uses existing Pi studio Ornith 35b, read-only, three allowlisted context files, isolated worktree, one request/process, stdin closed and 540 s hard process deadline. Result requires parent source verification; no UI edit or task closure delegated.

## 2026-10-24T04:39:11.641084+01:00 — UX-006-R worker launched

Real bounded process proc_57c99db6ccb1 / launcher PID 91566 started through uv and existing Pi studio. Streamed JSONL stays private; result.json is not acceptance. Registry remains running until parent reviews completion/failure; release hold remains active.

## 2026-10-24T04:51:08.716318+01:00 — UX-006-R timeout and parent fallback

Ornith exit 124 after 540.07 s, 11 read calls, no final; worker attempt failed and retained. No identical retry. Hermes directly verified the early-return/selector branches and existing test gap; task executor explicitly changed to parent for accepted source review. No UI edit, regression run, device check or release credited.

Scope audit: the 11 read requests include 4 unallowlisted read attempts at 2 guessed paths. This is an additional rejection reason, not accepted worker evidence; read-only tools are not a filesystem path sandbox. Failed attempt retains requested paths.

## 2026-10-24T14:45:03.684541+01:00 — UX-006-I parent preflight

Existing test/widgets/launchpad_view_test.dart:361-405 explicitly codifies missing chooser with an authenticated active MIDI fixture. Scope changed to that one relevant test, not a second test file; public MetronomeScreen seam unchanged. Separate clean worktree fix/ux006 at 63f301da avoids divergent old branch. Baseline native flutter_soloud compilation hit 180/120 s caps before test assertions; a real bounded 600 s baseline build now runs as proc_5ca025878ff8. No worker launched or RED/GREEN claimed yet.

## 2026-10-24T15:55:25.323581+01:00 — UX-006-I awaiting full orientation verification

Ornith implementation returned exit 0 in 50.62 s, exact model/provider and decoded backend manifest checked, two reads/one edit in sole production file; parent test unchanged by worker. Parent added explicit const and isolated permission fixture. Portrait flow plus existing related suite passed 16 tests. Expanded final fixture reproduced original defect in both portrait and landscape; final expanded GREEN is not yet claimed. Short build limits and a 420 s tool transport interruption delayed verification. Fixed source was recovered from recorded worker edits after interrupted baseline inspection; no baseline left in working source. Long bounded final run proc_5d473e2ade8a now active (1200 s); no main-branch code integration/release yet.

## 2026-10-24T16:10:40.566185+01:00 — final expanded suite returned GREEN; scheduled brief enabled

proc_5d473e2ade8a exited 0, All tests passed: 17 across Launchpad and drums button files, including authenticated active MIDI portrait and landscape. Code not yet integrated into primary, so UX-006-I remains review. Read-only script-only monitor d173a844e136 scheduled every 10 minutes to the origin Telegram DM; it does not execute implementation or close tasks.

## 2026-10-24T16:20:54.513718+01:00 — UX-006 code integrated, primary checks launched

Worktree code commit ba47ab143e8d5bd7e7b76823f310b3676ba9e20a cherry-picked as e6d8f26b6782fd3f3d3ce686a46a3ae396f6fcdc on second01. Exactly one production and one test file; hashes match the 17-test accepted worktree run. Primary six-file related regression now runs as proc_0a98acfc2ee0 (1800 s cap); final worktree analyze/format proc_ff17f75b994d pending. UX-006-I remains review until checks accepted. No device validation, tag, push or deploy.

## 2026-10-24T16:32:48.923938+01:00 — UX-006-I accepted on primary

Primary six-file run proc_0a98acfc2ee0 exited 0, 64 tests passed. Final worktree analyze/format/diff check proc_ff17f75b994d exited 0; three infos are located in source lines unchanged from baseline, no warnings. Accepted source/test hashes match tested worktree and e6d8f26b6782fd3f3d3ce686a46a3ae396f6fcdc. UX-006-I verified; UX-006-V explicitly blocked for fresh device recheck, not waived. All 33 issue records remain open.

## 2026-10-24T16:46:22.404789+01:00 — next bounded triage launched

NEW-002-R launched as proc_64e1fb0458b6 via existing Pi/Studio. Three explicit FAB call-site windows, at most three reads, 180 s process cap, no edits or commands; parent must inspect result before task closure and add three bounded fix/test tasks if confirmed. Periodic monitor now checks real worker PID from private process.json as well as native compiler/test processes.

## 2026-10-24T17:00:51.447516+01:00 — NEW-002-R accepted, three bounded fixes registered

Correct Ornith/Studio run, three scoped reads, source checked by parent. Spoken-label speculation and translated labels not accepted; existing English action vocabulary retained. NEW-002-I1/I2/I3 each allow one production and one test file. NEW-002-V and FINAL-TEST depend on all slices; issue not resolved.

## 2026-10-24T17:11:39.841252+01:00 — NEW-002-I1 RED launched

Parent added merged SemanticsData/tooltip assertions using existing routed setlists fixture, explicit try/finally semantics disposal. No production edit yet. Reused warm worktree under branch fix/new002; long bounded native/test run proc_136f64d6046b writes red-test.json. Successful worker triage is not counted as a UI fix.

## 2026-10-24T17:29:34.790245+01:00 — NEW-002-I1 RED confirmed and bounded edit returned

Rendered merged label was empty (expected Create Setlist), real red-test.json success=false. Ornith returned in 28.47 s, one read/one edit, exact model/provider/backend manifest, parent test unchanged. Parent diff confirms one added tooltip line only. Existing routed fixture gained label/tooltip assertions plus a no-edit permission guard check. Whole setlists test file and analyze/format now run as proc_9c2681e9389a; task remains review, no primary integration or acceptance yet.

## 2026-10-24T17:44:27.702029+01:00 — NEW-002-I1 worktree GREEN integrated; I2 RED prepared

12 worktree setlist tests passed including label/tooltip, no-edit guard and navigation; analyze/format/diff exit 0. One directive-ordering info remains in an already unsorted import block. Code 823b47dba17e807ae8e8b424c791291438f833c6 cherry-picked as 5de705cbdde2ab476b788d6db9e0121a70cf6f67. Primary replay proc_ba23aa3a455b pending, I1 remains review. Independent Band Setlists fixture now asserts the accessible name before the unchanged band-scoped navigation; I2 production code untouched.

## 2026-10-24T17:52:12.001487+01:00 — NEW-002-I1 accepted; I2 RED confirmed

Primary 12 tests pass, source/test hashes match, integrated 5de705cbdde2ab476b788d6db9e0121a70cf6f67. Accessible Create Setlist name and no-edit guard tested. I1 verified, whole NEW-002 issue remains open. Band Setlists RED confirms empty merged name against Create Band Setlist; fixture scope/navigation retained.

## 2026-10-24T17:57:10.999314+01:00 — NEW-002-I2 bounded edit and GREEN launched

Ornith returned in 23.84 s with one read/one edit, correct backend manifest and untouched parent test. Parent diff confirms only tooltip Create Band Setlist added. Existing band-scope navigation and viewer/demo cases retained. Whole Band Setlists suite plus analyze/format/diff run as proc_8d7a1d8b3263; I2 review only, not integrated.

## 2026-10-24T18:09:56.647004+01:00 — I2 worktree checks passed and integrated; I3 fixture prepared

All six Band Setlists tests pass, including band-scoped create/edit and viewer/demo guards. Analyze no issues; format/diff exit 0. Code 8a46527bb37fdba74cb440281d0e837aac93e797 cherry-picked as fafd262441f22ae7ae90fa485417eee04a91183b; primary replay proc_06091a3664dc pending. Rehearsals gains an isolated public screen fixture using existing routed harness/mock band and overridden read/permission providers, covering merged action name, band-scoped navigation and readonly UI. I3 production untouched pending RED.

## 2026-10-24T18:19:09.999887+01:00 — I2 accepted; I3 actual RED confirmed

Six primary Band Setlists tests passed; source hashes match fafd262441f22ae7ae90fa485417eee04a91183b. I2 verified, issue remains open. Rehearsals fixture compiled and readonly guard passed; proposal FAB test failed specifically for empty merged label against Propose rehearsal, not fixture/provider errors.

## 2026-10-24T18:25:33.248424+01:00 — I3 patch returned with read-budget deviation

Ornith exit 0 / 29.84 s / verified backend, one edit and two reads of the same allowed source instead of one requested read. Assertion caught the deviation; it is not reported as fully compliant. Parent inspected and retained the exact one-tooltip-line diff; test file untouched, no path expansion or retry. Task remains review pending independent GREEN/role/scope/analyze.

## 2026-10-24T18:29:01.741747+01:00 — I3 independent checks running

proc_dcdce8987aa4 runs the two-case Rehearsals fixture plus analyze/format/diff. Production/test hashes recorded. I2 accepted on primary; I3 not integrated or accepted; NEW-002 remains open and gated by V/device checks.
