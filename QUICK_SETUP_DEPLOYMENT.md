# 🚀 Quick Setup for flowgroove.app Deployment

## ✅ What's Already Done

1. ✅ Firebase Auth configured for `flowgroove.app` and `www.flowgroove.app`
2. ✅ FTP deployment script created
3. ✅ Makefile commands added
4. ✅ Comprehensive documentation created

---

## 🔐 Step 1: Set Up FTP Credentials

Create `.ftp-env` file with your FTP credentials:

```bash
# Copy the example file
cp .ftp-env.example .ftp-env

# Edit with your actual credentials
nano .ftp-env
```

**Fill in your FTP details:**
```env
FTP_HOST=ftp.flowgroove.app
FTP_USER=your_ftp_username
FTP_PASS=your_ftp_password
REMOTE_DIR=public_html
```

**⚠️ Important:** The `.ftp-env` file contains secrets and is already in `.gitignore` - never commit it!

---

## 📦 Step 2: Install lftp (Optional but Recommended)

For faster FTP uploads:

```bash
# macOS
brew install lftp

# Ubuntu/Debian
sudo apt-get install lftp
```

Without `lftp`, the script will use `curl` (works but slower).

---

## 🎯 Step 3: Deploy to Production

### Option A: Full Release (Recommended for new versions)

```bash
make release-stable
```

This will:
1. Increment version number
2. Build web + Android APK + AAB
3. Deploy to https://flowgroove.app/
4. Create GitHub Release
5. Commit and tag the release

### Option B: Deploy Only (Quick deployment)

```bash
make deploy-stable
```

This will:
1. Build web app
2. Deploy to https://flowgroove.app/
3. Commit to git

### Option C: Deploy Existing Build (Hotfix)

```bash
make deploy-flowgroove
```

Use when you already have a build and just want to upload.

---

## 🧪 Step 4: Verify Deployment

1. Open https://flowgroove.app/
2. Test login functionality
3. Check version in profile screen
4. Verify main features work

---

## 📋 Available Commands

```bash
# See all available commands
make help

# Deploy to production
make deploy-stable

# Deploy without building
make deploy-flowgroove

# Full release cycle
make release-stable

# Deploy to GitHub Pages (staging/backup)
make deploy
```

---

## 🆘 Troubleshooting

### FTP Upload Fails

**Error:** `FTP credentials not set!`

**Fix:**
```bash
# Check if .ftp-env exists
ls -la .ftp-env

# Create/edit it
cp .ftp-env.example .ftp-env
nano .ftp-env
```

### Slow Upload

**Fix:** Install `lftp` for faster parallel uploads:
```bash
brew install lftp
```

### Login Error on flowgroove.app

**Error:** `auth/unauthorized-domain`

**Fix:** Already configured! Just wait 1-2 minutes for Firebase to propagate.

---

## 📖 Full Documentation

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for complete details including:
- Detailed workflow
- All deployment commands
- Troubleshooting guide
- Best practices

---

**Ready to deploy!** 🎉
