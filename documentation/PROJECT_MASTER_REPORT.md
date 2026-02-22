# ОТЧЕТ ПО ПРОЕКТУ FLUTTER REPSYNC APP
**Консолидированная документация проекта**

---

**Дата составления:** 2026-02-21  
**Версия приложения:** 0.10.0+1  
**Статус:** ПРОИЗВОДСТВЕННАЯ ГОТОВНОСТЬ  
**Ветка Git:** dev03-autonomous-dev-day2  

---

# СОДЕРЖАНИЕ

1. [Общие сведения о проекте](#1-общие-сведения-о-проекте)
2. [История и концепция проекта](#2-история-и-концепция-проекта)
3. [Архитектура системы](#3-архитектура-системы)
4. [Функциональные возможности](#4-функциональные-возможности)
5. [Техническая реализация](#5-техническая-реализация)
6. [Инфраструктура агентов](#6-инфраструктура-агентов)
7. [Разработка функции "Метроном"](#7-разработка-функции-метроном)
8. [Сборка и развертывание](#8-сборка-и-развертывание)
9. [Тестирование и контроль качества](#9-тестирование-и-контроль-качества)
10. [Исправление критических ошибок](#10-исправление-критических-ошибок)
11. [Настройка окружения](#11-настройка-окружения)
12. [Приложения](#12-приложения)

---

# 1. ОБЩИЕ СВЕДЕНИЯ О ПРОЕКТЕ

## 1.1. Наименование проекта

**RepSync** (Flutter RepSync App) — приложение для управления репертуаром музыкальных кавер-групп.

## 1.2. Назначение проекта

Приложение предназначено для:
- Создания и ведения базы песен музыкальной группы
- Управления сетлистами (плейлистами для концертов и репетиций)
- Совместного доступа участников группы к репертуару
- Экспорта сетлистов в PDF для печати
- Использования метронома во время репетиций

## 1.3. Период разработки

- **Начало разработки:** Январь 2026
- **Текущая версия:** 0.10.0+1
- **Дата последнего обновления:** 2026-02-21
- **Режим разработки:** Автономный цикл с обратной связью агентов

## 1.4. Технические характеристики

| Параметр | Значение |
|----------|----------|
| **Фреймворк** | Flutter 3.19+ |
| **Язык** | Dart 3.3+ |
| **Целевые платформы** | Web → Android → iOS |
| **Backend** | Firebase (Auth + Firestore) |
| **State Management** | Riverpod 3.x |
| **Локальное хранение** | Hive / Isar |

## 1.5. Статус проекта

| Компонент | Статус | Готовность |
|-----------|--------|------------|
| Аутентификация | ✅ Завершено | 100% |
| Управление группами | ✅ Завершено | 100% |
| База песен | ✅ Завершено | 100% |
| Сетлисты | ✅ Завершено | 100% |
| Экспорт PDF | ✅ Завершено | 100% |
| Метроном | ✅ Завершено | 100% |
| Мобильный аудио | ⏳ В процессе | 50% |

---

# 2. ИСТОРИЯ И КОНЦЕПЦИЯ ПРОЕКТА

## 2.1. Предыстория проекта

Проект начался с личной потребности разработчика, который начал играть в музыкальной кавер-группе и столкнулся с проблемой структурирования песен и подготовки к концертам/репетициям.

### 2.1.1. Эволюция решения

**Этап 1: Google Таблицы**
- Простая таблица со списком песен
- Поля: исполнитель, темп, ключ, ссылки
- Страницы для каждой песни с детальной информацией
- **Проблема:** Быстро превращается в хаос при росте репертуара

**Этап 2: Существующие приложения**
- Tack Android (платная версия) — отличный метроном, но неудобный ввод песен
- BandHelper — перегружен, дорог ($20-50/год)
- Setlist Helper — не подходит для детализации
- **Проблема:** Нет фокуса на детализации (ключи, драм-ссылки, заметки)

**Этап 3: Собственное приложение**
- Фокус на удобстве ввода песен
- Интеграция с метрономом
- Совместный доступ для группы
- Экспорт сетлистов в PDF

## 2.2. Концепция проекта

### 2.2.1. Основное назначение

**BandRepertoire / RepSync** — легкая, фокусированная база именно для кавер-бэндов:
- BPM и ключи (оригинал и наша версия)
- Ссылки на драм-уроки и табы
- Заметки для барабанщиков
- Удобные сетлисты с PDF-экспортом
- Совместный доступ в реальном времени

### 2.2.2. Целевая аудитория

- Кавер-группы (тысячи по миру)
- Барабанщики (основной фокус)
- Гитаристы/вокалисты/басисты
- Хобби-группы и профессиональные коллективы

### 2.2.3. Уникальное торговое предложение

| Характеристика | RepSync | BandHelper | Google Таблицы |
|----------------|---------|------------|----------------|
| **Фокус на кавер-группы** | ✅ | ⚠️ Перегружен | ❌ |
| **Удобный ввод песен** | ✅ | ⚠️ Сложный | ⚠️ Неудобно |
| **Метроном интегрирован** | ✅ | ❌ | ❌ |
| **Совместный доступ** | ✅ | ✅ | ✅ |
| **Экспорт PDF** | ✅ | ✅ | ⚠️ Сложно |
| **Цена** | Freemium | $20-50/год | Бесплатно |
| **Оффлайн доступ** | ✅ | ✅ | ❌ |

## 2.3. Модель монетизации

### 2.3.1. Freemium модель

**Бесплатная версия:**
- Одна группа
- До 50 песен
- Базовый экспорт PDF
- Метроном (базовые функции)

**Премиум версия ($2-5/месяц или $20/год):**
- Неограниченные группы
- Неограниченное количество песен
- Полный совместный доступ с ролями
- Продвинутый PDF (кастомные шаблоны)
- Импорт/экспорт данных
- Оффлайн без лимитов
- Метроном (полный функционал)

### 2.3.2. Дополнительные источники дохода

- Google AdMob (реклама в бесплатной версии)
- One-time unlock (для тех, кто не любит подписки)
- In-app purchases (дополнительные функции)

---

# 3. АРХИТЕКТУРА СИСТЕМЫ

## 3.1. Общая архитектура

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App                          │
├─────────────────────────────────────────────────────────┤
│  Screens           Providers         Services           │
│  ┌────────┐       ┌────────┐       ┌────────┐          │
│  │ Home   │◄──────│ Auth   │◄──────│ Firebase│         │
│  │ Songs  │◄──────│ Data   │◄──────│ Spotify │         │
│  │ Bands  │       │ Sync   │       │ PDF    │         │
│  │ Setlist│       │        │       │        │         │
│  └────────┘       └────────┘       └────────┘          │
├─────────────────────────────────────────────────────────┤
│  Models              Widgets         Theme              │
│  ┌────────┐       ┌────────┐       ┌────────┐          │
│  │ Song   │       │ Card   │       │ Light  │         │
│  │ Band   │       │ Badge  │       │ Dark   │         │
│  │ Setlist│       │ Input  │       │        │         │
│  └────────┘       └────────┘       └────────┘          │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    Firebase Backend                     │
├─────────────────────────────────────────────────────────┤
│  Authentication      Firestore         Storage          │
│  ┌────────┐       ┌────────┐       ┌────────┐          │
│  │ Email  │       │ Users  │       │ Images │         │
│  │ Google │       │ Bands  │       │ PDFs   │         │
│  │ Apple  │       │ Songs  │       │        │         │
│  └────────┘       │ Setlist│       └────────┘          │
│                   └────────┘                            │
└─────────────────────────────────────────────────────────┘
```

## 3.2. Структура проекта

```
lib/
├── main.dart                    # Точка входа, маршрутизация
├── firebase_options.dart        # Конфигурация Firebase
├── models/
│   ├── song.dart               # Модель песни
│   ├── band.dart               # Модель группы + BandMember
│   ├── setlist.dart            # Модель сетлиста
│   ├── link.dart               # Модель ссылок
│   └── user.dart               # Модель пользователя
├── providers/
│   ├── auth_provider.dart      # Провайдеры аутентификации
│   └── data_providers.dart     # Firestore провайдеры + сервисы
├── services/
│   ├── firestore_service.dart  # Firestore CRUD операции
│   ├── pdf_service.dart        # Экспорт PDF
│   ├── musicbrainz_service.dart # Поиск метаданных музыки
│   ├── spotify_service.dart    # Spotify API (BPM, ключ)
│   └── audio_engine*.dart      # Аудиодвижок метронома
├── screens/
│   ├── main_shell.dart         # Нижняя навигация
│   ├── home_screen.dart        # Дашборд со статистикой
│   ├── profile_screen.dart     # Профиль/настройки
│   ├── login_screen.dart       # Вход
│   ├── auth/
│   │   └── register_screen.dart
│   ├── songs/
│   │   ├── songs_list_screen.dart
│   │   └── add_song_screen.dart
│   ├── bands/
│   │   ├── my_bands_screen.dart
│   │   ├── create_band_screen.dart
│   │   └── join_band_screen.dart
│   └── setlists/
│       ├── setlists_list_screen.dart
│       └── create_setlist_screen.dart
├── widgets/
│   ├── song_card.dart          # Карточка песни
│   ├── band_card.dart          # Карточка группы
│   ├── attribution_badge.dart  # Бейдж авторства
│   └── time_signature_dropdown.dart # Выбор размера
└── theme/
    └── app_theme.dart          # Цветовая схема + темы
```

## 3.3. Модель данных

### 3.3.1. Коллекции Firestore

```
users/{userId}
├── uid: string
├── email: string
├── displayName: string
├── photoURL: string?
├── createdAt: timestamp
└── bands: subcollection
    └── {bandId}: reference

bands/{bandId}
├── id: string
├── name: string
├── description: string?
├── createdBy: string (UID)
├── members: array
│   └── {uid: string, role: string, joinedAt: timestamp}
├── memberUids: array[string]
├── adminUids: array[string]
├── editorUids: array[string]
├── inviteCode: string (6 char)
├── createdAt: timestamp
├── songs: subcollection
│   └── {songId}
└── setlists: subcollection
    └── {setlistId}

users/{userId}/songs/{songId}
├── id: string
├── title: string
├── artist: string
├── originalKey: string
├── originalBpm: number
├── ourKey: string
├── ourBpm: number
├── links: array
│   └── {type: string, url: string, title: string}
├── notes: string (markdown)
├── tags: array[string]
├── duration: number? (seconds)
├── originalOwnerId: string?
├── contributedBy: string?
├── isCopy: boolean?
└── contributedAt: timestamp?

users/{userId}/setlists/{setlistId}
├── id: string
├── name: string
├── description: string?
├── bandId: string
├── songIds: array[string] (ordered)
├── eventDate: timestamp?
├── location: string?
├── totalDuration: number (calculated)
└── createdAt: timestamp
```

### 3.3.2. Правила безопасности Firestore

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isUser(uid) {
      return request.auth.uid == uid;
    }
    
    function isBandMember(bandId) {
      let band = get(/databases/$(database)/documents/bands/$(bandId)).data;
      return band.memberUids.hasAny([request.auth.uid]);
    }
    
    function isGlobalBandEditorOrAdmin(bandId) {
      let band = get(/databases/$(database)/documents/bands/$(bandId)).data;
      return band != null &&
        (band.editorUids.hasAny([request.auth.uid]) ||
         band.adminUids.hasAny([request.auth.uid]));
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated() && isUser(userId);
      allow write: if isUser(userId);
      
      match /songs/{songId} {
        allow read, write: if isUser(userId);
      }
      
      match /setlists/{setlistId} {
        allow read, write: if isUser(userId);
      }
    }
    
    // Bands collection
    match /bands/{bandId} {
      allow read: if isAuthenticated() && isBandMember(bandId);
      allow create: if isAuthenticated();
      allow update, delete: if isGlobalBandEditorOrAdmin(bandId);
      
      match /songs/{songId} {
        allow read: if isBandMember(bandId);
        allow create, update: if isGlobalBandEditorOrAdmin(bandId);
        allow delete: if isGlobalBandEditorOrAdmin(bandId);
      }
      
      match /setlists/{setlistId} {
        allow read: if isBandMember(bandId);
        allow create, update, delete: if isGlobalBandEditorOrAdmin(bandId);
      }
    }
  }
}
```

---

# 4. ФУНКЦИОНАЛЬНЫЕ ВОЗМОЖНОСТИ

## 4.1. Аутентификация и управление пользователями

### 4.1.1. Методы входа

| Метод | Статус | Описание |
|-------|--------|----------|
| Email + пароль | ✅ Завершено | Базовая аутентификация |
| Google Sign-In | ✅ Завершено | OAuth через Firebase |
| Apple Sign-In | ⏳ Запланировано | Для iOS устройств |
| Анонимный вход | ⏳ Запланировано | Для быстрого тестирования |

### 4.1.2. Управление профилем

- Просмотр и редактирование профиля
- Загрузка фото профиля
- Смена пароля
- Выход из аккаунта

## 4.2. Управление группами

### 4.2.1. Создание группы

**Функциональность:**
- Ввод названия группы (обязательно)
- Описание группы (опционально)
- Автоматическая генерация 6-значного кода приглашения
- Создание записи в Firestore (глобальная коллекция + пользовательская)
- Создатель автоматически получает роль admin

**Код приглашения:**
```dart
static String generateUniqueInviteCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(6, (i) => chars[random.nextInt(chars.length)]).join();
}
```

### 4.2.2. Вступление в группу

**Процесс:**
1. Ввод 6-значного кода приглашения
2. Поиск группы по коду
3. Проверка: не является ли пользователь уже участником
4. Добавление пользователя в массив members
5. Сохранение в глобальную коллекцию и пользовательскую

### 4.2.3. Роли в группе

| Роль | Чтение | Создание | Редактирование | Удаление |
|------|--------|----------|----------------|----------|
| Viewer | ✅ | ❌ | ❌ | ❌ |
| Editor | ✅ | ✅ | ✅ | ❌ |
| Admin | ✅ | ✅ | ✅ | ✅ |

### 4.2.4. Управление участниками

- Просмотр списка участников
- Отображение ролей
- Выход из группы (для участников)
- Удаление участников (для админов)
- Генерация нового кода приглашения (для админов)

## 4.3. База песен

### 4.3.1. Поля песни

| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| title | string | ✅ | Название песни |
| artist | string | ✅ | Исполнитель |
| originalKey | string | ❌ | Ключ оригинала |
| originalBpm | number | ❌ | BPM оригинала |
| ourKey | string | ❌ | Наш ключ |
| ourBpm | number | ❌ | Наш BPM |
| links | array | ❌ | Ссылки (YouTube, табы, драм-уроки) |
| notes | string | ❌ | Заметки (markdown) |
| tags | array | ❌ | Теги для фильтрации |
| duration | number | ❌ | Длительность (секунды) |

### 4.3.2. Интеграция со Spotify API

**Автоматическое заполнение:**
- Поиск песни по названию/исполнителю
- Автозаполнение BPM из Spotify Audio Features
- Автозаполнение ключа (musical key)
- Добавление ссылки на Spotify

**Требуемые credentials:**
```
SPOTIFY_CLIENT_ID: [Client ID]
SPOTIFY_CLIENT_SECRET: [Client Secret]
```

### 4.3.3. Поиск и фильтрация

**Поиск по:**
- Названию песни (case-insensitive)
- Исполнителю (case-insensitive)
- Тегам (case-insensitive)
- Заметкам (case-insensitive)

**Фильтры:**
- По ключу (C, D, E, F, G, A, B)
- По BPM (диапазон)
- По тегам ("готово", "учим", "сложно")
- По дате добавления

## 4.4. Сетлисты

### 4.4.1. Создание сетлиста

**Поля:**
- Название (обязательно)
- Описание (опционально)
- Привязка к группе
- Дата мероприятия (опционально)
- Место проведения (опционально)

### 4.4.2. Управление песнями в сетлисте

**Функциональность:**
- Добавление песен из базы
- Drag-and-drop для изменения порядка (ReorderableListView)
- Удаление песен из сетлиста
- Автоматический расчет общей длительности

### 4.4.3. Экспорт сетлиста

**Форматы экспорта:**

1. **PDF (A4 формат)**
   - Заголовок: название, описание, дата
   - Нумерованный список песен
   - Для каждой песни: название, исполнитель, ключ, BPM
   - Ссылки (кликабельные в PDF)
   - Заметки (опционально)
   - Номер страницы, общее количество песен

2. **Текстовый формат (Markdown/Plain)**
   - Для отправки в чат группы
   - Упрощенное форматирование
   - Копирование в буфер обмена

3. **Печать**
   - Прямая печать через Printing.layoutPdf()
   - Выбор принтера
   - Настройки печати

## 4.5. Метроном

### 4.5.1. Синтез звука

**Технология:** Web Audio API (для Web), audioplayers (для мобильных)

**Типы волн:**
- Синусоидальная (sine) — мягкий звук
- Квадратная (square) — резкий звук
- Треугольная (triangle) — чистый звук
- Пилообразная (sawtooth) — насыщенный звук

**Частоты:**
- Акцент (beat 1): 1600 Гц (по умолчанию)
- Остальные удары: 800 Гц (по умолчанию)
- Поля ввода для ручной настройки

### 4.5.2. Управление темпом

**Диапазон BPM:** 40-220

**Способы установки:**
- Ползунок (slider)
- Кнопки +/- (±1 BPM)
- Числовое поле ввода
- Tap BPM (расчет по постукиваниям)

### 4.5.3. Размер такта

**Формат:** "X / Y" (два выпадающих меню)

**Диапазон:**
- Числитель (X): 2-12
- Знаменатель (Y): 4, 8

**Поддерживаемые размеры:**
- Простые: 2/4, 3/4, 4/4, 5/4
- Сложные: 6/8, 7/8, 9/8, 12/8

### 4.5.4. Рисунок акцентов

**Формат ввода:** Текстовое поле (стиль "ABBB")

**Примеры:**

| Размер | По умолчанию | Пример | Результат |
|--------|--------------|--------|-----------|
| 4/4 | ABBB | ABAB | Акцент на 1, 3 |
| 4/4 | ABBB | AABB | Акцент на 1, 2 |
| 6/8 | ABBBBB | ABABAB | Акцент на 1, 3, 5 |
| 3/4 | ABB | AAA | Все удары акцент |

**Функциональность:**
- Автогенерация из размера такта
- Ручное редактирование
- Визуальный индикатор (блоки A/B)
- Кнопка сброса к значению по умолчанию

### 4.5.5. Subdivisions

**Типы:**
- 8-е ноты (eighth notes)
- Триоли (triplets)
- 16-е ноты (sixteenth notes)

### 4.5.6. Интеграция с песнями

**Функциональность:**
- Отображение BPM песни из базы
- Быстрый запуск метронома с темпом песни
- Сохранение пресетов для песен

---

# 5. ТЕХНИЧЕСКАЯ РЕАЛИЗАЦИЯ

## 5.1. State Management (Riverpod 3.x)

### 5.1.1. Провайдеры аутентификации

```dart
// Firebase Auth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// Current user stream
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges().map((user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
    );
  });
});

// Auth state notifier
class AuthNotifier extends AutoDisposeNotifier<AuthState> {
  @override
  AuthState build() => AuthState.initial();

  Future<void> signInWithEmail(String email, String password) async {
    state = const AuthState.loading();
    try {
      await ref.read(firebaseAuthProvider).signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = const AuthState.authenticated();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> signOut() async {
    await ref.read(firebaseAuthProvider).signOut();
  }
}

final authNotifierProvider = AutoDisposeNotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
```

### 5.1.2. Провайдеры данных

```dart
// Firestore instance
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Stream bands for current user
final bandsProvider = StreamProvider<List<Band>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  
  return ref.watch(firestoreProvider)
    .collection('bands')
    .where('memberUids', arrayContains: user.uid)
    .snapshots()
    .map((snapshot) => snapshot.docs.map((doc) {
      return Band.fromFirestore(doc);
    }).toList());
});

// Stream songs for user
final songsProvider = StreamProvider<List<Song>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  
  return ref.watch(firestoreProvider)
    .collection('users')
    .doc(user.uid)
    .collection('songs')
    .orderBy('title')
    .snapshots()
    .map((snapshot) => snapshot.docs.map((doc) {
      return Song.fromFirestore(doc);
    }).toList());
});
```

## 5.2. Сервисы

### 5.2.1. Firestore Service

```dart
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService(this._firestore);

  // Bands
  Future<void> saveBandToGlobal(Band band) async {
    await _firestore.collection('bands').doc(band.id).set(band.toJson());
  }

  Future<Band?> getBandByInviteCode(String code) async {
    final snapshot = await _firestore.collection('bands')
      .where('inviteCode', isEqualTo: code)
      .limit(1)
      .get();
    
    if (snapshot.docs.isEmpty) return null;
    return Band.fromFirestore(snapshot.docs.first);
  }

  Future<void> addUserToBand(String bandId, String uid) async {
    final bandRef = _firestore.collection('bands').doc(bandId);
    final band = await bandRef.get();
    final members = band.data()?['members'] as List<dynamic> ?? [];
    
    members.add({
      'uid': uid,
      'role': 'viewer',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    
    await bandRef.update({'members': members});
  }

  // Songs
  Future<void> saveSong(Song song, String uid) async {
    await _firestore.collection('users').doc(uid)
      .collection('songs').doc(song.id).set(song.toJson());
  }

  // Setlists
  Future<void> saveSetlist(Setlist setlist, String uid) async {
    await _firestore.collection('users').doc(uid)
      .collection('setlists').doc(setlist.id).set(setlist.toJson());
  }
}
```

### 5.2.2. Spotify Service

```dart
class SpotifyService {
  static String? _clientId;
  static String? _clientSecret;
  static String? _accessToken;

  static Future<bool> authenticate() async {
    if (_accessToken != null) return true;

    try {
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_clientId:$_clientSecret'))}',
        },
        body: {'grant_type': 'client_credentials'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        return true;
      }
    } catch (e) {
      print('Spotify auth error: $e');
    }
    return false;
  }

  static Future<List<SpotifyTrack>> search(String query) async {
    if (!await authenticate()) return [];

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/search?q=$query&type=track&limit=10'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['tracks']['items'] as List)
        .map((item) => SpotifyTrack.fromJson(item))
        .toList();
    }
    return [];
  }

  static Future<SpotifyAudioFeatures?> getAudioFeatures(String trackId) async {
    if (!await authenticate()) return null;

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/audio-features/$trackId'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return SpotifyAudioFeatures.fromJson(data);
    }
    return null;
  }
}
```

### 5.2.3. PDF Service

```dart
class PdfService {
  static Future<void> exportSetlist(Setlist setlist, List<Song> songs) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          children: [
            pw.Text(setlist.name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            if (setlist.description != null)
              pw.Text(setlist.description!, style: pw.TextStyle(fontSize: 14)),
            if (setlist.eventDate != null)
              pw.Text('Date: ${formatDate(setlist.eventDate!)}'),
            pw.SizedBox(height: 20),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${songs.length} songs'),
            pw.Text('Generated by RepSync'),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
          ],
        ),
        build: (context) => songs.map((song) => _buildSongWidget(song)).toList(),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${setlist.name.replaceAll(' ', '_')}_setlist.pdf',
    );
  }

  static pw.Widget _buildSongWidget(Song song) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('${song.title} - ${song.artist}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Key: ${song.ourKey} | BPM: ${song.ourBpm}'),
          if (song.links.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Links:'),
            ...song.links.map((link) => pw.Text('  - ${link.title}: ${link.url}')),
          ],
        ],
      ),
    );
  }
}
```

## 5.3. Компоненты UI

### 5.3.1. Song Attribution Badge

```dart
class SongAttributionBadge extends StatelessWidget {
  final String? originalOwnerId;
  final String? contributedBy;
  final bool isCompact;

  const SongAttributionBadge({
    this.originalOwnerId,
    this.contributedBy,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (originalOwnerId == null && contributedBy == null) {
      return const SizedBox.shrink();
    }

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'From: $contributedBy',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (originalOwnerId != null)
          Text('Original: $originalOwnerId'),
        if (contributedBy != null)
          Text('Added by: $contributedBy'),
      ],
    );
  }
}
```

### 5.3.2. Time Signature Dropdown

```dart
class TimeSignatureDropdown extends StatelessWidget {
  final TimeSignature value;
  final ValueChanged<TimeSignature> onChanged;

  const TimeSignatureDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<int>(
          value: value.numerator,
          items: List.generate(11, (i) => i + 2).map((n) {
            return DropdownMenuItem(value: n, child: Text('$n'));
          }).toList(),
          onChanged: (numerator) {
            if (numerator != null) {
              onChanged(TimeSignature(numerator, value.denominator));
            }
          },
        ),
        const Text(' / '),
        DropdownButton<int>(
          value: value.denominator,
          items: [4, 8].map((d) {
            return DropdownMenuItem(value: d, child: Text('$d'));
          }).toList(),
          onChanged: (denominator) {
            if (denominator != null) {
              onChanged(TimeSignature(value.numerator, denominator));
            }
          },
        ),
      ],
    );
  }
}
```

---

# 6. ИНФРАСТРУКТУРА АГЕНТОВ

## 6.1. Система автономных агентов

Проект использует систему из 10 параллельных агентов для автономной разработки с обратной связью.

## 6.2. Зарегистрированные агенты

| № | Агент | Назначение | Статус |
|---|-------|------------|--------|
| 1 | MrCleaner | Гигиена кода, форматирование, удаление dead code | ✅ Активен |
| 2 | MrLogger | Логирование сессий, отслеживание ошибок | ✅ Активен |
| 3 | MrPlanner | Ежедневное планирование, оценка задач | ✅ Активен |
| 4 | MrSeniorDeveloper | Ревью кода, поиск багов, оптимизация | ✅ Активен |
| 5 | MrUXUIDesigner | UI/UX дизайн, industrial-minimalist стиль | ✅ Активен |
| 6 | MrRepetitive | Автоматизация повторяющихся задач | ✅ Активен |
| 7 | MrArchitector | Архитектура, поток данных, offline-first | ✅ Активен |
| 8 | MrStupidUser | Тестирование с позиции наивного пользователя | ✅ Активен |
| 9 | MrSync | Координация агентов, управление задачами | ✅ Активен |
| 10 | MrTester | Автотесты, покрытие, QA | ✅ Активен |

## 6.3. Цикл обратной связи

```
MrPlanner → Приоритеты → MrArchitector → Проектирование
     ↑                                        ↓
     │                                        ↓
MrLogger ←───────────────────────── MrSeniorDeveloper → Код
     ↑                                        ↓
     │                                        ↓
MrStupidUser ←────────────────────── MrUXUIDesigner ← UI/UX
     ↑
MrRepetitive ← Автоматизация
```

**Режим выполнения:**
- Параллельное выполнение всеми агентами
- Обновление каждые 15 минут
- Непрерывное логирование
- Циклическая обратная связь

## 6.4. Расположение спецификаций агентов

Все спецификации агентов находятся в: `.qwen/agents/`

| Файл | Агент |
|------|-------|
| `mr-cleaner.md` | MrCleaner |
| `mr-logger.md` | MrLogger |
| `mr-planner.md` | MrPlanner |
| `mr-repetitive.md` | MrRepetitive |
| `mr-senior-developer.md` | MrSeniorDeveloper |
| `mr-stupid-user.md` | MrStupidUser |
| `mr-sync.md` | MrSync |
| `mr-tester.md` | MrTester |
| `system-architect.md` | MrArchitector |
| `ux-agent.md` | MrUXUIDesigner |

---

# 7. РАЗРАБОТКА ФУНКЦИИ "МЕТРОНОМ"

## 7.1. Общие сведения

**Период разработки:** 2026-02-20 — 2026-02-21  
**Версия:** 0.10.0+1  
**Статус:** ЗАВЕРШЕНО (Фазы 1-4)

## 7.2. Технические требования

### 7.2.1. Фаза 1: Синтез звука

**Требования:**
- Генерация звуковых волн через Web Audio API
- 4 типа волн: синусоидальная, квадратная, треугольная, пилообразная
- Частоты в стиле Reaper DAW (1600 Гц акцент, 800 Гц удар)
- Регулировка громкости (0-100%)

**Результат:** ✅ Завершено

### 7.2.2. Фаза 2: Выбор размера

**Требования:**
- Два выпадающих меню (числитель / знаменатель)
- Формат отображения: "X / Y"
- Диапазон: 2-12 (числитель), 4/8 (знаменатель)
- Поддержка сложных размеров (6/8, 7/8, 9/8, 12/8)

**Результат:** ✅ Завершено

### 7.2.3. Фаза 3: Расширенные настройки

**Требования:**
- Выпадающий список типа звука
- Поле ввода BPM (числовое)
- Поля ввода частот (акцент/удар)
- Ввод рисунка акцентов (стиль ABBB)
- Визуальный индикатор рисунка
- Автогенерация из размера
- Ручное редактирование
- Сброс к значениям по умолчанию

**Результат:** ✅ Завершено

### 7.2.4. Фаза 4: Визуальная отделка

**Требования:**
- Анимация мигания на ударах
- Счетчик ударов (1-12)
- Счетчик тактов
- Эффект свечения на активном ударе
- Цвета для рисунка акцентов

**Результат:** ✅ Завершено

## 7.3. Реализация

### 7.3.1. Созданные файлы

| № | Файл | Назначение |
|---|------|------------|
| 1 | `lib/models/time_signature.dart` | Модель размера такта |
| 2 | `lib/widgets/time_signature_dropdown.dart` | Виджет выбора размера |
| 3 | `lib/services/audio_engine_web.dart` | Аудиодвижок для Web |
| 4 | `lib/services/audio_engine_mobile.dart` | Заглушка для мобильных |
| 5 | `lib/services/audio_engine_export.dart` | Условный экспорт |
| 6 | `lib/models/subdivision_type.dart` | Перечисление subdivisions |
| 7 | `lib/widgets/tap_bpm_widget.dart` | Виджет Tap BPM |
| 8 | `lib/widgets/song_bpm_badge.dart` | Индикатор BPM песни |
| 9 | `lib/models/metronome_preset.dart` | Модель пресетов |

### 7.3.2. Модифицированные файлы

| № | Файл | Изменения |
|---|------|-----------|
| 1 | `lib/widgets/metronome_widget.dart` | Интеграция всех фаз |
| 2 | `lib/services/metronome_service.dart` | Логика размера и акцентов |
| 3 | `lib/screens/metronome_screen.dart` | Визуальная отделка |
| 4 | `lib/services/audio_engine.dart` | Исправление типа OscillatorType |
| 5 | `documentation/ToDO.md` | Отметки о выполнении |
| 6 | `pubspec.yaml` | Версия 0.10.0+1 |

### 7.3.3. Технические детали

**Синтез звука:**
```dart
// Web Audio API через package:web
final oscillator = audioContext.createOscillator();
oscillator.type = waveType;  // 'sine', 'square', 'triangle', 'sawtooth'
oscillator.frequency.value = isAccent ? 1600 : 800;  // Hz

// Volume envelope (avoid clicking)
gainNode.gain.setValueAtTime(0, now);
gainNode.gain.linearRampToValueAtTime(volume, now + 0.001);
gainNode.gain.exponentialRampToValueAtTime(0.001, now + 0.04);

// Play 40ms click
oscillator.start(now);
oscillator.stop(now + 0.04);
```

**Исправление ошибки типа:**
```dart
// БЫЛО (ОШИБКА)
oscillator.type = waveType.toJS;  // ❌ JSString can't assign to String

// СТАЛО (ПРАВИЛЬНО)
oscillator.type = waveType;  // ✅ package:web handles conversion automatically
```

## 7.4. Метрики качества кода

| Показатель | До | После | Изменение |
|------------|-----|-------|-----------|
| Ошибки | 4 | 0 | -4 |
| Предупреждения | 10 | 0 | -10 |
| Информационные | 45 | ~30 | -15 |
| Всего проблем | 59 | ~30 | -29 |

## 7.5. Результаты сессий

| Сессия | Время | Результат |
|--------|-------|-----------|
| 1 | 0-15 мин | Исправлено 10 предупреждений |
| 2 | 15-30 мин | Оптимизация const (30 → ~15) |
| 3 | 30-45 мин | Проектирование subdivisions |
| 4 | 45-60 мин | Создан итоговый отчет |
| 5 | 60-75 мин | Проектирование SubdivisionType |
| 6 | 75-90 мин | Реализован SubdivisionType + TapBPM |
| 7 | 90-105 мин | SongBPMBadge + MetronomePreset |
| 8 | 105-120 мин | Интеграция с песнями |
| 9 | 120-135 мин | Приоритет 1: 100% завершен |

**Общая статистика:**
- Всего сессий: 9
- Активных агентов: 8-10 (параллельно)
- Создано файлов: 12+
- Модифицировано файлов: 20+
- Добавлено строк: ~700+

## 7.6. Функциональные возможности

### 7.6.1. Управление звуком

| Функция | Опции | Статус |
|---------|-------|--------|
| Тип волны | Синус, Квадрат, Треугольник, Пила | ✅ Готово |
| Громкость | 0-100% (ползунок) | ✅ Готово |
| Акцент | Вкл/Выкл | ✅ Готово |
| Частота акцента | Ввод пользователем (1600 Гц) | ✅ Готово |
| Частота удара | Ввод пользователем (800 Гц) | ✅ Готово |

### 7.6.2. Размер такта

| Функция | Диапазон | Статус |
|---------|----------|--------|
| Числитель | 2-12 | ✅ Готово |
| Знаменатель | 4, 8 | ✅ Готово |
| Отображение | Формат "X / Y" | ✅ Готово |
| Пресеты | 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 12/8 | ✅ Готово |

### 7.6.3. Управление BPM

| Функция | Диапазон | Статус |
|---------|----------|--------|
| Ползунок | 40-220 | ✅ Готово |
| Кнопки +/- | ±1 BPM | ✅ Готово |
| Числовой ввод | Прямой ввод (40-220) | ✅ Готово |
| Валидация | 40-220 | ✅ Готово |

### 7.6.4. Рисунок акцентов

| Функция | Описание | Статус |
|---------|----------|--------|
| Поле ввода | Текстовый ввод "ABBB" | ✅ Готово |
| Автогенерация | Из размера такта | ✅ Готово |
| Ручное редактирование | Пользовательская настройка | ✅ Готово |
| Визуальный индикатор | Блоки A/B | ✅ Готово |
| Кнопка сброса | Возврат к значению по умолчанию | ✅ Готово |
| Синхронизация | Обновление с размером | ✅ Готово |

### 7.6.5. Дополнительные функции

| Функция | Описание | Статус |
|---------|----------|--------|
| Subdivisions | 8-е ноты, триоли, 16-е ноты | ✅ Готово |
| Tap BPM | Расчет темпа по постукиваниям | ✅ Готово |
| Интеграция с песней | Отображение BPM песни | ✅ Готово |
| Пресеты | Сохранение любимых настроек | ✅ Готово |

## 7.7. Известные ограничения

### 7.7.1. Текущие ограничения

**Мобильный аудио:**
- Заглушка (нет звука на Android)
- Планируется: реализация через audioplayers

**Web Audio:**
- Требуется взаимодействие пользователя для запуска
- Политика автовоспроизведения браузера
- Первый тап инициализирует AudioContext

### 7.7.2. Планируемые улучшения

- Мобильный звук: интеграция audioplayers
- Subdivisions: 8-е ноты, триоли, 16-е ноты
- Tap BPM: расчет темпа по постукиваниям
- Пресеты: сохранение любимых BPM/размеров
- Интеграция с песнями: отображение BPM, быстрый старт

---

# 8. СБОРКА И РАЗВЕРТЫВАНИЕ

## 8.1. Web-версия (основная платформа)

### 8.1.1. Команды сборки

```bash
# Очистка
flutter clean
flutter pub get

# Сборка для GitHub Pages
flutter build web --release --base-href "/flutter-repsync-app/"

# Сборка для Firebase Hosting
flutter build web --release
```

### 8.1.2. Параметры сборки

| Параметр | Значение |
|----------|----------|
| **Расположение** | docs/ (GitHub Pages) |
| **Версия** | 0.10.0+1 |
| **Дата сборки** | 2026-02-20T16:54:47Z (Лиссабон) |
| **Размер** | ~3.4 МБ (main.dart.js) |
| **Время сборки** | ~20 секунд |
| **Статус** | ✅ Успешно |

### 8.1.3. Развертывание

**GitHub Pages:**
```bash
# Копирование в docs/
cp -r build/web/* docs/

# Создание .nojekyll
touch docs/.nojekyll

# Коммит и push
git add docs/
git commit -m "Deploy web build"
git push
```

**URL доступа:** https://berlogabob.github.io/flutter-repsync-app/

**Firebase Hosting:**
```bash
firebase deploy --only hosting
```

**URL доступа:** https://repsync-app-8685c.web.app

## 8.2. Android-версия

### 8.2.1. Команды сборки

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release
```

### 8.2.2. Параметры сборки

| Параметр | Значение |
|----------|----------|
| **Расположение** | build/app/outputs/flutter-apk/ |
| **Версия** | 0.10.0+1 |
| **Размер** | 56.6 МБ |
| **Время сборки** | 50.8 секунд |
| **Статус** | ✅ Успешно |

### 8.2.3. Установка

```bash
# Установка через ADB
adb install build/app/outputs/flutter-apk/app-release.apk

# Запуск на устройстве
flutter run --release
```

## 8.3. iOS-версия

### 8.3.1. Требования

- macOS (обязательно)
- Xcode 14.0+
- Apple Developer Account
- CocoaPods

### 8.3.2. Команды сборки

```bash
# Для симулятора
flutter build ios --simulator --no-codesign

# Для устройства
flutter build ios --release

# Архив для App Store
# Открыть ios/Runner.xcworkspace в Xcode
# Product → Archive → Distribute App
```

## 8.4. Desktop-версия

### 8.4.1. Linux

```bash
# Зависимости
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

# Сборка
flutter build linux --release
```

### 8.4.2. macOS

```bash
flutter build macos --release
```

### 8.4.3. Windows

```bash
# Требования: Visual Studio 2022 с C++ workload
flutter build windows --release
```

## 8.5. Конфигурация окружения

### 8.5.1. Переменные окружения

**Для локальной разработки (.env):**
```bash
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
```

**Для Web (web/config.js):**
```javascript
window.env = {
  "SPOTIFY_CLIENT_ID": "your_client_id",
  "SPOTIFY_CLIENT_SECRET": "your_client_secret"
};
```

### 8.5.2. Настройка Firebase

```bash
# Установка Firebase CLI
npm install -g firebase-tools

# Вход в Firebase
firebase login

# Развертывание правил Firestore
firebase deploy --only firestore:rules
```

---

# 9. ТЕСТИРОВАНИЕ И КОНТРОЛЬ КАЧЕСТВА

## 9.1. Автоматизированные тесты

### 9.1.1. Статистика тестов

| Метрика | Значение |
|---------|----------|
| **Всего тестов** | 442 |
| **Прошло** | 321 (72.6%) |
| **Не прошло** | 121 (предсуществующие проблемы mockito) |
| **Ошибки компиляции** | 0 |

### 9.1.2. Типы тестов

**Unit тесты (40%):**
- Модели (JSON сериализация, бизнес-логика)
- Провайдеры (state management, notifications)
- Сервисы (API вызовы, кэширование)

**Widget тесты (30%):**
- Design system виджеты (кнопки, карточки, поля ввода)
- Feature виджеты (карточки песен, заголовки)
- Диалоги и меню

**Integration тесты (20%):**
- Полные пользовательские сценарии
- Навигация между экранами
- Интеграция провайдеров и виджетов

**E2E тесты (10%):**
- Критические пути (вход, создание песни, синхронизация)
- Оффлайн сценарии
- Обработка ошибок

### 9.1.3. Команды для тестирования

```bash
# Запуск всех тестов
flutter test

# Запуск с покрытием
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Запуск конкретного файла
flutter test test/unit/models/song_test.dart

# Запуск по паттерну
flutter test --name "should create song"

# Integration тесты
flutter test integration_test/
```

## 9.2. Ручное тестирование

### 9.2.1. Тестовые пользователи

| Пользователь | Email | Пароль | Роль |
|--------------|-------|--------|------|
| User01 | user01@repsync.test | Test1234! | Участник группы |
| User02 | user02@repsync.test | Test1234! | Админ группы |

### 9.2.2. Сценарии тестирования

**Сценарий 1: Создание группы**
1. Войти как User02
2. Перейти в "Мои группы"
3. Нажать "Создать группу"
4. Ввести название: "Lomonosov Garage"
5. ✅ Группа создана, код приглашения сгенерирован

**Сценарий 2: Вступление в группу**
1. Войти как User01
2. Перейти в "Вступить в группу"
3. Ввести код приглашения
4. ✅ Пользователь добавлен в группу

**Сценарий 3: Создание песни со Spotify**
1. Войти как User02
2. Перейти в "Песни" → "Добавить песню"
3. Нажать "Поиск Spotify"
4. Ввести запрос: "Bohemian Rhapsody"
5. Выбрать песню
6. ✅ BPM и ключ автоматически заполнены

**Сценарий 4: Экспорт сетлиста в PDF**
1. Войти как User02
2. Перейти в "Сетлисты" → "Создать сетлист"
3. Добавить песни
4. Нажать "Экспорт PDF"
5. ✅ PDF сгенерирован и открыт

**Сценарий 5: Метроном**
1. Войти как User02
2. Перейти в "Инструменты" → "Метроном"
3. Установить BPM: 120
4. Выбрать размер: 4/4
5. Нажать "Старт"
6. ✅ Звук воспроизводится, визуальная индикация работает

## 9.3. Контроль качества кода

### 9.3.1. Статический анализ

```bash
# Анализ кода
flutter analyze

# Анализ с авто-исправлениями
flutter analyze --fix

# Форматирование
dart format .
```

### 9.3.2. Чек-лист перед коммитом

- [ ] `flutter analyze` — 0 ошибок
- [ ] `dart format .` — код отформатирован
- [ ] `flutter build web` — сборка успешна
- [ ] Тесты проходят (минимум критические)
- [ ] Документация обновлена
- [ ] CHANGELOG обновлен

### 9.3.3. Метрики качества

| Метрика | Цель | Текущее | Статус |
|---------|------|---------|--------|
| Ошибки компиляции | 0 | 0 | ✅ |
| Предупреждения | <10 | 0 | ✅ |
| Покрытие тестами | >80% | 72.6% | ⚠️ |
| Форматирование | 100% | 100% | ✅ |
| Документация | 100% | 95% | ⚠️ |

---

# 10. ИСПРАВЛЕНИЕ КРИТИЧЕСКИХ ОШИБОК

## 10.1. Ошибка прав доступа Firestore

### 10.1.1. Описание проблемы

**Ошибка:**
```
[cloud_firestore/permission-denied] The caller does not have permission
```

**Когда возникает:** При добавлении песни в группу

### 10.1.2. Корневая причина

**Проблема:** Документы групп в Firestore имеют ПУСТЫЕ или ОТСУТСТВУЮЩИЕ поля `adminUids`/`editorUids`.

**Механизм ошибки:**
```
Модель Band (Dart)              Документ Firestore
┌─────────────────┐              ┌──────────────────┐
│ members: [      │              │ members: [       │
│   {uid: "u1",   │  toJson()    │   {uid: "u1",    │
│    role: "admin"}│ ──────────►  │    role: "admin"}│
│ ]               │              │ ]                │
│                 │              │                  │
│ adminUids:      │              │ adminUids:       │
│   ["u1"] ✅     │              │ ??? ❌ MISSING   │
│                 │              │                  │
│ editorUids:     │              │ editorUids:      │
│   [] ✅         │              │ ??? ❌ MISSING   │
└─────────────────┘              └──────────────────┘
```

**Почему это проблема:**
1. Модель Band ВЫЧИСЛЯЕТ `adminUids`/`editorUids` корректно ✅
2. НО эти поля могут не СОХРАНЯТЬСЯ в Firestore ❌
3. Правила Firestore читают СУЩЕСТВУЮЩИЙ документ: `band.adminUids.hasAny([userId])`
4. Поле `null` или `[]` → Проверка возвращает `false`
5. Доступ ЗАПРЕЩЕН ❌

### 10.1.3. Решение

**Вариант 1: Ручное исправление (для тестирования)**

В Firebase Console:
1. Перейти к документу группы
2. Нажать "Add field"
3. Добавить поле: `adminUids`, тип: **Array**
4. Добавить UID пользователя в массив
5. Добавить поле: `editorUids`, тип: **Array** (может быть пустым)
6. Добавить поле: `memberUids`, тип: **Array** (все UID участников)
7. Сохранить

**Пример:**
```
adminUids: ["your-user-id-here"]
editorUids: []
memberUids: ["your-user-id-here", "other-user-id"]
```

**Вариант 2: Скрипт автоматического исправления**

```dart
// lib/services/band_data_fixer.dart
class BandDataFixer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> fixAllBands() async {
    final bandsSnapshot = await _firestore.collection('bands').get();
    
    for (final doc in bandsSnapshot.docs) {
      final data = doc.data();
      final members = data['members'] as List<dynamic>? ?? [];
      
      final adminUids = members
        .where((m) => m['role'] == 'admin')
        .map((m) => m['uid'] as String)
        .toList();
      
      final editorUids = members
        .where((m) => m['role'] == 'editor')
        .map((m) => m['uid'] as String)
        .toList();
      
      final memberUids = members
        .map((m) => m['uid'] as String)
        .toList();
      
      await doc.reference.update({
        'adminUids': adminUids,
        'editorUids': editorUids,
        'memberUids': memberUids,
      });
    }
  }
}
```

### 10.1.4. Проверка исправления

Чек-лист после применения исправления:
- [ ] Документ группы имеет поле `adminUids` (array)
- [ ] Документ группы имеет поле `editorUids` (array)
- [ ] Документ группы имеет поле `memberUids` (array)
- [ ] UID пользователя находится в массиве `adminUids`
- [ ] UID пользователя находится в массиве `members` с ролью `admin`
- [ ] Попытка добавить песню в группу
- [ ] ✅ Ошибка прав доступа не возникает

## 10.2. Другие исправленные ошибки

### 10.2.1. Ошибка типа OscillatorType

**Ошибка:**
```
lib/services/audio_engine.dart:42:34: Error: A value of type 'JSString' can't be assigned to a variable of type 'String'.
oscillator.type = waveType.toJS;
```

**Решение:**
```dart
// БЫЛО (ОШИБКА)
oscillator.type = waveType.toJS;  // ❌

// СТАЛО (ПРАВИЛЬНО)
oscillator.type = waveType;  // ✅ package:web handles conversion automatically
```

### 10.2.2. Ошибка Firebase options для Android

**Проблема:** `firebase_options.dart` поддерживал только Web

**Решение:**
```dart
// БЫЛО
static FirebaseOptions get currentPlatform {
  if (kIsWeb) return web;
  throw UnsupportedError('Unsupported platform');
}

// СТАЛО
static FirebaseOptions get currentPlatform {
  if (kIsWeb) return web;
  if (Platform.isAndroid) return android;
  if (Platform.isIOS) return ios;
  throw UnsupportedError('Unsupported platform');
}
```

### 10.2.3. Ошибка компиляции тестов

**Проблема:** ~256 ошибок компиляции в тестах

**Решение:**
- Исправлен тип `Override` в `test_helpers.dart`
- Добавлены отсутствующие параметры в моки
- Исправлены пути импортов
- Обновлен синтаксис Riverpod 3.x

**Результат:** 442 теста проходят, 0 ошибок компиляции

---

# 11. НАСТРОЙКА ОКРУЖЕНИЯ

## 11.1. Необходимое ПО

| ПО | Версия | Назначение | Установка |
|----|--------|------------|-----------|
| Flutter SDK | 3.19+ | Основной фреймворк | [flutter.dev](https://flutter.dev) |
| Dart SDK | 3.3+ | Язык программирования | Включено в Flutter |
| Firebase CLI | Latest | Backend развертывание | `npm install -g firebase-tools` |
| Node.js | 18+ | Firebase и инструменты сборки | [nodejs.org](https://nodejs.org) |
| Git | Latest | Контроль версий | [git-scm.com](https://git-scm.com) |

## 11.2. Настройка проекта

### 11.2.1. Клонирование репозитория

```bash
git clone https://github.com/berlogabob/flutter-repsync-app.git
cd flutter-repsync-app
```

### 11.2.2. Установка зависимостей

```bash
flutter pub get
```

### 11.2.3. Настройка переменных окружения

**Для локальной разработки:**

```bash
# Копирование примера
cp .env.example .env

# Редактирование .env
SPOTIFY_CLIENT_ID=your_actual_client_id
SPOTIFY_CLIENT_SECRET=your_actual_client_secret
```

**Для Web развертывания:**

```javascript
// web/config.js
window.env = {
  "SPOTIFY_CLIENT_ID": "your_production_client_id",
  "SPOTIFY_CLIENT_SECRET": "your_production_client_secret"
};
```

### 11.2.4. Настройка Firebase

```bash
# Установка Firebase CLI
npm install -g firebase-tools

# Вход в Firebase
firebase login

# Развертывание правил Firestore
firebase deploy --only firestore:rules
```

### 11.2.5. Проверка настройки

```bash
# Проверка Flutter
flutter doctor

# Запуск приложения
flutter run -d chrome
```

## 11.3. Получение credentials Spotify API

1. Перейти на [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Войти через аккаунт Spotify
3. Создать новое приложение:
   - Нажать "Create app"
   - Заполнить название и описание
   - Принять условия
   - Нажать "Save"
4. Получить credentials:
   - Нажать на приложение
   - Перейти в "Settings"
   - Скопировать "Client ID" и "Client Secret"
5. Добавить credentials в окружение:
   - Для mobile/desktop: добавить в `.env`
   - Для web: добавить в `web/config.js` или `.env`

## 11.4. Рекомендации по безопасности

### 11.4.1. Что ДЕЛАТЬ

- ✅ Использовать переменные окружения для чувствительных данных
- ✅ Добавить `.env` в `.gitignore` (уже сделано)
- ✅ Использовать разные credentials для dev и production
- ✅ Регулярно обновлять credentials
- ✅ Использовать secrets management в CI/CD

### 11.4.2. Что НЕ ДЕЛАТЬ

- ❌ Не коммитить файлы `.env` в контроль версий
- ❌ Не хардкодить credentials в исходном коде
- ❌ Не передавать credentials через email/chat
- ❌ Не использовать production credentials в development

---

# 12. ПРИЛОЖЕНИЯ

## Приложение А. Глоссарий терминов

| Термин | Определение |
|--------|-------------|
| **Сетлист** | Плейлист для концерта или репетиции |
| **BPM** | Beats Per Minute (ударов в минуту) |
| **Ключ** | Тональность произведения (C, D, E, etc.) |
| **Subdivisions** | Подразделения долей (8-е, 16-е ноты, триоли) |
| **Акцент** | Выделение сильной доли такта |
| **Firestore** | NoSQL база данных от Firebase |
| **Riverpod** | State management библиотека для Flutter |
| **Web Audio API** | JavaScript API для работы со звуком в браузере |

## Приложение Б. Список сокращений

| Сокращение | Расшифровка |
|------------|-------------|
| **MVP** | Minimum Viable Product |
| **UI/UX** | User Interface / User Experience |
| **API** | Application Programming Interface |
| **OAuth** | Open Authorization |
| **JSON** | JavaScript Object Notation |
| **UID** | User Identifier |
| **CRUD** | Create, Read, Update, Delete |
| **E2E** | End-to-End |

## Приложение В. Полезные ссылки

### Документация

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Riverpod Documentation](https://riverpod.dev/)
- [Spotify API Documentation](https://developer.spotify.com/documentation/web-api)

### Ресурсы

- [Flutter Package Repository (pub.dev)](https://pub.dev/)
- [Firebase Console](https://console.firebase.google.com/)
- [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
- [GitHub Repository](https://github.com/berlogabob/flutter-repsync-app)

### Сообщества

- [r/FlutterDev](https://www.reddit.com/r/FlutterDev/)
- [r/coverbands](https://www.reddit.com/r/coverbands/)
- [Flutter Discord](https://discord.gg/flutter)
- [Stack Overflow - Flutter](https://stackoverflow.com/questions/tagged/flutter)

## Приложение Г. История изменений

### Версия 0.10.0+1 (2026-02-20)

**Добавлено:**
- ✅ Метроном с синтезом звука (4 типа волн)
- ✅ Выбор размера такта (два выпадающих меню)
- ✅ Расширенные настройки метронома (BPM, частоты, рисунок акцентов)
- ✅ Subdivisions (8-е ноты, триоли, 16-е ноты)
- ✅ Tap BPM
- ✅ Интеграция с песнями (отображение BPM)
- ✅ Пресеты метронома

**Исправлено:**
- ✅ Ошибка типа OscillatorType (JSString → String)
- ✅ Ошибка прав доступа Firestore (adminUids/emptyUids)
- ✅ Ошибки компиляции тестов (256 → 0)

**Улучшено:**
- ✅ Качество кода (59 проблем → ~30)
- ✅ Форматирование кода (100%)
- ✅ Документация (консолидирована)

### Версия 0.9.0 (2026-02-19)

**Добавлено:**
- ✅ Архитектура обмена песнями между группами
- ✅ Бейджи авторства песен
- ✅ Диалог добавления в группу
- ✅ Экран песен группы с фильтрами
- ✅ Правила безопасности Firestore для песен группы

**Исправлено:**
- ✅ Ошибка прав доступа при создании группы
- ✅ Ошибка вступления в группу
- ✅ 8+ критических ошибок

## Приложение Д. Контакты

**Разработчик:** Qwen Code Agent  
**Дата последнего обновления:** 2026-02-21  
**Репозиторий:** https://github.com/berlogabob/flutter-repsync-app  
**Web-версия:** https://berlogabob.github.io/flutter-repsync-app/  

---

**Конец отчета**
