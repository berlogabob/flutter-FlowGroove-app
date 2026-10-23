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
