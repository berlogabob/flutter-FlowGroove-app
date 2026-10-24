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
