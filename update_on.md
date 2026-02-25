### Расширенный бриф для реализации фич в RepSync

Этот расширенный бриф основан на суммированной переписке: фокус на добавлении календарь-пикера, системе тегов ролей (baseTags, memberRoles, assignments), фиксе бага добавления песни, тегах для песен (с облаком), использовании тегов для экспорта сетлистов. Учитывая стек (Flutter 3+, Riverpod 2+, Hive, Firestore), offline-first, user-centric дизайн.

**Общие цели проекта**:
- Улучшить UX для музыкантов: Валидные даты, гибкие роли/теги для сборных концертов, поиск/сортировка песен, экспорт списков участников.
- Обеспечить синхронизацию: Hive для оффлайн, Firestore для коллаборации (real-time snapshots в providers).
- Минимизировать зависимости: Только textfield_tags для тегов (если не хватит встроенных виджетов).
- Тестирование: Unit (Riverpod notifiers), integration (Hive/Firestore sync), UI (manual на эмуляторе).
- Риски: Конфликты синка (решить via lastUpdated timestamp); производительность при большом tag cloud (ограничить scan до 100 песен).
- Метрики успеха: Нет крашей в добавлении/экспорте; теги/роли сохраняются оффлайн; экспорт PDF с полным списком участников.
- Общий timeline: 8-10 дней (спринты по 1-2 дня), ежедневные commits в GitHub. После — ревью в issues.

**Структура спринтов**: Каждый спринт — MVP с тестами. Добавлены подзадачи, зависимости, выходные артефакты. В конце каждого — однострочные TODO (как чеклист для быстрого трекинга).

#### Спринт 1: Фикс бага добавления песни в банду (1 день)
- **Цели**: Устранить зависание loader, добавить обработку ошибок/timeout, интегрировать с Riverpod для async states.
- **Подзадачи**:
  - Обновить BandNotifier: Метод addSong с AsyncValue (loading/error/data), Hive put + Firestore update.arrayUnion с timeout(10s).
  - В band_screen.dart: ref.watch(bandProvider).when() для UI (loader: CircularProgressIndicator, error: Snackbar с 'Ошибка: $e').
  - Добавить логи (debugPrint) для отладки оффлайн/онлайн.
  - Тесты: Unit на notifier (mock service), manual добавление песни.
- **Зависимости**: Нет.
- **Выход**: Функциональное добавление без hangs; PR в repo.
- **Однострочные TODO**:
  - Добавить timeout в Firestore call.
  - Обработать AsyncError в UI.
  - Тест оффлайн-добавления.
  - Commit фикса.

#### Спринт 2: Календарь-пикер для даты сетлиста (1 день)
- **Цели**: Заменить ручной ввод на пикер, хранить дату как DateTime/Timestamp, интегрировать в Setlist model/provider.
- **Подзадачи**:
  - В models/setlist.dart: Поле DateTime date; обновить adapters/toMap.
  - В providers/setlist_provider.dart: StateNotifier с updateDate, инициализация из existing setlist.
  - В setlist_edit_screen.dart: ListTile с onTap: showDatePicker, ref.read для обновления + default DateTime.now().
  - Синк: Hive (DateTime), Firestore (Timestamp.fromDate).
  - Тесты: Валидация (no null dates), UI клик на пикер.
- **Зависимости**: Встроенные виджеты (showDatePicker).
- **Выход**: Дата выбирается только через пикер; обновлённый экран в app.
- **Однострочные TODO**:
  - Добавить DateTime в модель.
  - Реализовать пикер в UI.
  - Синк в Hive/Firestore.
  - Тест дефолт-даты.

#### Спринт 3: Система тегов ролей пользователей (baseTags в профиле) (1-2 дня)
- **Цели**: Внедрить базовые теги в профиль, с CRUD и pull в другие сущности; обеспечить автозаполнение ролей.
- **Подзадачи**:
  - В models/user_profile.dart: List<String> baseTags; обновить сериализацию.
  - В providers/user_provider.dart: UserNotifier с loadProfile (Hive/Firestore), addTag/removeTag (update state + save).
  - В profile_screen.dart: Wrap с FilterChip (onSelected: remove), ElevatedButton "+" с AlertDialog/TextField для add.
  - Интеграция: В BandNotifier — при addMember default из baseTags.
  - Тесты: Unit на notifier (add/remove), integration sync тегов.
