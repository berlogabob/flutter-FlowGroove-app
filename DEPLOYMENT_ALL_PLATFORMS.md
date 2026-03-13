# RepSync Deployment Guide

## Quick Deploy (All Platforms)

### One-Command Deploy Everything

```bash
./scripts/deploy-stable
```

This single command will:
- ✅ Build web version
- ✅ Deploy to **FTP** (flowgroove.app)
- ✅ Deploy to **GitHub Pages**
- ✅ Deploy to **Firebase Hosting**
- ✅ Build **Android APK**
- ✅ **Git commit** with version tag
- ✅ **Push** to GitHub

### Advanced Deployment Options

```bash
# Deploy to all platforms
./scripts/deploy-all.sh

# Skip Android build (faster)
./scripts/deploy-all.sh --skip-android

# Skip FTP deployment
./scripts/deploy-all.sh --skip-ftp

# Skip GitHub Pages
./scripts/deploy-all.sh --skip-github

# Skip Firebase
./scripts/deploy-all.sh --skip-firebase

# Skip multiple platforms
./scripts/deploy-all.sh --skip-android --skip-ftp
```

## Manual Platform-Specific Deploys

### Web Build Only

```bash
flutter build web
```

### FTP Deployment Only

```bash
./scripts/deploy-to-flowgroove.sh
```

### GitHub Pages Only

```bash
# Using gh-pages package
npx gh-pages -d build/web

# Or using git
git subtree push --prefix build/web origin gh-pages
```

### Firebase Hosting Only

```bash
firebase deploy --only hosting
```

### Android APK Only

```bash
flutter build apk --release
```

APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

## Configuration

### FTP Credentials

Create `.ftp-env` file (already in `.gitignore`):

```bash
FTP_HOST=194.39.124.68
FTP_USER=sounding
FTP_PASS=your_password_here
REMOTE_DIR=flowgroove.app
```

Or use environment variables:

```bash
export FTP_USER=sounding
export FTP_PASS=your_password_here
```

### Firebase Setup

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login:
   ```bash
   firebase login
   ```

3. Deploy:
   ```bash
   firebase deploy --only hosting
   ```

### GitHub Pages Setup

The script automatically handles GitHub Pages deployment. It will:
- Create `gh-pages` branch if it doesn't exist
- Push build files to the branch
- Update your GitHub Pages site

## Version Management

The deployment script automatically:
- Reads version from `pubspec.yaml`
- Updates `web/version.json` with build timestamp
- Creates git tag (e.g., `v0.13.1+167`)
- Commits with deployment info

## Deployment URLs

After deployment, your app will be available at:

| Platform | URL |
|----------|-----|
| **FTP (Primary)** | https://flowgroove.app/ |
| **GitHub Pages** | https://berlogabob.github.io/flutter-FlowGroove-app/ |
| **Firebase** | https://repsync-app-8685c.web.app/ |
| **Android APK** | `build/app/outputs/flutter-apk/app-release.apk` |

## Troubleshooting

### lftp not found (FTP deployment slow)

Install lftp for faster FTP deployments:

```bash
# macOS
brew install lftp

# Linux
sudo apt-get install lftp
```

### Firebase CLI not found

```bash
npm install -g firebase-tools
```

### Android build fails

Make sure Android SDK is set up:

```bash
flutter doctor
flutter config --android-sdk=/path/to/android/sdk
```

### GitHub Pages 404

Wait a few minutes for GitHub Pages to propagate. Check:
- Settings → Pages in your GitHub repo
- Ensure source is set to `gh-pages` branch

### FTP Connection Fails

Check your internet connection and FTP credentials. Try:

```bash
# Test FTP connection
lftp -u $FTP_USER,$FTP_PASS $FTP_HOST
```

## Automated Deployment (CI/CD)

For automated deployments on git push, see `.github/workflows/` (future enhancement).

## Release Checklist

Before deploying to production:

- [ ] Test on local device
- [ ] Test on web (localhost)
- [ ] Check version number in `pubspec.yaml`
- [ ] Run `flutter analyze`
- [ ] Run tests: `flutter test`
- [ ] Update CHANGELOG.md (if applicable)
- [ ] Deploy to staging first (Firebase)
- [ ] Deploy to production (FTP + GitHub)
- [ ] Verify all platforms
- [ ] Create release notes on GitHub

## Rollback

If something goes wrong:

```bash
# Revert to previous git tag
git checkout v0.13.1+166  # previous version
./scripts/deploy-stable   # redeploy
```

Or restore from GitHub releases.

## Support

For deployment issues, check:
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Detailed deployment instructions
- [QUICK_SETUP_DEPLOYMENT.md](QUICK_SETUP_DEPLOYMENT.md) - Quick setup guide
- [Firebase Console](https://console.firebase.google.com/project/repsync-app-8685c)
