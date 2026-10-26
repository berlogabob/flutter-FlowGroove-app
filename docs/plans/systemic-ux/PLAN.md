# Active activity plan — FlowGroove systemic UX/UI

Дата: 2026-10-23. Владелец приёмки: Hermes; продуктовые решения/закрытие GitHub issues: Andrew. План создан 23 октября; выполнение начато 24 октября малыми проверяемыми срезами.

## Источник истины

- [x] GH-179-TUNER-P: принят 86a6cade; свежие 79 combined tests PASS, scoped analyze exit 0 (style infos), format/diff PASS.
- [x] GH-179-TUNER-L: принят c8ca71bb; актуальные права callback и цель личной/групповой записи проверены, 105 combined tests PASS, scoped analyze/format/diff PASS.
- [x] GH-179-TUNER-L-S: принят 58be5329; экран обрабатывает отказ без ложного успеха, повторная попытка и запрет local проверены для песни/элемента. 105 combined tests PASS; analyze с одним baseline info, format/diff PASS. При unmount исправлен обнаруженный unsafe ref.read.
- [x] GH-179-TUNER-L-C: принят 0590206d; личный контекст не наследует старый bandId, explicit band и legacy/setlist сохранены. 108 combined tests PASS; scoped analyze/format/diff PASS.
- [x] **GH-179-REC-S6-P**: source preflight завершён; SharedPreferences меняет кеш до результата записи, а Undo запускает restore параллельно cancel. Это исследование, не исправление.
- [ ] **Текущий шаг — GH-179-REC-S6-Q**: RED подтверждён (2 ожидаемых отказа, 11 controls PASS); минимальная queue-правка готова, combined queue/Recorder/Song Lab проверка запущена. Далее отдельные Recorder/Song Lab/shared recovery срезы; S6 остаётся заблокированным до полной безопасности. Актуальные процессы и результаты — только в activity.json.

**activity.json — единственный текущий реестр проблем, задач, зависимостей и состояния.** Этот PLAN — правила и маршрут чтения, не второй независимый backlog. BASELINE.md фиксирует исходные 9 findings; прежние планы/аудиты остаются историей. Ничего не закрывать только по старому FINAL/галочке/коммиту.

- Исходный scope: 9 UX findings + 14 GitHub issues + 8 обязательных областей проверки.
- В процессе добавлены NEW-001 (Graphify), NEW-002 (соседние FAB) и NEW-003 (семантика readonly-card). Текущие количества и состояния читать из activity.json; GH-179 дополнен отдельными permission/security срезами.
- Исходная декомпозиция расширяется по принятым source reviews; исполнителей/фазы читать из activity.json. UX-006-R и UX-009-I2 приняты Hermes после первого timeout. Остальное — малые реализации, независимая приёмка, устройства/люди, preflight и решения владельца.
- Реальные текущие числа: `make activity-status`.
- Новая проблема, обнаруженная в процессе, входит в тот же scope сразу, а не в «после релиза».

## Release hold — решение владельца

**Нового релиза, bump, тега или публикации нет, пока остаётся хотя бы одна открытая проблема, незавершённая задача, обязательная повторная проверка или непроверенное исправление.** Никакого молчаливого deferred/waived ради зелёного gate.

Проверка `scripts/activity_plan.py gate` подключена в оба Makefile ДО рецептов/зависимостей и в release workflow ДО build/sign/publish. Пока backlog открыт, ожидается BLOCKED/ненулевой exit. Debug/local tests/build для проверки не являются публикацией; release/deploy не запускать.

Gate требует: валидный реестр и DAG, все issue resolved с resolution, все task verified с reviewer/tested commit/существующим evidence, затем свежая проверка отсутствия открытых GitHub issues. Недоступный GitHub = blocked. PASS не является поручением автоматически публиковать: решение владельца отдельное.

**Обнаруженная коллизия:** среди 14 открытых issues есть first release / Play launch. Их буквальное закрытие «после первого релиза» противоречит запрету релиза при любом open issue. Не исключать их автоматически: FINAL-OWNER требует явного решения владельца. На данный момент все остаются блокерами.

Защита — workflow/операционное правило, не защита от администратора, вручную обходящего Make/CI или меняющего gate. Прямые `firebase deploy`, `gh release`, `git tag/push` запрещены этим планом.

## Очерёдность

