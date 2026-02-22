# DEPLOYMENT GUIDE - GitHub Pages
**Flutter RepSync App**

---

## ПРОБЛЕМА: Белая страница после деплоя

**Причина:** Неправильный `base-href` в `index.html`

GitHub Pages обслуживает сайт из подпапки:
```
https://berlogabob.github.io/flutter-repsync-app/
                    ^^^^^^^^^^^^^^^^^^^^^^^^
                    Это должно быть в base-href!
```

---

## ПРАВИЛЬНАЯ КОМАНДА ДЛЯ СБОРКИ

### ❌ НЕПРАВИЛЬНО (белая страница):
```bash
flutter build web --release
# base-href будет "/" - НЕ РАБОТАЕТ на GitHub Pages
```

### ✅ ПРАВИЛЬНО (работает):
```bash
flutter build web --release --base-href "/flutter-repsync-app/"
# base-href будет "/flutter-repsync-app/" - РАБОТАЕТ!
```

---

## ПОЛНЫЙ ПРОЦЕСС ДЕПЛОЯ

### Шаг 1: Сборка
```bash
cd /Users/berloga/Documents/GitHub/flutter_repsync_app

flutter build web --release --base-href "/flutter-repsync-app/"
```

### Шаг 2: Копирование в docs/
```bash
cp -r build/web/* docs/
```

### Шаг 3: Коммит и пуш
```bash
git add docs/
git commit -m "Deploy web build"
git push origin main
```

### Шаг 4: Проверка
GitHub Pages автоматически задеплоит через 1-2 минуты.

**URL:** https://berlogabob.github.io/flutter-repsync-app/

---

## АВТОМАТИЗАЦИЯ (Makefile)

Создайте `Makefile` в корне проекта:

```makefile
.PHONY: deploy

deploy:
	@echo "🔨 Building web app..."
	flutter build web --release --base-href "/flutter-repsync-app/"
	
	@echo "📦 Copying to docs/..."
	cp -r build/web/* docs/
	
	@echo "✅ Build complete! Commit and push to deploy:"
	@echo "   git add docs/"
	@echo "   git commit -m 'Deploy web build'"
	@echo "   git push origin main"
```

**Использование:**
```bash
make deploy
```

---

## ПРОВЕРКА ПЕРЕД ДЕПЛОЕМ

### 1. Проверьте base-href:
```bash
grep "base href" build/web/index.html
# Должно быть: <base href="/flutter-repsync-app/" />
```

### 2. Проверьте наличие файлов:
```bash
ls -la build/web/
# Должны быть: index.html, flutter_bootstrap.js, канвас-кит и др.
```

### 3. Локальный тест:
```bash
cd build/web
python3 -m http.server 8080
# Откройте: http://localhost:8080/flutter-repsync-app/
```

---

## ВОЗМОЖНЫЕ ПРОБЛЕМЫ И РЕШЕНИЯ

### Проблема 1: Белая страница
**Решение:** Проверьте base-href
```bash
grep "base href" docs/index.html
# Должно совпадать с именем репозитория!
```

### Проблема 2: 404 ошибка
**Решение:** Убедитесь что GitHub Pages включен:
1. GitHub → Settings → Pages
2. Source: Deploy from a branch
3. Branch: main
4. Folder: /docs (root)
5. Save

### Проблема 3: Кэш браузера
**Решение:** Очистите кэш:
```bash
# Chrome: Ctrl+Shift+Delete
# Или откройте в инкогнито режиме
```

### Проблема 4: CanvasKit не загружается
**Решение:** Используйте HTML рендерер:
```bash
flutter build web --release --base-href "/flutter-repsync-app/" --web-renderer html
```

---

## CI/CD АВТОМАТИЗАЦИЯ (GitHub Actions)

Создайте `.github/workflows/deploy.yml`:

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Build web
        run: flutter build web --release --base-href "/flutter-repsync-app/"
      
      - name: Deploy to docs
        run: |
          cp -r build/web/* docs/
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add docs/
          git commit -m "Auto-deploy web build"
          git push
```

---

## СТАТУС ДЕПЛОЯ

| Параметр | Значение |
|----------|----------|
| **Repository** | berlogabob/flutter-repsync-app |
| **GitHub Pages URL** | https://berlogabob.github.io/flutter-repsync-app/ |
| **Source Branch** | main |
| **Source Folder** | /docs (root) |
| **Base Href** | /flutter-repsync-app/ |

---

## ЧЕКЛИСТ ПЕРЕД ДЕПЛОЕМ

- [ ] Сборка с правильным base-href
- [ ] Файлы скопированы в docs/
- [ ] GitHub Pages включен в настройках репозитория
- [ ] Source установлен в "Deploy from a branch"
- [ ] Branch: main, Folder: /docs
- [ ] Коммит и пуш сделаны
- [ ] Деплой проверен в браузере

---

**Last Updated:** 2026-02-23  
**Version:** 0.10.1+1