- **Зависимости**: Опционально textfield_tags ^3.0 (pub add если нужно).
- **Выход**: Теги в профиле сохраняются/отображаются; автозаполнение в банде.
- **Однострочные TODO**:
  - Добавить baseTags в модель.
  - Создать notifier методы.
  - UI для чипов/ввода.
  - Тест автозаполнения.
  - Синк тегов.

#### Спринт 4: Роли в бандах/сетлистах и overrides для концертов (2 дня)
- **Цели**: Добавить роли в группы, overrides в сетлисты для гостей/тональности; генерировать список участников.
- **Подзадачи**:
  - В models/band.dart: Map<String, List<String>> memberRoles.
  - В models/setlist.dart: Map<String, Map<String, String>> assignments; метод getParticipants() (compute unique users/roles).
  - В providers: Методы updateRole в BandNotifier, addAssignment в SetlistNotifier.
  - UI: В band_edit — FilterChip multi-select из baseTags + custom; в setlist_edit — ExpansionTile с ListTile/ PopupMenuButton для overrides (роль + тональность).
  - Тесты: Manual на сборный концерт (гость-вокалист), unit на getParticipants.
- **Зависимости**: Нет.
- **Выход**: Роли сохраняются; overrides в UI; список участников генерируется.
- **Однострочные TODO**:
  - Добавить memberRoles в band.
  - Assignments в setlist.
  - UI dropdown/chips.
  - Метод getParticipants.
  - Тест overrides.
  - Синк ролей.

#### Спринт 5: Теги для песен и облако тегов (1-2 дня)
- **Цели**: Arbitrary теги для песен, поддержка CSV, поиск/сортировка; аггрегация в tag cloud.
- **Подзадачи**:
  - В models/song.dart: List<String> tags.
  - В providers/song_provider.dart: SongNotifier с add/removeTag.
  - В song_edit_screen.dart: TextFieldTags (пакет) с initialTags, onTag/onDelete callbacks.
  - В user_service.dart: getTagCloud() — scan songs, return Map<String, int> (frequency).
  - UI: В song_list/search — SearchBar с фильтром по tags; profile/search — Wrap с ChoiceChip (size по frequency).
  - Импорт: В csv_service — parse 'tags' column as split(',').
  - Тесты: Импорт CSV без ошибок, поиск по тегу.
- **Зависимости**: textfield_tags (pub add).
- **Выход**: Теги добавляются/ищутся; cloud отображается.
- **Однострочные TODO**:
  - Добавить tags в song.
  - UI TextFieldTags.
  - Метод getTagCloud.
  - Фильтр в SearchBar.
  - Тест CSV import.
  - Синк тегов.

#### Спринт 6: Интеграция тегов для подготовки сетлиста (1 день)
- **Цели**: Экспорт полного списка (участники + песни) для площадки; использовать теги/роли.
- **Подзадачи**:
  - В setlist_provider: Интегрировать getParticipants с тегами/ролями из user/band/song.
  - В export_service (PDF/CSV): Добавить таблицу "Участники" (user, roles, songs) перед песнями; использовать pdf пакет.
  - UI: Кнопка экспорта в setlist_screen, с опцией "Включить участников".
  - Тесты: Генерация PDF для тестового сетлиста с гостями.
- **Зависимости**: Существующий pdf пакет.
- **Выход**: Экспорт с тегами/ролями; полный для концертов.
- **Однострочные TODO**:
  - Интегрировать getParticipants.
  - Добавить секцию в PDF.
  - Кнопка экспорта.
  - Тест PDF генерации.

**Пост-спринт**: Рефакторинг (если нужно), full app тесты, deploy to test device. Если фичи растянутся, приоритизируй: Багфикс > Дата > Теги ролей > Теги песен > Экспорт.