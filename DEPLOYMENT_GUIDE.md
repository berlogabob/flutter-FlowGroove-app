# FlowGroove Deployment Guide

**Last Updated:** April 15, 2026
**Version:** 0.13.4+183
**Configuration System:** Modern Environment Variable Injection ✅
**Status:** ✅ PRODUCTION READY (Hugo + Flutter)

---

## 🚀 Quick Start

### Production Deployment (FTP - flowgroove.app)

**Option 1: Local Development (using .env file)**
```bash
# 1. First time setup (only once)
cp .env.example .env
# Edit .env with your credentials

# 2. Deploy
make deploy-stable
```

**Option 2: CI/CD (using GitHub Actions)**
```bash
# 1. Set secrets in GitHub Repository Settings
# Go to: Settings → Secrets and variables → Actions

# 2. Push to second01 branch (automated deployment)
git push origin second01

# Or trigger manually: Actions → "Deploy Test" → Run workflow
```

### Test Deployment (GitHub Pages)

```bash
# 1. No setup required - uses demo config
make deploy-test

# 2. Test in 2 minutes at:
# https://berlogabob.github.io/flutter-FlowGroove-app/
```

**Note:** Demo config includes valid Firebase key. Spotify/Twitter disabled but app fully functional.

---

## 📋 Pre-Deployment Checklist

### Required Credentials

Before deploying, ensure you have:

1. **Firebase API Key**
   - Get from: https://console.firebase.google.com
   - Project Settings → Your apps → Web app

2. **Spotify API Credentials**
   - Get from: https://developer.spotify.com/dashboard
   - Create an app to get Client ID and Client Secret
   - **PRODUCTION:** Use backend proxy (see `docs/SECURITY_BEST_PRACTICES.md`)

3. **Twitter/X API Credentials** (optional)
   - Get from: https://developer.twitter.com/en/portal/dashboard

4. **Track Analysis API Key** (optional)
   - Get from: https://rapidapi.com/soundnet-soundnet-default/api/track-analysis
   - Free tier: 100 requests/month

5. **FTP Credentials** (for production only)
   - FTP_HOST, FTP_USER, FTP_PASS, FTP_DIR
   - Provided by your hosting provider

---

## 🔧 Setup Instructions

### Step 1: Create .env File

```bash
cp .env.example .env
```

Edit `.env` file with your credentials:

```bash
# Firebase Configuration
FIREBASE_API_KEY=your_actual_firebase_key_here

# Spotify API Credentials
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret

# Twitter/X API Credentials (optional)
TWITTER_API_KEY=your_twitter_api_key
TWITTER_API_SECRET=your_twitter_api_secret

# Track Analysis API (optional)
TRACK_ANALYSIS_API_KEY=your_rapidapi_key

# Backend proxy URL (production recommended)
# SPOTIFY_PROXY_URL=https://your-backend.com/api/spotify
```

### Step 2: Verify Configuration

```bash
# This will validate your .env and create web/config.js
./scripts/inject-web-config.sh
```

Expected output:
```
✅ .env file found
✅ web/config.js created successfully
```

---

## 📦 Deployment Commands

### Production: FTP Deployment

```bash
make deploy-stable
```

**What this does:**
1. ✅ Validates `.env` file exists
2. ✅ Builds Hugo landing page with `hugo --baseURL "https://flowgroove.app/"`
3. ✅ Injects credentials into `web/config.js`
4. ✅ Updates `version.json` with current version
5. ✅ Builds Flutter web app with `flutter build web --release --base-href "/app/"`
6. ✅ Copies `config.js` to `build/web/`
7. ✅ Uploads Hugo to FTP root (`flowgroove.app/`)
8. ✅ Uploads Flutter to FTP `/app/` (`flowgroove.app/app/`)

**Expected duration:** 5-8 minutes
**Landing URL:** https://flowgroove.app/
**App URL:** https://flowgroove.app/app/
**SSL propagation:** 1-5 minutes

---

### Test: GitHub Pages Deployment

```bash
make deploy-test
```