- [x] OPS-LAN: exact Ornith 35b runtime + реальный read tool + проверенный непустой final; verification/OPS-LAN.json. Native delegate 401 не исправлялся.
- [x] OPS-RUNNER: чистый fix/systemic-ux worktree, existing Pi с bounded tools/stdin, parent diff/allowlist/test приёмка; verification/OPS-RUNNER.json. Старый runner не запускался.
- [ ] Повторно изучить UX-001…UX-009; проверить реальные source branches и сформулировать малые acceptance tests.
- [ ] LEGACY-01 и GH-*-R: сверить все прежние local/remote открытые работы, связи/дубликаты и доказательства.
- [ ] DESIGN-01: утвердить Practice/Progress, view/Edit и global/context menu до широких nav-изменений.
- [ ] Начать с малых независимых срезов UX-006/007/009 после подтверждения; последовательно, без общего rewrite.
- [ ] Остальные UX-срезы: после -R и необходимых решений, один production file + один test за задачу.
- [ ] QA-*: безопасные копии данных, роли, editors, state/recovery, visual/a11y, платформы, audio и human tasks.
- [ ] FINAL-TEST → FINAL-DOCS → FINAL-RETEST → FINAL-OWNER. Новая проблема инвалидирует финальную приёмку.

## Текущий checkpoint — 2026-10-24

OPS-LAN verified через существующий Pi studio. Один read tool, корректный source-backed final, 9.69 s. Первый Pi timeout был запуском с inherited stdin; использовать stdin=DEVNULL. Старые неуспешные probes ниже сохраняются как история. OPS-RUNNER и UX-007-R/I/S verified; первый кодовый срез прошёл 20 screen tests, но device/TalkBack и закрытие issue остаются впереди.

## Ornith-first по LAN

Переиспользовать существующий Pi provider `studio`, endpoint `http://desktop-vdsrh2e:8888/v1`, exact model `ollama/ornith-1.5:35b`. Credentials берутся только существующим клиентом; не записывать их здесь, не менять глобальную конфигурацию Hermes/Pi ради обхода auth. Не направлять Codex на Studio.

GET /models действительно показал эту модель. Первый chat probe: actual model совпал, 51.29 s, finish_reason=length, final пустой. Это **неуспех**, записанный в worker-preflight.json. Новая, более простая проверка и корректный reasoning/output budget обязательны до выполнения кода; план не утверждает, что рабочий агент уже готов.

Все bounded code/research drafts по возможности делает Ornith. Hermes декомпозирует, даёт проверенный контекст, запускает проверки и принимает работу. Облачная подмена не автоматическая. Один Studio request/worker одновременно; независимость задач не означает параллельные генерации на одной GPU.

### Контракт одной задачи

- task ID, finding ID, родитель/зависимости и ожидаемое before → after;
- до 3 исходных контекстных файлов и короткая инструкция; обычно до ~2000 символов task prompt, без всего репозитория/переписки;
- один production file и максимум один relevant test; research output — один файл; registry/control plane пишет только Hermes;
- конкретные allowed_files и запреты: credentials, пользовательские данные, engine/auth/rules, deploy, массовый формат, новые пакеты вне scope;
- максимум 600 секунд, одна попытка; выход за scope/нехватка данных → blocked + запрос новой малой подзадачи;
- run.id, requested/actual model, log/PID, started_at, deadline_at, duration/finish reason, result path, diff и verification;
- начатая работа: status=running с run metadata; полученный результат: review; verified ставит только Hermes после независимой проверки;
- timeout/auth/empty-final/reasoning-only/выход за allowlist = failed или blocked, не «сделано»; тот же prompt не гонять повторно;
- heartbeat — реальные tool/log events, не фиктивный таймер. Нет событий до deadline/worker умер — разобраться и сохранить failure, не оставлять running навечно.

### Статусы и история

`queued → running → review → verified`; `blocked/failed → queued` только как новая явно описанная попытка после разбора причины. Зависимости должны быть verified до старта. Гипотеза -R может закончиться «не воспроизведено», но это отдельное resolution с evidence, а не механический cosmetic fix.

Worker может вернуть «готово», но не закрывает issue/task, не коммитит весь worktree и не переводит board в Done. Для verified нужны независимый reviewer, tested commit и tracked безопасный verification summary. Приватные снимки/логи остаются локально; CI не должен зависеть от наличия чужой приватной папки.

**Не переиспользовать `scripts/plan_run.py` без исправления/обхода опасных мест:** global checkout/clean, add -A, автоматический cloud fallback, вера grep/noop и недостаточный контроль реального исполнителя. Отдельный worktree не делает эти команды безопасными для смешанного рабочего дерева. Не строить новый оркестратор: начать с одного bounded Pi-запуска и приёмки.

## Добавление найденной проблемы

```sh
uv run --isolated --no-project python scripts/activity_plan.py add \
  --title 'Конкретный наблюдаемый дефект' \
  --source 'path:line или локальный evidence reference' --severity 2
```

Команда создаёт NEW-###, triage/verification tasks, дописывает HISTORY.md, расширяет финальные зависимости и сбрасывает финальное подтверждение. После triage Hermes добавляет малые fix/test задачи и реальные allowed files; нельзя закрыть задачу общим «исправить весь экран».

