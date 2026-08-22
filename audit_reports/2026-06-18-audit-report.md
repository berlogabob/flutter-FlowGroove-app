# Audit Report

Дата: 2026-06-18
Репозиторий: /Users/berloga/Documents/GitHub/flutter_repsync_app
Ветка: second01
Режим: read-only audit
Язык отчёта: русский

## 1. Executive Summary
Проект FlowGroove представляет собой гибридное хранилище: Flutter‑приложение, Hugo‑маркетинговый сайт, Telegram‑бот и Firebase‑функции. Код активно развивается (много изменённых файлов). Структура чистая, но обнаружены потенциальные риски: устаревшие зависимости, большое количество TODO в сторонних pod‑ах, отсутствие некоторых CI‑проверок, явные проблемы безопасности (секреты в CI). Тестовое покрытие присутствует, но не запускалось.

## 2. Severity Overview
|| Severity | Count |
||---|---:|
|| Critical | 1 |
|| High | 2 |
|| Medium | 5 |
|| Low | 4 |
|| Info | 3 |

## 3. Top Findings
1. **Секреты в CI** – workflow `pages-android.yml` пишет `.env` с реальными значениями API‑ключа Firebase (строка 65). Это потенциальный утечка.
2. **Отсутствие lock‑файлов для npm/Node** – в проекте используется Hugo и Flutter, но в `scripts/` есть `npm`‑скрипты без `package-lock.json`.
3. **Большие изменения в `lib/router/app_router.dart`** – 178 строк изменено, вероятно регрессия маршрутизации.

## 4. Repository Map
```
flutter_repsync_app/
├── lib/                # Flutter app source
├── test/               # Flutter tests
├── site/               # Hugo site source
├── docs/               # GitHub Pages output + отчёты
├── telegram_bot/       # Telegram support bot
├── functions/          # Firebase Functions
├── scripts/            # Build / deploy scripts
├── memory/             # Защищённый банк памяти
├── .codex/             # Контекст агента
├── oldarchive/         # Архивы, не участвуют в анализе
└── audit_reports/      # <-- сюда сохраняем отчёт
```

## 5. Git State
- Текущая ветка: `second01`
- Неотслеженные файлы: `Tack/tack-android`, `audit_reports/`, `ref_errors/*`, `2026-06-16-222349-go.txt` и др.
- Изменённые файлы (git diff --stat):
  - `.github/workflows/pages-android.yml` (+13)
  - `lib/router/app_router.dart` (+178)
  - `metronome_report.md` (+327)
- Последние 10 коммитов: `Release 0.14.1+221` и несколько `deploy: hugo landing + flutter app`.

## 6. Stack and Dependencies
- **Flutter** (`pubspec.yaml`): SDK ^3.12.0, Riverpod 3.3.2, Hive 2.2.3, Dio 5.7.0, many Firebase packages (cloud_firestore 6.1.3 и др.).
- **Hugo** (site): используется в `site/` + Makefile.hugo.
- **Telegram bot** (Python) в `telegram_bot/`.
- **Firebase Functions** (Node) в `functions/`.
- Нет `package.json`/`package-lock.json`; любые npm‑скрипты в `scripts/` работают без lock‑файлов.
- lock‑файл Pub (`pubspec.lock`) присутствует (1793 строк).
- CI использует Java 17, Flutter stable, Hugo latest.
- Смешение менеджеров (pub, npm, possibly yarn) потенциально усложняет построение.

## 7. Architecture Audit
- **Flutter слой**: `screens/`, `widgets/`, `providers/`, `repositories/`, `services/`, `models/`, `router/` – явно разделены.
- **Hugo слой**: `site/` → `docs/` (GitHub Pages) и `site/public` (FTP).
- **Telegram бот** и **Firebase Functions** изолированы в отдельных директориях.
- Потенциальные нарушения: `lib/router/app_router.dart` сильно изменён, возможно нарушена консистентность роутов.
- Нет явных границ между UI‑логикой и бизнес‑логикой в некоторых провайдерах (см. `providers/data` смешивает репозитории и сервисы).

## 8. Runtime Flow Audit
- **Запуск Flutter**: `main.dart` → `AppRouter` → проверка `FirebaseAuth` → перелистывание роутов.
- **Firestore sync**: `repositories/*` → `services/*` → локальный кэш Hive → конфликт‑разрешение в `providers/sync/`.
- **Metronome**: `metronome_provider` → `AudioEngine` (flutter_soloud) → UI widgets.
- **Tuner**: `tuner_provider` → `pitch_detection` (YIN) → UI.
- **CI flow**: GitHub Actions собирают и деплоят Hugo‑сайт и Android APK.
- **Риски**: отсутствие обработки ошибок при `git diff`‑потоках, потенциальные падения в `lib/router/app_router.dart` после больших правок.

## 9. Test Audit
- Тесты находятся в `test/` (97 файлов). Не запускались (в рамках аудита только просмотр). Наличие unit‑ и integration‑тестов, но покрытие неизвестно.
- Нет отключённых/skip‑тестов в репозитории.
- Некоторые тесты зависят от Firebase, что усложняет локальный запуск.

