# Аудит аватаров (людей и групп)

## Цель
Проверить корректность отображения аватаров пользователей и групп, их обновление без необходимости перезагрузки, а также убедиться, что аватары видимы всем участникам.

## 1. Общее наблюдение
В проекте используется несколько виджетов для отображения аватаров:
- `lib/widgets/user_avatar.dart`
- `lib/widgets/band_avatar.dart`
- `lib/widgets/greeting_card.dart`
- `lib/widgets/band_avatar.dart` (повторяется) 
- `lib/screens/profile_screen.dart` и `lib/screens/bands/the_band_screen.dart` – логика загрузки/обновления.
- `lib/services/avatar_function_service.dart` – серверные вызовы.

## 2. Проблемы и потенциальные риски
| № | Файл / участок кода | Проблема | Severity | Рекомендация |
|---|----------------------|----------|----------|--------------|
| 1 | `user_avatar.dart` и `band_avatar.dart` – `bool get _hasPhoto => photoURL != null && photoURL!.startsWith('http');` | Ошибочный fallback: если URL начинается с `https` — покрывается, но если URI будет `data:` или кастомный протокол, аватар не покажется. | Low | Использовать `Uri.tryParse(photoURL!).isAbsolute` вместо простого `startsWith('http')`.
| 2 | `user_avatar.dart` и `band_avatar.dart` – отсутствие `errorBuilder` у `NetworkImage`. | При любой ошибке загрузки (404, сетевой сбой) виджет будет просто пустым без индикатора. | Medium | Заменить `backgroundImage: _hasPhoto ? NetworkImage(photoURL!) : null` на `backgroundImage: _hasPhoto ? NetworkImage(photoURL!) : null, onBackgroundImageError: (_, __) => /* fallback to initials */` либо использовать `CachedNetworkImage` с placeholder.
| 3 | `greeting_card.dart` – `if (avatarPath == null || avatarPath!.isEmpty) return null;` без fallback‑иконки. | Пустой аватар без визуального индикатора, пользователь может подумать, что UI сломался. | Low | Возвращать `AssetImage('assets/avatar_placeholder.png')`.
| 4 | `profile_screen.dart` – после `AvatarFunctionService().importTelegramAvatar()` обновляется только локальная переменная `_avatarUrl`. Другие экраны (домашний, band) читают `user?.photoURL` из Firebase Auth, которое **не** обновляется автоматически. | Пользователь видит новый аватар только в профиле, остальные части UI продолжают показывать старый/пустой. | После успешного импорта вызвать `await FirebaseAuth.instance.currentUser!.updatePhotoURL(url);` **и** обновить поток `authStateChanges()` либо использовать `StreamProvider`/`Riverpod` для подписки на `FirebaseAuth.instance.authStateChanges()`.
| 5 | `the_band_screen.dart` – после изменения/удаления аватара вызывается `await AvatarFunctionService().setBandAvatar(...)`/`removeBandAvatar`. UI‑компоненты читают `band.photoURL` из локального `Band` объекта, полученного через `watchBand...`? В коде нет явного прослушивания изменений Firestore документа `bands/{bandId}`. | Члены группы могут не увидеть обновлённый аватар без перезапуска/переключения вкладки. | Переписать код, чтобы использовать `Stream<DocumentSnapshot>` (например `FirebaseFirestore.instance.collection('bands').doc(bandId).snapshots()`) и в UI подписываться через Riverpod `StreamProvider`. При изменении аватара Firestore уведомит всех.
| 6 | `avatar_function_service.dart` – отсутствие обработки `FirebaseFunctionsException` с кодом `deadline-exceeded` или `unavailable`. | При сетевых проблемах пользователь получит непонятную ошибку без указания, что аватар не загрузился. | Добавить маппинг этих кодов в `_mapBandAvatarError` с `ApiError.network`.
| 7 | `user_avatar.dart` – импорт `package:flutter/material.dart` без `package:cached_network_image/cached_network_image.dart`. При большом количестве аватаров каждый запрос повторяется, ухудшая производительность. | Снижение скорости и лишний трафик. | Перейти на `CachedNetworkImage` с кэшированием и placeholder.
| 8 | `band_avatar.dart` и `user_avatar.dart` – `final String? photoURL;` без указания nullable в Firestore модели. Если поле `photoURL` отсутствует в документе, `null` будет, но при чтении/записи могут возникать `null`‑исключения в других частях кода (например, `SongSuggestionService`). | Потенциальные краши. | Убедиться, что все места чтения `photoURL` проверяют на `null` (использовать `?.` и `??`).
| 9 | Нет единых тестов UI‑компонентов, проверяющих отображение аватара при разных состояниях (null, ошибка, обновление). | Регрессия может незаметно сломать отображение. | Добавить widget‑тесты для `UserAvatar`, `BandAvatar`, `GreetingCard` с мок‑объектами `NetworkImage` и `ImageErrorListener`.
| 10 | При загрузке аватара в `profile_screen.dart` используется `await AvatarFunctionService().importTelegramAvatar();` без индикации прогресса. Пользователь может думать, что приложение зависло. | Плохой UX. | Добавить `CircularProgressIndicator` во время загрузки и блокировать UI.

## 3. Приоритет исправлений
1. **Critical** – Обновление глобального состояния пользователя после изменения аватара (пункт 4). 
2. **High** – Подписка на изменения Firestore документа группы (пункт 5). 
3. **Medium** – Обработка ошибок загрузки NetworkImage (пункт 2). 
4. **Low** – Замена `startsWith('http')` на более надёжную проверку URI (пункт 1) и добавление placeholder‑изображения (пункт 3).
5. **Low** – Добавление кэширования и тестов (пункты 7, 9).

## 4. Доказательства
- Поиск по `avatarPath` в `greeting_card.dart` показал отсутствие fallback‑иконки (строка 115‑124).
- В `profile_screen.dart` после импорта Telegram аватара вызывается только локальная переменная `_avatarUrl` (строка 261). 
- В `the_band_screen.dart` нет подписки на `band.photoURL` изменения (поиск показывает только статический `avatarPath: _liveBand().photoURL`).

## 5. Как проверить исправления
1. После исправления `profile_screen.dart` обновить `photoURL` через `FirebaseAuth.instance.currentUser!.updatePhotoURL(url)` и проверить, что `HomeScreen` автоматически меняет аватар без перезапуска.
2. В `BandScreen` заменить получение band данных на `watchDocument` и убедиться, что после изменения аватара в любой вкладке все члены видят новый аватар сразу.
3. Написать widget‑тест, где `NetworkImage` бросает ошибку и убедиться, что показывается placeholder.

---
*Отчёт создан в рамках репозитория‑аудита. Для полной аудиторской картины см. `audit_reports/2026-06-18-audit-report.md`*