Перед запуском/после изменения состояния:

```sh
uv run --isolated --no-project python scripts/activity_plan.py check
make activity-status
```

Registry изменяет только один родительский процесс. Во время работы subprocess/log — локально; состояния/безопасные результаты/команды/exit codes/решения и commit IDs сохраняются в HISTORY.md и verification summaries. Не стирать прежнее evidence при повторной проверке.

## Обязательная приёмка каждого изменения

1. Убедиться, что исходный симптом воспроизводится либо явно классифицирован как гипотеза/не воспроизведён.
2. Проверить всех затронутых callers и общий источник проблемы; малый diff не оправдывает fix в неправильном месте.
3. Проверить реальный diff и allowlist, nonempty result, actual model и exit code.
4. Запустить targeted tests и analyze; для source изменения оставить минимальный regression check. Grep лишь дополнение, не доказательство поведения.
5. Device recheck исходного сценария и соседних flows на безопасных данных. Не путать автоматический проход с human task success/HEART Happiness.
6. Обновить документацию и Graphify при изменении структуры/переходов; проверить query и integrity. Pending/unindexed semantic части назвать явно.
7. Сохранить историю task → finding → checks → evidence → commit. Небольшой тематический commit только после проверки; никакого `git add -A`.

## Артефакты и безопасность

- activity.json — текущая работа; HISTORY.md — append-only события.
- BASELINE.md, TARGET-UX.md, target-wireframes.* — исходные evidence/предложения, не утверждение об исправлении.
- github-open-snapshot.json — исторический snapshot, не замена свежему GitHub read перед release.
- worker-preflight.json — результат реальной LAN проверки, включая failure.
- Полный приватный device audit — audit/2026-10-23-systemic-ux/, не коммитить raw screenshots/hierarchy/invite codes/account data.
- docs/plans/unified-workspace/ остаётся существующей untracked research-папкой: не включать её целиком в этот commit.

## Задачи (первоначальная декомпозиция, актуальный status в activity.json)

- [x] **UX-001-R** · ornith · Повторно проверить: Practice и фактическая практика разделены по разным понятиям
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/UX-001.md`.
- [ ] **UX-001-I** · ornith · Минимальное исправление/проверка решения: Practice и фактическая практика разделены по разным понятиям
  - После: UX-001-R, DESIGN-01. Scope: `lib/screens/practice_screen.dart`, `test/widgets/practice_dashboard_card_test.dart`.
- [ ] **UX-001-V** · hermes · Независимая приёмка и device recheck: UX-001
  - После: UX-001-I. Scope: проверка/решение без production edits.
- [x] **UX-002-R** · luna + independent Hermes source acceptance · Повторно проверить: Menu совмещает глобальную навигацию и контекстные команды
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/UX-002.md`.
- [ ] **UX-002-I** · ornith · Минимальное исправление/проверка решения: Menu совмещает глобальную навигацию и контекстные команды
  - После: UX-002-R, DESIGN-01. Scope: `lib/screens/main_shell.dart`, `test/screens/home_quick_actions_test.dart`.
- [ ] **UX-002-V** · hermes · Независимая приёмка и device recheck: UX-002
  - После: UX-002-I. Scope: проверка/решение без production edits.
- [x] **UX-003-R** · luna + independent Hermes caller/destination acceptance · Повторно проверить: Открытие объекта непоследовательно: песня сразу Edit, сетлист — просмотр
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/UX-003.md`.
- [ ] **UX-003-I** · ornith · Минимальное исправление/проверка решения: Открытие объекта непоследовательно: песня сразу Edit, сетлист — просмотр
  - После: UX-003-R, DESIGN-01. Scope: `lib/screens/songs/songs_list_screen.dart`, `test/screens/songs/songs_list_screen_test.dart`.
- [ ] **UX-003-V** · hermes · Независимая приёмка и device recheck: UX-003
  - После: UX-003-I. Scope: проверка/решение без production edits.
- [x] **UX-004-R** · luna + independent Hermes source acceptance · Повторно проверить: Недоступные песни видны, но причины и дальнейшее действие не объяснены
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/UX-004.md`.
- [x] **UX-004-I** · luna + parent review · Минимальное исправление/проверка решения: Недоступные песни видны, но причины и дальнейшее действие не объяснены
  - После: UX-004-R. Scope: `lib/screens/setlists/setlist_view_screen.dart`, `test/screens/setlists/setlist_view_screen_test.dart`; shared row unchanged. Integrated f0aa7414; 10 warm + 27 primary combined tests PASS. UX-004-V/device remains open.
- [ ] **UX-004-V** · hermes · Независимая приёмка и device recheck: UX-004
  - После: UX-004-I. Scope: проверка/решение без production edits.
