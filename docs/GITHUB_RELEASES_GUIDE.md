# GitHub Releases Guide
**Flutter RepSync App - Automated Release Deployment**

---

## OVERVIEW

The Makefile now includes **automatic GitHub Releases** creation. When you run `make release`, it will:

1. ✅ Increment build number
2. ✅ Build web (GitHub Pages)
3. ✅ Build Android (APK + AAB)
4. ✅ Deploy web to docs/
5. ✅ Commit & push
6. ✅ Create git tag
7. ✅ **Create GitHub Release with APK + AAB artifacts**

---

## PREREQUISITES

### GitHub CLI (gh) Required

To use automatic GitHub Releases, you need **GitHub CLI** installed and authenticated.

### Installation

#### macOS
```bash
brew install gh
gh auth login
```

#### Linux
```bash
# Debian/Ubuntu
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Fedora/RHEL
sudo dnf install 'dnf-command(config-manager)'
sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
sudo dnf install gh

gh auth login
```

#### Windows
```bash
# Using winget
winget install GitHub.cli

# Or download from: https://github.com/cli/cli/releases

gh auth login
```

### Authentication

```bash
gh auth login
# Follow prompts:
# - GitHub.com
# - HTTPS
# - Login with browser
# - Authorize GitHub CLI
```

---

## USAGE

### Full Release (Recommended)

```bash
make release
```

**What it does:**
1. Increments build number (0.10.1+1 → 0.10.1+2)
2. Builds web with correct base-href
3. Builds Android APK
4. Builds Android App Bundle (AAB)
5. Copies web to docs/
6. Commits changes
7. Creates git tag
8. Pushes to GitHub
9. **Creates GitHub Release with APK + AAB**

**Output:**
```
🎉 Release 0.10.1+2 complete!

📱 Artifacts:
   Web: https://berlogabob.github.io/flutter-repsync-app/
   Android APK: build/app/outputs/flutter-apk/app-release.apk
   Android AAB: build/app/outputs/bundle/release/app-release.aab
   GitHub Release: https://github.com/berlogabob/flutter-repsync-app/releases/tag/v0.10.1+2
```

---

### GitHub Release Only

If you already built and just want to create release:

```bash
make github-release
```

**Requirements:**
- APK and AAB must exist in `build/` folder
- Git tag must exist

**What it does:**
- Creates GitHub Release
- Uploads APK as `android-apk`
- Uploads AAB as `android-aab`
- Uses RELEASE_NOTES.md for description

---

### Generate Release Notes

```bash
make release-notes
```

**What it does:**
- Creates `RELEASE_NOTES.md` from git log
- Lists last 20 commits
- Includes changelog link

**Example output:**
```markdown
# Release 0.10.1+2

**Date:** 2026-02-23

## What's Changed

- Update Mono Pulse theme
- Fix base-href for web build
- Add Makefile automation
- ...

## Full Changelog

https://github.com/berlogabob/flutter-repsync-app/compare/v0.10.1+1...v0.10.1+2
```

---

## GITHUB RELEASE FORMAT

### Release Tag
```
v0.10.1+2
```

### Release Title
```
Release 0.10.1+2
```

### Release Assets
```
app-release.apk (labeled as "android-apk")
app-release.aab (labeled as "android-aab")
```

### Release Notes
Auto-generated from:
- `RELEASE_NOTES.md` (if exists)
- Or: `Release 0.10.1+2 - YYYY-MM-DD`

---

## WORKFLOWS

### Workflow 1: Complete Release

```bash
# 1. Make your changes
git add .
git commit -m "New features"

# 2. Create release
make release

# 3. Test
# - Web: https://berlogabob.github.io/flutter-repsync-app/
# - GitHub Release: Check artifacts uploaded
```

---

### Workflow 2: Manual Release

```bash
# 1. Build manually
flutter build web --release --base-href "/flutter-repsync-app/"
flutter build apk --release
flutter build appbundle --release

# 2. Create release notes
make release-notes

# 3. Edit RELEASE_NOTES.md if needed
nano RELEASE_NOTES.md

# 4. Create GitHub Release
make github-release
```

---

### Workflow 3: Hotfix Release

```bash
# 1. Quick fix
git add .
git commit -m "Hotfix: critical bug"

# 2. Release
make release

# 3. GitHub Release created automatically
```

---

## TROUBLESHOOTING

### Problem: "gh: command not found"

**Solution:**
```bash
# Install GitHub CLI
brew install gh  # macOS
# or
sudo apt install gh  # Linux

# Authenticate
gh auth login
```

---

### Problem: "gh: not authenticated"

**Solution:**
```bash
gh auth login
```

---

### Problem: "Release already exists"

**Solution:**
```bash
# Delete existing release
gh release delete v0.10.1+2 --cleanup-tag --yes

# Or use different version
make increment-version
make release
```

---

### Problem: "APK/AAB not found"

**Solution:**
```bash
# Build first
make build-android

# Or build manually
flutter build apk --release
flutter build appbundle --release

# Then create release
make github-release
```

---

### Problem: "File already exists in release"

**Solution:**
```bash
# Remove from existing release
gh release upload v0.10.1+2 --clobber \
  build/app/outputs/flutter-apk/app-release.apk \
  build/app/outputs/bundle/release/app-release.aab
```

---

## MANUAL GITHUB RELEASE

If you prefer manual release:

### 1. Build
```bash
flutter build web --release --base-href "/flutter-repsync-app/"
flutter build apk --release
flutter build appbundle --release
```

### 2. Create Git Tag
```bash
git tag -a "v0.10.1+2" -m "Release 0.10.1+2"
git push origin v0.10.1+2
```

### 3. Upload to GitHub Releases

1. Go to: https://github.com/berlogabob/flutter-repsync-app/releases/new
2. Tag: `v0.10.1+2`
3. Title: `Release 0.10.1+2`
4. Description: Add release notes
5. Upload binaries:
   - `build/app/outputs/flutter-apk/app-release.apk`
   - `build/app/outputs/bundle/release/app-release.aab`
6. Click "Publish release"

---

## RELEASE CHECKLIST

Before releasing:

- [ ] All tests passing
- [ ] Flutter analyze clean
- [ ] Web build tested
- [ ] Android APK tested on device
- [ ] Version incremented
- [ ] CHANGELOG.md updated
- [ ] Git tag created
- [ ] GitHub Release created with artifacts

---

## EXAMPLES

### Example 1: Regular Release

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

### Example 2: Release Notes

```bash
$ make release-notes

📝 Creating release notes...
✅ Release notes created: RELEASE_NOTES.md

# Release 0.10.1+2

**Date:** 2026-02-23

## What's Changed

- a1b2c3d Update Mono Pulse theme
- d4e5f6g Fix base-href for web build
- g7h8i9j Add Makefile automation
- j0k1l2m Add profile button
- ...

## Full Changelog

https://github.com/berlogabob/flutter-repsync-app/compare/v0.10.1+1...v0.10.1+2
```

---

## LINKS

- **GitHub CLI:** https://cli.github.com/
- **GitHub Releases:** https://docs.github.com/en/repositories/releasing-projects-on-github
- **Flutter Build:** https://docs.flutter.dev/deployment

---

**Last Updated:** 2026-02-23  
**Version:** 0.10.1+2
