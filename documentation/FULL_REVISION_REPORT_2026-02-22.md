# ОТЧЕТ О ПОЛНОЙ РЕВИЗИИ ПРОЕКТА
**Flutter RepSync App**

---

**Дата:** 2026-02-22  
**Версия:** 0.10.0+1  
**Статус:** ТРЕБУЕТСЯ ВНИМАНИЕ  
**Агентов задействовано:** 10 (параллельно)  
**Время ревизии:** ~90 минут  

---

# СОДЕРЖАНИЕ

1. [Краткое резюме](#1-краткое-резюме)
2. [Метрики качества кода](#2-метрики-качества-кода)
3. [Архитектурная оценка](#3-архитектурная-оценка)
4. [UX/UI аудит](#4-uxui-аудит)
5. [Тестирование и покрытие](#5-тестирование-и-покрытие)
6. [Приоритетные задачи](#6-приоритетные-задачи)
7. [План действий](#7-план-действий)

---

# 1. КРАТКОЕ РЕЗЮМЕ

## Общая оценка проекта

| Категория | Оценка | Статус |
|-----------|--------|--------|
| **Качество кода** | 7/10 | ✅ Удовлетворительно |
| **Архитектура** | 6/10 | ⚠️ Требует работы |
| **UX/UI** | 6/10 | ⚠️ Несогласованно |
| **Тесты** | 4/10 | 🔴 Критично |
| **Документация** | 8/10 | ✅ Хорошо |
| **ОБЩАЯ** | **62/100** | ⚠️ **ТРЕБУЕТ ВНИМАНИЯ** |

## Ключевые проблемы

### 🔴 Критические (требуют немедленного решения)
1. **10 ошибок компиляции** в `metronome_preset.dart` (const с DateTime)
2. **Мобильный аудио движок отсутствует** (пустая заглушка)
3. **122 теста не проходят** (23.4% failure rate)
4. **Покрытие тестами 39.8%** при цели 80%
5. **Сервисы без тестов** (Spotify, MusicBrainz, Metronome, PDF)

### 🟠 Высокий приоритет
1. **13 предупреждений** (unused imports, dead code)
2. **85 info-level проблем** (const constructors, print statements)
3. **Нет error handling стратегии** (silent failures)
4. **Нет offline-first** (прямые Firestore stream без кэша)
5. **MetronomeService использует ChangeNotifier** вместо Riverpod

### 🟡 Средний приоритет
1. **UX несогласованности** (15 критических)
2. **Большие файлы** (6 файлов >350 строк)
3. **Нет password recovery** в аутентификации
4. **Сложный UI метронома** (технические элементы управления)
5. **Скрытый экспорт PDF** (неочевидный для пользователей)

---

# 2. МЕТРИКИ КАЧЕСТВА КОДА

## Статистика анализа

| Метрика | Количество | Цель | Статус |
|---------|------------|------|--------|
| **Ошибки** | 10 | 0 | 🔴 Критично |
| **Предупреждения** | 13 | 0 | 🟠 Высокий |
| **Info-level** | 85 | <10 | 🟡 Средний |
| **Всего проблем** | 108 | 0 | 🔴 Требуется действие |
| **Проблемы форматирования** | 12 файлов | 0 | 🟡 Средний |

## Критические ошибки по файлам

| Файл | Ошибки | Проблема |
|------|--------|----------|
| `lib/models/metronome_preset.dart` | 7 | `const` с `DateTime` (не const) |
| `scripts/fix_all_bands.dart` | 2 | Отсутствует импортируемый файл |

## Предупреждения по категориям

| Категория | Количество | Файлы |
|-----------|------------|-------|
| Unused imports | 5 | metronome_preset.dart, metronome_widget.dart, test files |
| Unused variables | 4 | test files (mockFirestore) |
| Dead code | 4 | metronome_widget.dart, register_screen_test.dart |

## Файлы требующие форматирования (12)

```
lib/models/subdivision_type.dart
lib/models/time_signature.dart
lib/screens/home_screen.dart
lib/screens/profile_screen.dart
lib/services/audio_engine*.dart
lib/services/metronome_service.dart
lib/widgets/*.dart (5 файлов)
```

---

# 3. АРХИТЕКТУРНАЯ ОЦЕНКА

## Общая оценка архитектуры

| Аспект | Оценка | Комментарий |
|--------|--------|-------------|
| **Разделение ответственности** | 6/10 | Смешанные concerns в data_providers.dart |
| **State Management** | 6/10 | Inconsistent (Riverpod + ChangeNotifier) |
| **Структура файлов** | 7/10 | Хорошая, но нужна реорганизация |
| **Тестируемость** | 5/10 | Низкая из-за耦合 |
| **Масштабируемость** | 5/10 | Потребует рефакторинга |

## Проблемные файлы

| Файл | Строк | Проблема | Решение |
|------|-------|----------|---------|
| `lib/providers/data_providers.dart` | 294 | God file (сервис + провайдеры) | Выделить FirestoreService |
| `lib/widgets/metronome_widget.dart` | 458 | Слишком большой виджет | Разделить на под-виджеты |
| `lib/screens/songs/add_song_screen.dart` | 494 | Логика формы в UI | Вынести в контроллер |
| `lib/screens/songs/songs_list_screen.dart` | 409 | Фильтрация в screen | Переместить в провайдер |

## Архитектурные анти-паттерны

1. **Service Locator** — MetronomeService как singleton вместо Riverpod
2. **God Provider** — data_providers.dart содержит сервис и 10+ провайдеров
3. **Navigation Coupling** — прямые `Navigator.pushNamed` везде
4. **Silent Failures** — сервисы ловят ошибки без уведомления UI
5. **Missing Offline-First** — нет локального кэша (Hive/Isar)

## Рекомендации по архитектуре

### Приоритет 1 (Критично)
1. Мигрировать MetronomeService на Riverpod NotifierProvider
2. Реализовать mobile audio engine (audioplayers)
3. Выделить FirestoreService из data_providers.dart
4. Внедрить стратегию обработки ошибок

### Приоритет 2 (Высокий)
5. Реализовать локальное кэширование (Hive/Isar)
6. Рефакторинг больших файлов (>400 строк)
7. Разделить MetronomeWidget на компоненты
8. Внедрить go_router для навигации

---

# 4. UX/UI АУДИТ

## Оценка пользовательских сценариев

| Сценарий | Статус | Проблемы | Серьезность |
|----------|--------|----------|-------------|
| **Логин/Регистрация** | ⚠️ Частично | 4 проблемы | Высокая |
| **Создание группы** | ✅ Завершено | 3 проблемы | Средняя |
| **Добавление песни** | ⚠️ Частично | 6 проблем | Высокая |
| **Создание сетлиста** | ⚠️ Частично | 5 проблем | Высокая |
| **Метроном** | ⚠️ Частично | 8 проблем | Критично |

## Критические UX проблемы

| ID | Проблема | Влияние | Решение |
|----|----------|---------|---------|
| UX-001 | Нет восстановления пароля | 🔴 Critical | Добавить ссылку "Forgot Password?" |
| UX-002 | Требования к паролю после ошибки | 🟠 High | Показать требования до отправки |
| UX-003 | Экспорт PDF скрыт | 🔴 Critical | Добавить кнопку на карточке сетлиста |
| UX-004 | Нет объяснений BPM/Key | 🟠 High | Добавить tooltip с пояснениями |
| UX-005 | Метроном слишком технический | 🔴 Critical | Скрыть Hz за "Advanced Settings" |
| UX-006 | Invite code не показан | 🟠 High | Показать сразу с кнопкой "Copy" |
| UX-007 | Кнопка "+ Group" вместо "Band" | 🟡 Medium | Унифицировать терминологию |
| UX-008 | Поиск Spotify внизу формы | 🟠 High | Переместить к полям title/artist |
| UX-009 | Accent pattern "ABBB" непонятен | 🔴 Critical | Использовать визуальные toggle |
| UX-010 | Time signature dropdowns | 🟠 High | Использовать preset кнопки (4/4, 3/4) |

## Предложения Creative Director (ожидают подтверждения)

| ID | Предложение | Усилия | Влияние | Статус |
|----|-------------|--------|---------|--------|
| UX-001 | Унифицировать кнопку Save (внизу) | Low | High | ⏳ Pending |
| UX-002 | Добавить undo после удаления | Medium | High | ⏳ Pending |
| UX-003 | Dialog несохраненных изменений | Medium | Medium | ⏳ Pending |
| UX-004 | Guided onboarding для новых | High | High | ⏳ Pending |
| UX-010 | Интеграция метронома с песнями | Medium | High | ⏳ Pending |

---

# 5. ТЕСТИРОВАНИЕ И ПОКРЫТИЕ

## Статистика тестов

| Метрика | Значение |
|---------|----------|
| **Всего тестов** | 521 |
| **Проходят** | 399 (76.6%) |
| **Не проходят** | 122 (23.4%) |
| **Пропущено** | 0 |

## Покрытие по компонентам

| Компонент | Покрытие | Цель | Разрыв | Статус |
|-----------|----------|------|--------|--------|
| Models | 88.2% | 90% | -1.8% | 🟡 Почти цель |
| Providers | 17.5% | 85% | -67.5% | 🔴 Критично |
| Services | 0.0% | 80% | -80.0% | 🔴 Критично |
| Widgets | 49.7% | 75% | -25.3% | 🔴 Критично |
| Screens | 40.1% | 70% | -29.9% | 🔴 Критично |
| Theme | 0.0% | 50% | -50.0% | 🔴 Критично |
| **ОБЩЕЕ** | **39.8%** | **80%** | **-40.2%** | 🔴 **Критично** |

## Проблемы с тестами

### 122 failing tests breakdown:
- `auth_integration_test.dart`: 19 — mockito "Cannot call when within stub"
- `api_integration_test.dart`: 5 — MockHttpClient возвращает null
- `custom_text_field_test.dart`: 6 — Отсутствует Material widget ancestor
- `error_banner_test.dart`: 1 — Retry button not found
- `confirmation_dialog_test.dart`: 1 — Multiple Confirm buttons found

### Сервисы без тестов (344 строки кода)
- `spotify_service.dart` — 85 строк, 0% coverage
- `musicbrainz_service.dart` — 47 строк, 0% coverage
- `track_analysis_service.dart` — 27 строк, 0% coverage
- `metronome_service.dart` — 80 строк, 0% coverage
- `pdf_service.dart` — 0% coverage
- `audio_engine*.dart` — 0% coverage

---

# 6. ПРИОРИТЕТНЫЕ ЗАДАЧИ

## Приоритет 1 (Критично — выполнить за 48 часов)

| № | Задача | Агент | Время | Статус |
|---|--------|-------|-------|--------|
| 1.1 | Исправить 10 ошибок компиляции (metronome_preset.dart) | MrSeniorDeveloper | 30 мин | ⏳ Ожидает |
| 1.2 | Исправить mobile audio engine (audioplayers) | MrSeniorDeveloper + Architect | 60 мин | ⏳ Ожидает |
| 1.3 | Исправить 122 failing tests | MrTester | 90 мин | ⏳ Ожидает |
| 1.4 | Удалить unused imports и dead code | MrCleaner | 30 мин | ⏳ Ожидает |

## Приоритет 2 (Высокий — выполнить за неделю)

| № | Задача | Агент | Время | Статус |
|---|--------|-------|-------|--------|
| 2.1 | Мигрировать MetronomeService на Riverpod | MrSeniorDeveloper | 60 мин | ⏳ Ожидает |
| 2.2 | Выделить FirestoreService из data_providers | MrSeniorDeveloper | 45 мин | ⏳ Ожидает |
| 2.3 | Внедрить error handling стратегию | MrArchitect + Developer | 90 мин | ⏳ Ожидает |
| 2.4 | Добавить локальное кэширование (Hive) | MrArchitect + Developer | 120 мин | ⏳ Ожидает |
| 2.5 | Исправить 13 предупреждений | MrCleaner | 30 мин | ⏳ Ожидает |

## Приоритет 3 (Средний — выполнить за 2 недели)

| № | Задача | Агент | Время | Статус |
|---|--------|-------|-------|--------|
| 3.1 | Рефакторинг metronome_widget.dart (458 строк) | MrSeniorDeveloper | 90 мин | ⏳ Ожидает |
| 3.2 | Рефакторинг add_song_screen.dart (494 строки) | MrSeniorDeveloper | 90 мин | ⏳ Ожидает |
| 3.3 | Добавить тесты для сервисов (344 строки) | MrTester | 180 мин | ⏳ Ожидает |
| 3.4 | Исправить UX-001, UX-002, UX-003, UX-006 | MrUXUIDesigner | 60 мин | ⏳ Pending Approval |
| 3.5 | Упростить UI метронома (скрыть Hz) | CreativeDirector + UXAgent | 60 мин | ⏳ Pending Approval |

## Приоритет 4 (Низкий — выполнить за месяц)

| № | Задача | Агент | Время | Статус |
|---|--------|-------|-------|--------|
| 4.1 | Внедрить go_router для навигации | MrSeniorDeveloper | 120 мин | ⏳ Ожидает |
| 4.2 | Добавить json_serializable | MrRepetitive | 60 мин | ⏳ Ожидает |
| 4.3 | Реорганизовать /lib/providers/ | MrCleaner + Architect | 90 мин | ⏳ Ожидает |
| 4.4 | Реорганизовать /lib/services/ | MrCleaner + Architect | 90 мин | ⏳ Ожидает |
| 4.5 | Достичь 80% покрытия тестами | MrTester | 300 мин | ⏳ Ожидает |

---

# 7. ПЛАН ДЕЙСТВИЙ

## Фаза 1: Критические исправления (48 часов)

```
День 1 (2 часа):
├─ 09:00-09:30 — MrCleaner: Исправить 10 ошибок компиляции
├─ 09:30-10:30 — MrSeniorDeveloper + Architect: Mobile audio engine
├─ 10:30-12:00 — MrTester: Исправить 122 failing tests
└─ 12:00-12:30 — MrCleaner: Удалить unused imports/dead code

День 2 (1.5 часа):
├─ 09:00-10:00 — MrSeniorDeveloper: Миграция MetronomeService на Riverpod
├─ 10:00-10:45 — MrSeniorDeveloper: Выделение FirestoreService
├─ 10:45-12:00 — MrArchitect + Developer: Error handling стратегия
└─ 12:00-12:30 — MrSync: Проверка Quality Gate 1
```

**Quality Gate 1:**
- ✅ 0 ошибок компиляции
- ✅ 0 предупреждений
- ✅ Все тесты проходят
- ✅ Mobile audio работает

## Фаза 2: Улучшение архитектуры (1 неделя)

```
День 3-4:
├─ Локальное кэширование (Hive/Isar)
├─ Рефакторинг больших файлов
└─ Разделение MetronomeWidget

День 5-7:
├─ Тесты для сервисов (344 строки)
├─ Исправление UX проблем (P0)
└─ Интеграция метронома с песнями
```

**Quality Gate 2:**
- ✅ Покрытие тестами ≥60%
- ✅ Все сервисы протестированы
- ✅ UX P0 проблемы исправлены

## Фаза 3: Стабилизация (2 недели)

```
Неделя 2:
├─ go_router навигация
├─ json_serializable
├─ Реорганизация директорий
└─ Документация (README, CHANGELOG)

Неделя 3:
├─ Достичь 80% покрытия
├─ Интеграционные тесты
└─ Подготовка релиза v0.10.1+1
```

**Quality Gate 3:**
- ✅ Покрытие тестами ≥80%
- ✅ 0 известных багов P0/P1
- ✅ Документация обновлена
- ✅ Релиз v0.10.1+1 готов

---

# ПРИЛОЖЕНИЕ A. Агенты задействованные в ревизии

| Агент | Выполнено | Время | Документы |
|-------|-----------|-------|-----------|
| **MrPlanner** | ✅ План ревизии | 30 мин | REVISION_PLAN_2026-02-22.md |
| **CreativeDirector** | ✅ UX Patterns Audit | 45 мин | UX_PATTERNS_AUDIT_2026-02-22.md + 15 proposals |
| **MrUXUIDesigner** | ✅ Design Review | 45 мин | Вклад в UX audit |
| **MrStupidUser** | ✅ User Testing | 90 мин | USER_TESTING_REPORT_2026-02-22.md + 10 bug reports |
| **MrCleaner** | ✅ Code Quality Audit | 45 мин | 108 issues identified |
| **MrArchitector** | ✅ Architecture Review | 45 мин | ARCHITECTURE_REVIEW_2026-02-22.md |
| **MrTester** | ✅ Coverage Analysis | 60 мин | TEST_COVERAGE_ANALYSIS_20260222.md |
| **MrSeniorDeveloper** | ✅ Code Review | 45 мин | Вклад в architecture review |
| **MrSync** | ✅ Координация | 60 мин | Обновление ToDo.md |
| **MrLogger** | ✅ Логирование | 30 мин | /log/20260222.md |

---

# ПРИЛОЖЕНИЕ Б. Созданные документы

| Документ | Расположение | Размер |
|----------|--------------|--------|
| **Revision Plan** | `/documentation/REVISION_PLAN_2026-02-22.md` | ~5 KB |
| **UX Patterns Audit** | `/documentation/proposals/UX_PATTERNS_AUDIT_2026-02-22.md` | ~15 KB |
| **User Testing Report** | `/documentation/proposals/USER_TESTING_REPORT_2026-02-22.md` | ~12 KB |
| **Architecture Review** | `/documentation/ARCHITECTURE_REVIEW_2026-02-22.md` | ~20 KB |
| **Test Coverage Analysis** | `/coverage/TEST_COVERAGE_ANALYSIS_20260222.md` | ~10 KB |
| **Code Quality Audit** | `/documentation/CODE_QUALITY_AUDIT_2026-02-22.md` | ~8 KB |
| **Session Log** | `/log/20260222.md` | ~5 KB |
| **Updated ToDo.md** | `/documentation/ToDo.md` | ~3 KB |

---

# ПРИЛОЖЕНИЕ В. Quality Gates Checklist

## Gate 1: Critical Fixes (День 2)
- [ ] 0 compilation errors
- [ ] 0 warnings
- [ ] All tests passing (521/521)
- [ ] Mobile audio functional

## Gate 2: Architecture (День 7)
- [ ] MetronomeService migrated to Riverpod
- [ ] FirestoreService extracted
- [ ] Error handling implemented
- [ ] Local caching (Hive) working
- [ ] Test coverage ≥60%

## Gate 3: Stabilization (День 14)
- [ ] go_router implemented
- [ ] json_serializable added
- [ ] Directories reorganized
- [ ] Test coverage ≥80%
- [ ] Documentation updated

## Gate 4: Release Ready (День 21)
- [ ] All P0/P1 bugs fixed
- [ ] UX proposals approved & implemented
- [ ] Integration tests passing
- [ ] README + CHANGELOG updated
- [ ] Release v0.10.1+1 tagged

---

**Отчет подготовлен:** MrSync (координация) + все агенты  
**Дата завершения:** 2026-02-22 15:30  
**Следующий шаг:** Ожидание подтверждения пользователя для начала Фазы 1

---

**СТАТУС:** ⏳ **ОЖИДАЕТ ПОДТВЕРЖДЕНИЯ ПОЛЬЗОВАТЕЛЯ**

Для начала выполнения Фазы 1 (Критические исправления) требуется ваше подтверждение:
- ✅ **Approve Phase 1** — Начать исправление критических проблем
- ⏸️ **Hold** — Требуется обсуждение приоритетов
- ❌ **Reject** — Отложить ревизию