- [x] **UX-005-R** · luna + independent Hermes source acceptance · Повторно проверить: Нет видимого единого входа для продолжения конкретного рабочего контекста
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/UX-005.md`.
- [ ] **UX-005-I** · ornith · Минимальное исправление/проверка решения: Нет видимого единого входа для продолжения конкретного рабочего контекста
  - После: UX-005-R, DESIGN-01. Scope: `lib/screens/home_screen.dart`, `test/domain/metronome_practice_features_test.dart`.
- [ ] **UX-005-V** · hermes · Независимая приёмка и device recheck: UX-005
  - После: UX-005-I. Scope: проверка/решение без production edits.
- [x] **UX-006-R** · hermes (fallback after one Ornith timeout) · Повторно проверить: При активном MIDI исчезает общий вход выбора сопровождения
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/UX-006.md`.
- [x] **UX-006-I** · ornith · Минимальное исправление/проверка решения: При активном MIDI исчезает общий вход выбора сопровождения
  - После: UX-006-R. Scope: `lib/screens/metronome_screen.dart`, `test/widgets/launchpad_view_test.dart`.
- [ ] **UX-006-V** · hermes · Независимая приёмка и device recheck: UX-006
  - После: UX-006-I. Scope: проверка/решение без production edits.
- [x] **UX-007-R** · ornith · Повторно проверить: У кнопки создания песни отсутствует явное имя в текущей иерархии
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/UX-007.md`.
- [x] **UX-007-I** · ornith · Минимальное исправление/проверка решения: У кнопки создания песни отсутствует явное имя в текущей иерархии
  - После: UX-007-R. Scope: `lib/screens/songs/songs_list_screen.dart`, `test/screens/songs/songs_list_screen_test.dart`.
- [ ] **UX-007-V** · hermes · Независимая приёмка и device recheck: UX-007
  - После: UX-007-I. Scope: проверка/решение без production edits.
- [x] **UX-008-R** · luna + independent Hermes source acceptance · Повторно проверить: Микротекст вне общей шкалы требует отдельной проверки читаемости
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/UX-008.md`.
- [ ] **UX-008-I** · ornith · Минимальное исправление/проверка решения: Микротекст вне общей шкалы требует отдельной проверки читаемости
  - После: UX-008-R. Scope: `lib/widgets/tuner/transport_bar.dart`, `test/widgets/tuner/central_dial_geometry_test.dart`.
- [ ] **UX-008-V** · hermes · Независимая приёмка и device recheck: UX-008
  - После: UX-008-I. Scope: проверка/решение без production edits.
- [x] **UX-009-R** · ornith · Повторно проверить: Загрузка и ошибка в Practice могут выглядеть как отсутствие пользовательских данных
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/UX-009.md`.
- [x] **UX-009-I** · luna + parent corrections · PracticeScreen independent loading/error/retry and truthful song-title states
  - После: UX-009-R, UX-009-I2. Scope: `lib/screens/practice_screen.dart`, `test/screens/practice_screen_test.dart`. Integrated b7fa6542; 22 primary related tests PASS. UX-009-V/device and issue closure remain open.
- [ ] **UX-009-V** · hermes · Независимая приёмка и device recheck: UX-009
  - После: UX-009-I. Scope: проверка/решение без production edits.
- [x] **GH-189-R** · luna + independent Hermes source acceptance · Event deep links and analytics; partial stream deviations retained, not device/GA4 acceptance.
  - Scope: `reviews/GH-189.md`, `verification/GH-189-R.json`; exact source identity checked against 13e054c0. Remote issue OPEN.
- [x] **GH-189-A0** · centralized event-sharing names only; integrated af6be538, primary analyzer/format/diff PASS. No instrumentation/GA4 credit.
- [x] **GH-189-A1** · Hermes direct fallback after retained Luna admission failure · Parameterless consent-safe methods; integrated `dcccc355`, 27 targeted / 33 consent-combined tests PASS. Exact SDK transport names/null payload, consent-off suppression and nonfatal SDK errors checked; no caller/device/GA4 credit.
- [x] **GH-189-A2** · Luna draft + Hermes direct completion · Successful create/copy instrumentation integrated `75b3d59d`; 21 primary targeted / 90 combined visible tests PASS, scoped analyze/format/diff/security checks PASS. Explicit service/clipboard failures, guest/no-access, consent-off and nonfatal analytics failure covered. Original incomplete worker attempt/partial stream retained, no replay. No device/GA4 or issue-closure credit.
- [x] **GH-189-A3** · Luna draft + Hermes direct completion. Integrated `23ac5256`: successful token-backed opens once per mounted screen and successful token/direct-owner suggestions, consent-safe/null payloads. Parent final six-file combined regression **84 PASS**, actual suggestion mutation RED/GREEN, final scoped analyze (5 infos)/format and byte restoration checked. Device/GA4 and issue closure remain open.
- [x] **GH-189-L0** · independent source preflight accepted with parent corrections; ten source identities checked, legacy hash contract and association gaps recorded. Not device/signing/ownership acceptance.
- [ ] **GH-189-L1/L2/L3/L4** · URL compatibility → Android → iOS/Hosting configuration. Blocked on deliberate native URL policy, signing identity and actual source/output mapping; no deployment.
- [ ] **GH-189-V** · integrated permission/privacy/legacy regressions + actual Android/iOS opening and GA4 Realtime. Added to FINAL-TEST dependencies; no release waiver.
- [x] **GH-188-R** · luna + independent Hermes source acceptance · GitHub #188: per-person access ticks UI
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/GH-188.md`. Source-only; missing controls confirmed; issue stays OPEN.
- [x] **GH-188-I** · Luna draft + Hermes direct completion · Integrated `3c193749`: five per-person hidden/view/edit controls and effective live preview; identity/notes, cancel, role-reset and preset isolation preserved. Independently parsed 26 warm / 51 primary combined tests PASS, scoped analyze/format passed. Device gate GH-188-V remains open.
- [ ] **GH-188-V** · hermes · Independent source/test/primary integration + safe device/permission recheck; gates FINAL-TEST.
- [x] **GH-187-R** · Hermes direct fallback after retained Luna admission failure · Source review accepted; inbox/guest status exist, Accept does not apply typed changes; initial loading/error hidden. No product/device acceptance.
  - Evidence: `reviews/GH-187.md`, `verification/GH-187-R.json`. Issue OPEN, original failed attempt preserved.
