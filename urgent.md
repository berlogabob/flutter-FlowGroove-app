

### Шаг 1: В проекте переименуй файл
В папке `assets/`:
- `.env` → `env.json`  
(можно назвать `config.json` — как угодно, главное без точки в начале)

### Шаг 2: Обнови pubspec.yaml
Найди раздел `assets:` и поменяй:

```yaml
flutter:
  assets:
    - assets/env.json   # ← было assets/.env
```

Сохрани.

### Шаг 3: Поменяй код загрузки (в main.dart или где ты загружаешь)
Найди строку примерно такую:

```dart
await dotenv.load(fileName: "assets/.env");
```

Поменяй на:

```dart
await dotenv.load(fileName: "assets/env.json");
```

(если используешь пакет `flutter_dotenv`)

Сохрани файл.

### Шаг 4: Перебилдь и залей заново

```bash
flutter clean
flutter pub get
flutter build web
```

