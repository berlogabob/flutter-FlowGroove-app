# 🚀 RepSync Quick Deploy Reference

## Fastest Way - One Command!

```bash
# Deploy EVERYTHING (web, FTP, GitHub, Firebase, Android APK, git commit)
./scripts/deploy-stable
```

Or using Make:
```bash
make deploy
```

---

## What Gets Deployed?

| Platform | URL | Status |
|----------|-----|--------|
| **FTP** | https://flowgroove.app/ | ✅ Primary |
| **GitHub Pages** | https://berlogabob.github.io/flutter-FlowGroove-app/ | ✅ Backup |
| **Firebase** | https://repsync-app-8685c.web.app/ | ✅ Staging |
| **Android APK** | `build/app/outputs/flutter-apk/` | ✅ Release |

---

## Selective Deployment

```bash
# Skip Android (faster)
./scripts/deploy-all.sh --skip-android

# Skip FTP
./scripts/deploy-all.sh --skip-ftp

# Web only (FTP + GitHub + Firebase)
./scripts/deploy-all.sh --skip-android
```

---

## Manual Commands

```bash
# Build only
flutter build web

# FTP only
./scripts/deploy-to-flowgroove.sh

# GitHub Pages only  
npx gh-pages -d build/web

# Firebase only
firebase deploy --only hosting

# Android APK only
flutter build apk --release
```

---

## Makefile Shortcuts

```bash
make              # Show help
make deploy       # Deploy everything
make deploy-web   # Web platforms only
make build-all    # Build web + Android
make clean        # Clean builds
make test         # Run tests
make version      # Show version
make bump         # Bump build number
```

---

## After Deploy

1. ✅ Check https://flowgroove.app/ (wait 1-5 min for SSL)
2. ✅ Verify GitHub Pages loads
3. ✅ Test Firebase URL
4. ✅ Check APK was created
5. ✅ Verify git tag was created: `git tag -l`

---

## Troubleshooting

**Slow FTP?** Install lftp:
```bash
brew install lftp
```

**Firebase error?** Login first:
```bash
firebase login
```

**GitHub 404?** Wait 2-3 minutes for propagation

**APK fails?** Run:
```bash
flutter doctor
```

---

## Version Info

Current version is in `pubspec.yaml`:
```yaml
version: 0.13.1+167
```

Auto-updates `web/version.json` on deploy.

---

## Full Documentation

- [DEPLOYMENT_ALL_PLATFORMS.md](DEPLOYMENT_ALL_PLATFORMS.md) - Complete guide
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Detailed instructions
- [QUICK_SETUP_DEPLOYMENT.md](QUICK_SETUP_DEPLOYMENT.md) - Setup guide