- [x] **GH-187-P** · independently accepted typed contract; duplicate/break identity, atomic/stale/replay and legacy decision-only semantics fixed. Source contract only, not a product fix. I1 backend → S submission → E authorized view → C transport → U structured UI → I2 compatibility/presentation gate; all registered under GH-187, V/final gates retained.
- [x] **GH-187-I1** · atomic typed add/remove/reorder backend integrated `6a514349`; controller corrections preserve authority/privacy and legacy decisions. 79 warm / 87 primary callable+security tests PASS; original incomplete Luna attempt retained.
- [x] **GH-187-S** · typed proposal submission integrated `6321d0c6`; real public callable RED, final 88 primary callable/security tests PASS; rejected schema/targets consume no quota, both scopes persist proposals without execution. Device/client/issue acceptance remains open.
- [x] **GH-187-E** · authorized running-order identities/base integrated `df4c4c39`; independent public callable RED, 82 warm / 90 primary combined tests PASS. Permission omission, legacy unready and private-field filtering checked; original incomplete Luna attempt retained.
- [x] **GH-187-C** · client transport integrated `73057d2f`: typed payload forwarding and scoped running-order base; 44 primary combined tests PASS. Existing rendered fake signature corrected; no UI/device acceptance.
- [x] **GH-187-U1** · Luna draft + Hermes direct completion · Remove/reorder public UI integrated `deb989e9`; 57 primary combined tests PASS, rendered RED/GREEN and small-viewport overflow correction verified. Duplicate occurrences numbered, break IDs preserved, notes/analytics/scope/cancel/errors retained. No device or whole-U credit.
- [x] **GH-187-U2-R** · independent source review accepted; candidate publication requires owner policy; not a product fix.
- [ ] **GH-187-U2/U/I2** · Named safe add-selection research → implementation remains explicit privacy gate; U2 scoped candidates/authorized selection unresolved. U is aggregate only; I2 retains structured presentation/legacy checks; no free-text execution or device acceptance.
- [x] **GH-187-I3** · inbox loading/error/retry through existing public widget/test pair; cached requests/roles/scope preserved. Integrated `37490537`; 11 warm / 54 primary combined tests PASS. Original Luna lease-loss failure retained, controller completed directly. GH-187-V/device remains open.
- [ ] **GH-187-V** · fresh combined regression and safe device/guest round trip; gates FINAL-TEST.
- [x] **GH-186-R** · luna + independent Hermes source acceptance · Missing inventory confirmed; required export/writer/pagination/URL gates registered. Source review only.
- [x] **GH-186-B** · Luna draft + Hermes direct completion · Authorized metadata inventory/export integrated `8cfa0698`; 87 warm / 95 primary callable+security tests PASS. Original 32-turn incomplete worker retained; no client/UI/device credit.
- [x] **GH-186-C** · Hermes direct fallback after reconciled incomplete Luna terminal · Typed immutable metadata pages integrated `546d2b39`; public runtime/date RED and final 67 primary combined tests PASS; scoped analyzer has 20 infos/no warnings/errors, format/diff PASS. No UI/device credit.
- [x] **GH-186-U** · Luna draft + Hermes direct completion · Writer-only paged inventory and isolated confirmed revoke integrated `6f85d62f`; 63 primary combined tests PASS, scoped analyze/format/diff PASS. Original lease-loss attempt retained, no replay.
- [ ] **GH-186-URL/V** · URL waits GH-189-L1; combined/device final gate retained.
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/GH-186.md`.
- [ ] **GH-180-R** · ornith · Повторная проверка GitHub #180: [epic] Event participants: scoped event sharing for non-members
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/GH-180.md`.
- [x] **GH-179-R** · Luna + независимая приёмка Hermes · Source review прав принят; исправлены рекомендации по lazy migration, author-delete/Undo и тестовым identities. Evidence: `verification/GH-179-R.json`; это не исправление продукта.
  - [ ] **GH-179-LAB** — aggregate remains open: screen slice accepted separately, shared recording authority/cancellation awaits GH-179-REC-R/I.
  - [x] **GH-179-LAB-S1** — screen-owned task/entry/version gates and current-permission callbacks; integrated `ba1c8a45`, 22 Song Lab / 40 combined tests PASS. No full LAB/audio/device acceptance.
  - [x] **GH-179-REC-R** — independent source contract accepted; corrected demo-claim and queue-race recommendations. Research only, no audio fix credit.
  - [x] **GH-179-REC-S1A** — Recorder personal action/identity entry guards, post-selection link and live Undo; integrated `5ff203e0`, 45 combined tests PASS (14 Recorder), scoped analyzer no warnings/errors. Original Luna baseline-only attempt retained; Hermes direct completion.
  - [x] **GH-179-REC-S1B** — Recorder pending-delete cancellation after revocation/unmount and failed document deletion; integrated `860448eb`, 48 primary combined tests PASS, scoped analyzer/format/diff PASS. Original incomplete Luna attempt retained; Hermes completion. Shared queue/audio/device acceptance remains open.
  - [x] **GH-179-REC-S4** — Song Lab failed-delete cancels queued audio and reports safe retry; integrated `3faa61f8`, 54 related tests PASS, scoped analyzer no warnings/errors and format/diff PASS. Existing revocation/unmount guards covered as controls, not newly repaired defects. Prior admission failure retained; Hermes completion.
  - [x] **GH-179-REC-S5** — sweep rechecks cancellation and preserves concurrent enqueue by reusing flush; integrated `5034cc89`, parent actual baseline RED and 56 combined tests PASS; analyzer one info/no warnings/errors, format/diff PASS. Not durable cancellation/device acceptance.
  - [ ] **GH-179-REC-S1/S2/S3/S6 → REC-I** — S1 aggregate retains A+B; shared identity/authority → conservative save reconciliation; REC-S6 explicitly retains cancellation persistence false/throw/restart safety. Audio/device acceptance remains open. Status/leases in activity.json.
  - [x] **GH-179-AUDIO-R** — independently accepted CODE-only Storage/Firestore identity and async-boundary review; exact four-source identities and original terminal checked. No production fix or deployed-policy credit; AUDIO-I still requires approved policy. Evidence: `verification/GH-179-AUDIO-R.json`.
  - [x] **GH-179-TUNER-R** — Hermes source fallback после подтверждённого terminal исходного Luna: квота HTTP 429, затем незапрошенный runtime fallback и connection failure; результат подменной модели не принят. Только CODE review, не исправление продукта. Evidence: `verification/GH-179-TUNER-R.json`.
  - [x] **GH-179-TUNER-E** — редактор: доступные synced scopes и live/stale Save authority, local сохранён. b7ad107a; combined 64 PASS, analyze exit 0 (10 infos), format/diff PASS. Устройство и фактическая синхронизация не проверены.
  - [ ] **GH-179-TUNER-P/L → TUNER-I** — общий notifier → live-authorized привязка. Public provider baseline запущен, транспортный fixture ещё требует preflight; gate V/FINAL-TEST сохранён. Luna не перезапускается при нездоровом маршруте.
  - [ ] **GH-179-AUDIO-I, VOTE, AVATAR, DEMO-R, LEGACY-R, DELETE-OWNER, V** — все остаточные срезы и решения зарегистрированы в activity.json; V блокирует FINAL-TEST. Никакого закрытия issue по одному UI fix.