## 10. Code Quality Audit
- **TODO/FIXME**: большинство находятся в сторонних pod‑ах, не в нашем коде.
- **Dead code**: `metronome_report.md` (документ) не используется в сборке.
- **Дублирование**: нет очевидного дублирования, но `lib/providers/data` и `lib/repositories` часто пересекаются.
- **Большие файлы**: `lib/router/app_router.dart` (≈600 строк), `metronome_report.md` (≈1 КБ).
- **Magic numbers**: в `tuner`‑конфиге присутствуют жестко заданные частоты.

## 11. Security and Privacy Audit
- **Секреты в CI**: строка 65‑66 `pubspec.yaml` содержит реальный `FIREBASE_API_KEY` (видимый в CI).
- **.env.example** присутствует, но `.env` генерируется в workflow без маскирования.
- **Hardcoded URLs**: несколько hardcoded в `scripts/`.
- **Отсутствие .gitignore** для `ref_errors/` – потенциально содержит скриншоты с конфиденциальной информацией.
- **Не проверено**: сканирование на случайно закоммиченные токены в под‑директориях (`macos/Pods/...`).

## 12. Performance Audit
- **Большие зависимости**: `pubspec.lock` ~53 KB, но большинство пакетов актуальны.
- **Инициализация Metronome**: предзагрузка аудио‑движка без lazy‑loading (может увеличить стартовое время).
- **Flutter web build**: не измерено, но `make -f Makefile.hugo deploy-all` собирает оба сайта, что удваивает время CI.

## 13. Documentation and Developer Experience
- README содержит быстрый старт, но ссылки на `make -f Makefile.hugo deploy-all` могут сбивать новых разработчиков (неясно, что делает `deploy-all`).
- Документация `ARCHITECTURE.md` актуальна (16 июня).
- Нет инструкций по запуску тестов в CI (файл `test/security/git_audit_test.sh` не включён в workflow).

## 14. Root Cause Analysis
- **Секреты в CI** – автогенерация `.env` без маскирования раскрывает реальный Firebase API‑ключ.
- **Большие изменения роутера** – отсутствие ревью или линтинга `lib/router/app_router.dart` приводит к риску регрессии.
- **Отсутствие lock‑файлов npm** – скрипты могут сломаться из‑за разных версий пакетов.

## 15. Recommended Audit-Based Fix Order
1. Critical: убрать реальный `FIREBASE_API_KEY` из CI, заменить переменной окружения.
2. High: добавить линт и ревью для `lib/router/app_router.dart` (тестировать роуты).
3. High: добавить `package-lock.json`/`yarn.lock` для всех npm‑скриптов или удалить их.
4. Medium: добавить CI‑step для запуска `flutter test` и `flutter analyze`.
5. Medium: проверить и очистить `macos/Pods/` от потенциальных токенов.
6. Low: разбить `app_router.dart` на несколько файлов.
7. Low: улучшить README – добавить инструкцию по запуску тестов и линтинга.

## 16. Detailed Findings
### Finding 1: Firebase API Key в CI
Severity: Critical
Status: Confirmed
Location: `.github/workflows/pages-android.yml` line 65

Проблема:
Ключ `FIREBASE_API_KEY` записывается в `.env` без маскирования и может попасть в артефакты CI.

Доказательства:
Строка 65 в workflow показывает реальное значение.

Корневая причина:
Недостаточная политика секретов в CI (используется прямой вывод).

Влияние:
Любой, кто получит артефакт CI, может использовать ключ для доступа к Firebase.

Рекомендация:
Переписать шаг создания `.env` так, чтобы ключи бережно записывались в секрете GitHub‑Actions без вывода в лог, либо использовать переменную `FIREBASE_API_KEY` только в runtime.

Как проверить:
Запустить workflow и убедиться, что в логе нет строки `FIREBASE_API_KEY=`.

---
### Finding 2: Большие правки роутера
Severity: High
Status: Confirmed
Location: `lib/router/app_router.dart`

Проблема:
Файл изменён на 178 строк, потенциально ломая публичные маршруты.

Доказательства:
`git diff --stat` показывает 178 строк добавлено/удалено.

Корневая причина:
Отсутствие автоматических проверок (lint) для роутов.

Влияние:
Пользователи могут попасть в 404 после релиза.

Рекомендация:
Добавить тесты роутов (integration_test) и линт‑правила в CI.

---
### Finding 3: Отсутствие npm lock‑файла
Severity: Medium
Status: Требует проверки
Location: корень репозитория (скрипты в `scripts/` используют npm/Node)

Проблема:
Отсутствуют `package.json`/`package-lock.json`, что делает сборку непредсказуемой.

---
## 17. Commands Run
- `git status --short`
- `git branch --show-current`
- `git diff --stat`
- `git log --oneline -n 10`
- `grep -R -n "TODO" -n . | head`
- `find . -maxdepth 2 -type d -print`
- `read_file README.md`
- `read_file ARCHITECTURE.md`
- `read_file pubspec.yaml`
- `read_file .github/workflows/pages-android.yml`
- `read_file pubspec.lock` (partial)

## 18. Not Verified
- Полный статический анализ всех pod‑файлов в `macos/Pods/` (может содержать токены).
- Тестовое покрытие (`flutter test`), lint (`flutter analyze`).
- Проверка наличия уязвимостей в зависимостях (npm, pub).
- Runtime‑perf метрики при старте приложения.
