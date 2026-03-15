firebase_analytics.md
**Техническое задание (ТЗ)**  
**Подключение и настройка аналитики посещений для веб-приложения FlowGroove**

**Дата:** 11 марта 2026  
**Проект:** FlowGroove (Flutter Web, Firebase Hosting + Firestore)  
**Цель:** Получить статистику посещений, уникальных пользователей, сессий и просмотров экранов в реальном времени и за периоды.

### 1. Текущая ситуация
- Приложение развернуто по адресу: https://flowgroove.app
- Проект в Firebase: repsync-app-8685c
- В дашборде Firebase Analytics → Overview для web-приложения (web:MjhkY2M1MzktMWNmMy00ZWI3LTg2NjctOWJmYjgwMTBhZjk4) данные отсутствуют полностью (пустой дашборд, нет событий, пользователей, сессий).

### 2. Требуемый результат
- В Firebase Analytics (и желательно в связанном Google Analytics 4) должны отображаться:
  - Количество уникальных пользователей (Users)
  - Количество сессий (Sessions)
  - Просмотры экранов / страниц (screen_view / page_view)
  - Базовые метрики: страны, устройства, источники трафика
  - Данные в Realtime (в течение секунд/минут после действий пользователя)
- Минимальная задержка появления данных — до 1 часа после первого события.

### 3. Требования к реализации

**3.1. Зависимости (pubspec.yaml)**
- Добавить (или обновить до актуальной версии на март 2026):
  ```yaml
  firebase_core: ^3.0.0  # или новее
  firebase_analytics: ^11.3.0  # или новее
  ```

**3.2. Инициализация и автоматический трекинг**
- В main.dart выполнить корректную инициализацию Firebase и добавить observer для автоматического логирования смены экранов:
  ```dart
  import 'package:firebase_core/firebase_core.dart';
  import 'package:firebase_analytics/firebase_analytics.dart';
  import 'package:firebase_analytics/observer.dart';

  // ...

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final analytics = FirebaseAnalytics.instance;

    runApp(
      MaterialApp.router(
        // или ваш виджет с go_router / auto_route
        routerConfig: router,
        navigatorObservers: [
          FirebaseAnalyticsObserver(analytics: analytics),
        ],
      ),
    );
  }
  ```

**3.3. Ручное логирование событий (для теста и надёжности)**
- Добавить хотя бы 1–2 тестовых события + логирование screen_view в ключевых местах приложения (например, после входа, на главной, при открытии сетлиста):
  ```dart
  // Пример: после загрузки главной страницы
  await FirebaseAnalytics.instance.logScreenView(
    screenName: 'HomeScreen',
    screenClass: 'HomePage',
  );

  // Или кастомное событие
  await FirebaseAnalytics.instance.logEvent(
    name: 'app_open_test',
    parameters: {'source': 'manual'},
  );
  ```

**3.4. Деплой и тестирование**
- Собрать и задеплоить релизную версию:
  ```bash
  flutter build web --release
  firebase deploy --only hosting
  ```
- Открыть приложение в режиме инкогнито в браузере.
- Выполнить несколько действий (логин, создание группы, добавление песни, переход по экранам).
- Подождать 10–60 минут.

**3.5. Места проверки данных**
- Firebase Console → Analytics → **Realtime** (показывает события в живую)
- Firebase Console → Analytics → **Events** → искать screen_view, page_view, app_open_test и т.д.
- Firebase Console → Analytics → **Dashboard** / **Overview**
- Кнопка «View in Google Analytics» → Reports → Engagement → Overview (Users, Sessions, Page views)

### 4. Критерии приёмки
- В Realtime появляются события в течение 1–5 минут после действий пользователя.
- Через 1–24 часа в Events и Dashboard видны:
  - минимум 1–5 уникальных пользователей
  - события screen_view / page_view
  - сессии и базовая статистика
- Нет ошибок в консоли браузера, связанных с аналитикой (F12 → Console / Network → запросы на collect).

### 5. Дополнительные пожелания (опционально, после базовой настройки)
- Добавить логирование ключевых событий приложения:
  - login_success
  - band_created
  - song_added
  - setlist_exported
  - metronome_started
- Настроить User Properties (например, role: musician / band_leader)
- Связать с Google Analytics 4 для более детальной отчётности (если нужно).

Готов приступить к реализации.