- [ ] **GH-178-R** · ornith · Повторная проверка GitHub #178: refactor(metronome): extract live setlist/song sync out of MetronomeNotifier
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/GH-178.md`.
- [ ] **GH-177-R** · ornith · Повторная проверка GitHub #177: Graph-audit remediation 2026-08 (trackable, measurable)
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/GH-177.md`.
- [ ] **GH-151-R** · ornith · Повторная проверка GitHub #151: iOS metronome: PCM feeder starvation — dropped beats up to 118s silence on older hardware + audio/animation desync
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/GH-151.md`.
- [ ] **GH-77-R** · ornith · Повторная проверка GitHub #77: Remote MCP connector — one-click OAuth (Claude/ChatGPT)
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/GH-77.md`.
- [ ] **GH-50-R** · ornith · Повторная проверка GitHub #50: Play Console: org account + first release
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/GH-50.md`.
- [ ] **GH-49-R** · ornith · Повторная проверка GitHub #49: Play Console: store listing assets
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/GH-49.md`.
- [ ] **GH-48-R** · ornith · Повторная проверка GitHub #48: Play Console: App Content forms
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/GH-48.md`.
- [ ] **GH-42-R** · ornith · Повторная проверка GitHub #42: 🚀 Google Play Store launch
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/GH-42.md`.
- [ ] **QA-DRUMS-V** · hermes · Расширенная проверка: Drums grid/editor и MIDI note editor
  - После: DESIGN-01. Scope: проверка/решение без production edits.
