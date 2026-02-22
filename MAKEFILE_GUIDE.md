# Makefile Usage Guide
**Flutter RepSync App - Build Automation**

---

## QUICK START

### Deploy to GitHub Pages (Most Common)
```bash
make deploy
```

### Full Release (Web + Android + Git Tag)
```bash
make release
```

### Just Build Web
```bash
make build-web
```

---

## ALL COMMANDS

### Build Commands

| Command | Description |
|---------|-------------|
| `make build-web` | Build for web (GitHub Pages) |
| `make build-android` | Build Android APK |
| `make build-appbundle` | Build Android App Bundle (Play Store) |
| `make build-all` | Build for web and Android |

### Deploy Commands

| Command | Description |
|---------|-------------|
| `make deploy-web` | Build web + copy to docs/ |
| `make deploy` | Build web + copy to docs/ + commit + push |

### Release Commands

| Command | Description |
|---------|-------------|
| `make increment-version` | Increment build number (e.g., +1 → +2) |
| `make release` | Full release: increment + build all + commit + tag + push |
| `make release-web` | Quick web release: increment + build web + deploy |

### Utility Commands

| Command | Description |
|---------|-------------|
| `make version` | Show current and next version |
| `make clean` | Clean build artifacts |
| `make test` | Run all tests with coverage |
| `make analyze` | Run flutter analyze |
| `make info` | Show build info |
| `make deps` | Install dependencies |
| `make mocks` | Generate test mocks |
| `make release-notes` | Create release notes |

### Development Commands

| Command | Description |
|---------|-------------|
| `make run` | Run on connected device |
| `make run-web` | Run on Chrome (web) |
| `make run-android` | Run on Android device |
| `make watch` | Watch for changes (development) |

---

## COMMON WORKFLOWS

### Workflow 1: Quick Deploy to GitHub Pages

```bash
# 1. Make your changes
# 2. Deploy
make deploy

# That's it! GitHub Pages will update in 1-2 minutes
```

**What it does:**
1. ✅ Builds web with correct base-href
2. ✅ Copies to docs/
3. ✅ Commits changes
4. ✅ Pushes to GitHub

---

### Workflow 2: Full Release (Recommended)

```bash
# 1. Make your changes
# 2. Create new release
make release

# 3. Test the deployment
# 4. Upload APK to testers if needed
```

**What it does:**
1. ✅ Increments build number (+1 → +2)
2. ✅ Builds web (GitHub Pages)
3. ✅ Builds Android APK
4. ✅ Copies web to docs/
5. ✅ Commits changes
6. ✅ Creates git tag (v0.10.1+2)
7. ✅ Pushes everything

**Output:**
- Web: https://berlogabob.github.io/flutter-repsync-app/
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`
- Git tag: `v0.10.1+2`

---

### Workflow 3: Build Only (No Deploy)

```bash
# Build for testing
make build-web
make build-android

# Test locally
make run-android

# Deploy later
make deploy
```

---

### Workflow 4: Development

```bash
# Install dependencies
make deps

# Run on device with hot reload
flutter run

# Or run tests
make test

# Or analyze code
make analyze
```

---

## VERSION MANAGEMENT

### How Versioning Works

**Format:** `MAJOR.MINOR.PATCH+BUILD`

Example: `0.10.1+1`
- `0` - Major version
- `10` - Minor version
- `1` - Patch version
- `1` - Build number (auto-incremented)

### Manual Version Change

Edit `pubspec.yaml`:
```yaml
version: 0.10.1+2  # Change this line
```

### Auto-Increment

```bash
# Increment build number
make increment-version

# Current: 0.10.1+1
# New: 0.10.1+2
```

---

## EXAMPLES

### Example 1: First Deploy

```bash
# Check current version
make version
# Output: Current version: 0.10.1+1

# Deploy to GitHub Pages
make deploy

# Wait 1-2 minutes, then check:
# https://berlogabob.github.io/flutter-repsync-app/
```

### Example 2: Weekly Release

```bash
# You've made changes throughout the week
# Friday: Create release
make release

# Output:
# 📦 Current version: 0.10.1+1
# 📦 New version: 0.10.1+2
# 🔨 Building web app...
# ✅ Web build complete
# 🤖 Building Android APK...
# ✅ Android build complete
# 📦 Copying web build to docs/...
# ✅ Web build copied to docs/
# 💾 Committing release...
# 🏷️  Creating git tag...
# 🚀 Pushing to GitHub...
# 🎉 Release 0.10.1+2 complete!
```

### Example 3: Hotfix Deploy

```bash
# Quick fix deployed immediately
make increment-version
make deploy-web
git add docs/ pubspec.yaml
git commit -m "Hotfix: fix login issue"
git push
```

---

## TROUBLESHOOTING

### Problem: "make: command not found"

**Solution (macOS):**
```bash
xcode-select --install
```

**Solution (Windows):**
Install Make for Windows or use WSL.

**Solution (Linux):**
```bash
# Ubuntu/Debian
sudo apt-get install make

# Fedora
sudo dnf install make
```

---

### Problem: "sed: can't read"

**Solution (Linux):**
The Makefile uses macOS sed. For Linux, change:
```makefile
sed -i '' 's/...'  # macOS
```
To:
```makefile
sed -i 's/...'  # Linux
```

---

### Problem: Build fails with "base-href" error

**Solution:**
Make sure you're using the correct command:
```bash
make build-web  # Uses correct base-href automatically
```

NOT:
```bash
flutter build web  # Missing base-href!
```

---

### Problem: GitHub Pages shows old version

**Solution:**
1. Clear browser cache (Ctrl+Shift+Delete)
2. Or open in incognito mode
3. Wait 2-3 minutes for GitHub to deploy

---

## CUSTOMIZATION

### Change Repository Name

If your repo is not `flutter-repsync-app`, update the base-href:

**In Makefile:**
```makefile
build-web:
	flutter build web --release --base-href "/YOUR-REPO-NAME/"
```

### Add Custom Commands

Add to Makefile:
```makefile
my-custom-command:
	@echo "Running custom command..."
	@your-command-here
```

---

## QUICK REFERENCE

```bash
# Most common commands
make deploy          # Deploy to GitHub Pages
make release         # Full release cycle
make build-web       # Build for web
make build-android   # Build for Android
make version         # Show version
make clean           # Clean build
make test            # Run tests
make help            # Show all commands
```

---

**Last Updated:** 2026-02-23  
**Version:** 0.10.1+2