**What this does:**
1. ✅ Validates `.env` file exists
2. ✅ Injects credentials into `web/config.js`
3. ✅ Updates `version.json` with current version
4. ✅ Builds web app with subdirectory base-href
5. ✅ Copies `config.js` to `build/web/`
6. ✅ Copies build to `docs/` folder
7. ✅ Preserves existing `docs/config.js` (doesn't delete secrets)
8. ✅ Commits and pushes to `second01` branch

**Expected duration:** 2-3 minutes  
**Test URL:** https://berlogabob.github.io/flutter-FlowGroove-app/  
**GitHub Pages build:** 1-2 minutes

---

## 🔒 Security Best Practices

### ✅ DO:
- Keep `.env` file in `.gitignore` (already configured)
- Keep `web/config.js` in `.gitignore` (already configured)
- Keep `docs/config.js` in `.gitignore` (already configured)
- Use environment variables for credentials
- Use `SPOTIFY_PROXY_URL` for production (recommended)

### ❌ NEVER:
- Commit `.env` file to git
- Commit `config.js` files to git
- Share your credentials publicly
- Use production credentials in test deployments
- Add `.env` to `pubspec.yaml` assets

---

## 🛠️ Troubleshooting

### Problem: "❌ ERROR: .env file not found!"

**Solution:**
```bash
cp .env.example .env
# Edit .env with your credentials
make deploy-stable
```

---

### Problem: "⚠️ WARNING: The following required variables are missing"

**Solution:**
1. Open `.env` file
2. Replace `REPLACE_ME_*` placeholders with actual values
3. Save and run deployment again

---

### Problem: "White screen after deployment"

**Possible causes:**
1. `config.js` not in `build/web/` folder
2. Credentials are placeholders (REPLACE_ME_*)
3. Firebase not initialized properly

**Solution:**
```bash
# Verify config.js exists
ls -la build/web/config.js

# Check credentials are set (not placeholders)
cat web/config.js | grep -E "FIREBASE|SPOTIFY"

# Rebuild and redeploy
make deploy-stable
```

---

### Problem: "FTP upload fails"

**Check:**
1. FTP credentials in `.env` are correct
2. FTP server is accessible
3. FTP directory path is correct

**Test FTP connection:**
```bash
lftp -c "open -u 'YOUR_USER','YOUR_PASS' YOUR_HOST"
```

---

### Problem: "GitHub Pages shows old version"

**Solution:**
```bash
# Force rebuild
rm -rf build/web
make deploy-test

# Hard refresh browser: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
```

---

## 📊 Build Artifacts

### What Gets Built

**Hugo:**
```
site/public/
├── index.html              # Hugo landing page
├── about/                  # About page
├── faq/                    # FAQ page
├── blog/                   # Blog posts
├── images/                 # Images & favicon
└── assets/                 # CSS, JS
```

**Flutter:**
```
build/web/
├── index.html              # Main HTML file
├── flutter_bootstrap.js    # Flutter loader
├── main.dart.js            # Compiled Flutter app (~5MB)
├── config.js               # ⚠️ Contains secrets - NOT in git
├── manifest.json           # PWA manifest
├── assets/                 # App assets
└── canvaskit/              # Graphics library
```

### What Gets Deployed

**Production (FTP):**
- `site/public/*` → FTP root (`flowgroove.app/`) — Hugo landing page
- `build/web/*` → FTP `/app/` (`flowgroove.app/app/`) — Flutter app
- `config.js` → `/app/config.js` (for Flutter)

**Test (GitHub Pages):**
- Hugo + Flutter → `docs/` folder on `second01` branch
- Hugo: `docs/` (root)
- Flutter: `docs/app/` (subdirectory)
- `docs/config.js` preserved between deployments

---

## 🔄 Version History

### v0.13.4+183 (Current — April 15, 2026)
- ✅ Hugo landing page now included in production FTP deploy
- ✅ `make deploy-stable` deploys Hugo (`flowgroove.app/`) + Flutter (`flowgroove.app/app/`)
- ✅ Health check validates both landing page and app URLs
- ✅ Post-MVP tuner features (regional instruments, custom tuning editor)
- ✅ Auto/manual note detection
- ✅ Stage mode with auto-hide UI
- ✅ Haptic feedback system
- ✅ Wakelock support
- ✅ Song autocomplete provider
- ✅ Test suite: 1718 passing, 50 failing, 291 skipped
- ✅ 11 new tuner widgets
- ✅ Instrument/tuning definitions (assets/data/tunings.json)

### v0.13.4+179
- ✅ Automated config injection at build time
- ✅ Pre-deployment validation
- ✅ Preserved docs/config.js during test deployments
- ✅ Fixed recurring credential deployment issues

### v0.13.5+180 (April 2, 2026) - Configuration Modernization ✅

**Major Changes:**
- ✅ Modern environment variable injection system
- ✅ CI/CD support via GitHub Actions
- ✅ Runtime config validation
- ✅ User-friendly error screens
- ✅ Proper sed escaping for special characters
- ✅ No hardcoded credentials
- ✅ Dual-mode deployment (local .env + CI/CD env vars)

**New Files:**
- `web/config.template.js` - Modern template with `${VAR}` placeholders
- `scripts/generate-web-config.sh` - CI/CD config generation
- `.github/workflows/deploy-test.yml` - GitHub Actions workflow
- `lib/config/config_validator.dart` - Runtime validation
- `lib/widgets/config_error_widget.dart` - Error UI

**Documentation:**
- `docs/WEB_CONFIG_MIGRATION.md` - Migration guide
- `docs/SECURITY_BEST_PRACTICES.md` - Security guidelines
- `docs/ROLLBACK_PROCEDURE.md` - Emergency rollback
- `docs/POST_DEPLOY_CHECKLIST.md` - Verification steps

### Pre-v0.13.4 (Legacy)
- ❌ Manual config.js creation required
- ❌ No validation before deploy
- ❌ docs/config.js deleted on every rebuild
- ❌ Credentials sometimes exposed in git

---

## 📞 Support

If you encounter issues:

1. **Check documentation:**
   - `docs/WEB_CONFIG_MIGRATION.md` - Migration guide
   - `docs/SECURITY_BEST_PRACTICES.md` - Security guidelines
   - `docs/ROLLBACK_PROCEDURE.md` - Emergency rollback
   - `docs/POST_DEPLOY_CHECKLIST.md` - Verification steps

2. **Review known issues:**
   - `memory/CRITICAL_PROBLEMS.md` - Historical issues
   - `test/PHASE3_TEST_REPORT.md` - Test results

3. **Common fixes:**
   - Verify `.env` file has valid credentials (not placeholders)
   - Check `web/config.js` was created successfully
   - Verify `config.js` loads in browser (check DevTools)
   - Check build logs for specific error messages

4. **Emergency rollback:**
   - Follow `docs/ROLLBACK_PROCEDURE.md`
   - Restore from `backup/config-modernization-2026-04-02/`

---

## 🎯 Quick Reference

| Command | Purpose | Target |
|---------|---------|--------|
| `make deploy-stable` | Production (Hugo + Flutter) | `flowgroove.app/` + `/app/` |
| `make deploy-test` | Test deploy (Hugo + Flutter) | GitHub Pages |
| `make release` | Android + GitHub Release | APK + Release |
| `./scripts/inject-web-config.sh` | Validate & inject config | Local only |

---

**Remember:** Always test with `make -f Makefile.hugo deploy-all` before `make deploy-stable`!