- [ ] **QA-SONG-V** · hermes · Расширенная проверка: Song arrangement и create/edit/cancel
  - После: DESIGN-01. Scope: проверка/решение без production edits.
- [ ] **QA-EVENT-V** · hermes · Расширенная проверка: Event Kit, sharing и роли viewer/member/admin
  - После: DESIGN-01. Scope: проверка/решение без production edits.
- [ ] **QA-STATE-V** · hermes · Расширенная проверка: Offline, loading/error/partial, permission denial
  - После: DESIGN-01. Scope: проверка/решение без production edits.
- [ ] **QA-VISUAL-V** · hermes · Расширенная проверка: Mono Pulse: light/dark, large text, TalkBack
  - После: DESIGN-01. Scope: проверка/решение без production edits.
- [ ] **QA-PLATFORM-V** · hermes · Расширенная проверка: P30/A24, landscape, web и iOS risk matrix
  - После: DESIGN-01. Scope: проверка/решение без production edits.
- [ ] **QA-AUDIO-V** · hermes · Расширенная проверка: MIDI/click, loop/speed/count-in, screen off и route changes
  - После: DESIGN-01. Scope: проверка/решение без production edits.
- [ ] **QA-HUMAN-V** · hermes · Расширенная проверка: Human task testing: navigation, context/resume и setlist recovery
  - После: DESIGN-01. Scope: проверка/решение без production edits.
- [x] **OPS-LAN** · hermes · Подтвердить рабочий Ornith 35b final/tool cycle по LAN
  - После: нет. Scope: проверка/решение без production edits.
- [x] **OPS-RUNNER** · hermes · Подготовить безопасный запуск существующего Pi клиента
  - После: OPS-LAN. Scope: проверка/решение без production edits.
- [ ] **LEGACY-01** · ornith · Сверить незакрытые локальные планы и статусные утверждения
  - После: OPS-LAN, OPS-RUNNER. Scope: `docs/plans/systemic-ux/reviews/LEGACY-01.md`.
- [ ] **DESIGN-01** · owner+hermes · Утвердить UX-контракты и первый тонкий срез
  - После: UX-001-R, UX-002-R, UX-003-R, UX-005-R. Scope: проверка/решение без production edits.
- [ ] **FINAL-TEST** · hermes · Полная свежая регрессия исправленного кода
  - После: UX-001-V, UX-002-V, UX-003-V, UX-004-V, UX-005-V, UX-006-V, UX-007-V, UX-008-V, UX-009-V, QA-DRUMS-V, QA-SONG-V, QA-EVENT-V, QA-STATE-V, QA-VISUAL-V, QA-PLATFORM-V, QA-AUDIO-V, QA-HUMAN-V. Scope: проверка/решение без production edits.
- [ ] **FINAL-DOCS** · hermes · Обновить документацию, Graphify и историю по фактическому коду
  - После: FINAL-TEST, LEGACY-01. Scope: проверка/решение без production edits.
- [ ] **FINAL-RETEST** · hermes · Повторный независимый UX/UI проход после всех исправлений
  - После: FINAL-DOCS. Scope: проверка/решение без production edits.
- [ ] **FINAL-OWNER** · owner · Разрешение владельца после нулевого открытого backlog
  - После: FINAL-RETEST. Scope: проверка/решение без production edits.

## Добавлено во время настройки

- [ ] NEW-001-R · Ornith: классифицировать предупреждение Graphify на linux header, без автоматической правки приложения.
- [ ] NEW-001-V · Hermes: подтвердить покрытие/ограничение и безопасное resolution после triage.

