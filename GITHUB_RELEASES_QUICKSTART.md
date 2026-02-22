# Makefile GitHub Releases - Quick Start

## ✅ ЧТО ДОБАВЛЕНО

Теперь `make release` **автоматически создает GitHub Release** с APK и AAB файлами!

---

## 🚀 БЫСТРЫЙ СТАРТ

### 1. Установите GitHub CLI (если еще нет)

```bash
# macOS
brew install gh

# Linux
sudo apt install gh

# Windows
winget install GitHub.cli
```

### 2. Аутентифицируйтесь

```bash
gh auth login
# Следуйте инструкциям в браузере
```

### 3. Создайте релиз

```bash
make release
```

**Все!** Через 2-3 минуты у вас будет:
- ✅ Web на GitHub Pages
- ✅ Git tag
- ✅ **GitHub Release с APK и AAB**

---

## 📦 КОМАНДЫ

### Полный релиз (все включено)
```bash
make release
```
- Increment version
- Build web + Android
- Deploy to GitHub Pages
- Commit + tag + push
- **Create GitHub Release**

### Только GitHub Release
```bash
make github-release
```
- Создает GitHub Release
- Загружает APK + AAB

### Заметки к релизу
```bash
make release-notes
```
- Генерирует RELEASE_NOTES.md из git log

---

## 🎯 ПРИМЕР ВЫВОДА

```bash
$ make release

📦 Current version: 0.10.1+1
📦 New version: 0.10.1+2
✅ Version updated in pubspec.yaml

🔨 Building web app...
✅ Web build complete

🤖 Building Android APK...
✅ Android build complete

🤖 Building Android App Bundle...
✅ Android App Bundle complete

📦 Copying web build to docs/...
✅ Web build copied to docs/

💾 Committing release...

🏷️  Creating git tag...

🚀 Pushing to GitHub...

📱 Creating GitHub Release...
✅ GitHub Release created!
🔗 https://github.com/berlogabob/flutter-repsync-app/releases/tag/v0.10.1+2

🎉 Release 0.10.1+2 complete!

📱 Artifacts:
   Web: https://berlogabob.github.io/flutter-repsync-app/
   Android APK: build/app/outputs/flutter-apk/app-release.apk
   Android AAB: build/app/outputs/bundle/release/app-release.aab
   GitHub Release: https://github.com/berlogabob/flutter-repsync-app/releases/tag/v0.10.1+2
```

---

## 📋 ЧЕКЛИСТ ПЕРЕД РЕЛИЗОМ

- [ ] GitHub CLI установлен (`gh --version`)
- [ ] GitHub CLI аутентифицирован (`gh auth status`)
- [ ] Все тесты проходят (`make test`)
- [ ] Flutter analyze clean (`make analyze`)
- [ ] CHANGELOG.md обновлен

---

## 🔧 TROUBLESHOOTING

### "gh: command not found"
```bash
brew install gh  # macOS
sudo apt install gh  # Linux
```

### "gh: not authenticated"
```bash
gh auth login
```

### "Release already exists"
```bash
gh release delete v0.10.1+2 --cleanup-tag --yes
make increment-version
make release
```

---

## 📖 ПОДРОБНАЯ ДОКУМЕНТАЦИЯ

См. **docs/GITHUB_RELEASES_GUIDE.md** для полной документации.

---

**Last Updated:** 2026-02-23