Регистрация выполнена реальной командой add; финальные зависимости расширены, история дописана, release остаётся BLOCKED.

- [x] UX-007-S · Ornith: SingleFab Icon semanticLabel из tooltip. Добавлено после реального RED, который не исправился одним tooltip; UX-007-I зависит от этого среза.

## UX-007 implementation checkpoint

Code commit d842fa36674a6a4a008ac413203bf939603c836b in fix/systemic-ux: caller tooltip + shared Icon semanticLabel. Parent corrected the test to merged SemanticsData and in-body handle disposal, then confirmed original RED / tooltip-only RED / both GREEN. All 20 SongsListScreen tests pass; analyzer has only the same two baseline findings, format unchanged. UX-007-V remains open for fresh device/TalkBack, so the issue and release hold are NOT closed.

- [ ] NEW-002-R/V · Соседние create FAB: Setlists, Band Setlists, Rehearsals. Создано реальной командой add по свежему чтению callers; не объявлены исправленными этим срезом.

Primary branch checkpoint: efef7ca4 passed 47 tests across four related screen files, plus analyze/format. UX-006-R completed via parent source fallback after one 540 s Ornith timeout; no UI implementation or device verification credited. No fresh device/TalkBack verification or release.

UX-006-R: worker exit 124/no final preserved in attempt_history; parent source review verified, see reviews/UX-006.md. Next UX-006-I requires an authenticated active-MIDI regression fixture before production edits.

UX-006-I complete: authenticated public launchpad regression covers portrait/landscape; Ornith production edit and parent tests/const cleanup accepted on primary. See verification/UX-006-I.json.

UX-006-I accepted on second01 e6d8f26b: 64 primary related tests passed (including the 17 target cases), final analyze/format exit 0. UX-006-V is blocked pending fresh installed-device recheck; issue remains open and release held.

## NEW-002 bounded fix slices

- [x] **NEW-002-I1** · ornith · Подписать create FAB в Setlists. Scope: `lib/screens/setlists/setlists_list_screen.dart`, `test/screens/setlists/setlists_list_screen_test.dart`. After NEW-002-R.
- [x] **NEW-002-I2** · ornith · Подписать create FAB в Band Setlists. Scope: `lib/screens/bands/band_setlists_screen.dart`, `test/screens/bands/band_setlists_screen_test.dart`. After NEW-002-R.
- [x] **NEW-002-I3** · ornith · Подписать create FAB в Rehearsals. Scope: `lib/screens/bands/rehearsals/rehearsals_list_screen.dart`, `test/screens/bands/rehearsals/rehearsals_list_screen_test.dart`. After NEW-002-R.

All three slices gate NEW-002-V and FINAL-TEST; device acceptance remains separate.

## UX-009 additional shared caller slice

- [x] **UX-009-I2** — Home/Practice shared DashboardCard loading/error vs true empty week; one production file + existing card tests. Must pass before PracticeScreen slice; all dependencies are recorded in activity.json.

## NEW-003 — readonly stats-card semantics

- [x] **NEW-003-R** — separate accessible label from visible copy; source confirmed.
- [x] **NEW-003-I** — one shared-card production file plus existing test, after UX-009-I2; preserve disabled navigation.
- [ ] **NEW-003-V** — independent tests and fresh device/screen-reader evidence.

## Parallel Luna lane — authorized 2026-10-24

- [x] Real Luna request through Hermes CLI; Pi OAuth route failed 401 and was not silently substituted.
- [x] Independent fix/luna-ux worktree and project-only context; no global provider/delegation or personal-memory changes.
- [x] UX-002-R draft produced in 35.040 s, only assigned report written; parent acceptance pending.
- [x] Resume same Luna session for UX-008-R; controller remains sole registry/integration writer.
- [ ] Measure accepted code throughput with coherent slices and batch integration checks, not additional agent counts.

See PARALLEL-LANES.md for revised verification/checkpoint cadence; release hold is unchanged.

## Continuous queue control — authorized 2026-10-24

- [x] User requires no unattended idle while executable tasks remain.
- [x] Native recurring supervisor 748ba92c74d8 configured every 3m; cheap admission script skips LLM while no action is due.
- [x] Admission fixtures exercise busy, ready, pending review, missing PID, expired run, unmet dependencies and manual blocker.
- [x] Preserve disconnected gateway leases: missing CLI PID is not model completion; reconcile server-side outcome before redispatch.
- [x] First controller cycle accepted UX-002-R; next accepted UX-008-R and reconciled terminal UX-009-I. Source-review acceptances are not product-fix counts.

Status-only job d173a844e136 remains every 10m. Controller owns registry/dispatch/acceptance; foreground honors file leases. Limits: one Luna and one controlled test lane; no unauthorized cleanup, global config changes or release.
