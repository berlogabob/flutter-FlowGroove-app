# 🏗️ FLOWGROOVE PROJECT ARCHITECTURE

**Last Updated:** April 8, 2026  
**Version:** 0.13.4+183

---

## 📂 PROJECT OVERVIEW

FlowGroove consists of **TWO separate systems** that work together:

```
┌─────────────────────────────────────────────────────────────┐
│                    FLOWGROOVE PROJECT                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1️⃣  HUGO LANDING PAGE (site/)                              │
│      └─ Marketing site, blog, FAQ, TinyLaunch info           │
│      └─ Built with Hugo (static site generator)              │
│      └─ Deployed to GitHub Pages                             │
│                                                              │
│  2️⃣  FLUTTER APP (lib/, web/, android/)                     │
│      └─ Full FlowGroove application                          │
│      └─ Built with Flutter (cross-platform)                  │
│      └─ Deployed to GitHub Pages (web) + APK (mobile)        │
│                                                              │
│  USER JOURNEY:                                               │
│  Landing Page → "Open App" button → Flutter Web App          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 1️⃣ HUGO LANDING PAGE

### Location
```
site/
├── content/          # Markdown content
│   ├── _index.md     # Landing page (home)
│   ├── about.md      # About / The Story
│   ├── faq.md        # FAQ
│   ├── privacy.md    # Privacy policy
│   ├── terms.md      # Terms of service
│   ├── tinylaunch.md # TinyLaunch launch page
│   ├── blog/         # Blog posts
│   └── songs/        # Programmatic SEO (future)
├── layouts/          # Hugo templates
│   ├── partials/     # SEO, analytics
│   └── shortcodes/   # Custom components
├── static/           # Images, videos, robots.txt
├── themes/           # PaperMod theme
├── hugo.toml         # Configuration
└── public/           # Built output (gitignored)
```

### Purpose
- **Marketing site** for FlowGroove
- **SEO-optimized** landing page with blog
- **Conversion-focused** to get users to open the app
- **Legal compliance** (privacy, terms for Sounding Doubts)

### Key Features
- ✅ Hero section with "Open App" CTA
- ✅ Feature grid (sync, BPM detection, dark mode, offline)
- ✅ FAQ accordion
- ✅ Blog (developer journey, band tips)
- ✅ Ko-fi floating widget
- ✅ TinyLaunch launch tracking
- ✅ GA4 + Microsoft Clarity analytics

### Build & Deploy
```bash
# Build
make -f Makefile.hugo build

# Local dev server
make -f Makefile.hugo serve
# URL: http://localhost:1313/

# Deploy to GitHub Pages
make -f Makefile.hugo deploy
# Commits site/public/ → pushes → GitHub Actions auto-deploys
```

### Analytics
- **GA4:** `G-T6YBX0M53W`
- **Clarity:** `w8h5eswdua`
- Custom events: Ko-fi clicks, demo trials, FAQ engagement

---

## 2️⃣ FLUTTER APP

### Location
```
flutter_repsync_app/
├── lib/              # Dart source code
│   ├── main.dart     # App entry point
│   ├── screens/      # UI screens (login, songs, setlists)
│   ├── providers/    # Riverpod state management
│   ├── models/       # Data models
│   ├── services/     # Business logic
│   ├── widgets/      # Reusable UI components
│   └── theme/        # MonoPulse theme
├── web/              # Web-specific files
│   ├── index.html    # Web entry point
│   └── config.js     # Runtime config (generated)
├── android/          # Android native code
├── ios/              # iOS native code
├── pubspec.yaml      # Dependencies
└── Makefile          # Build commands
```

### Purpose
- **Full FlowGroove application** for musicians
- **Login/Register** → Firebase auth
- **Song management** → Add, search, filter songs
- **Setlist creation** → Build rehearsal/gig setlists
- **Real-time sync** → Firestore across devices
- **BPM/Key detection** → Auto-detect song metadata
- **Offline support** → Hive local cache

### Key Features
- ✅ Firebase authentication
- ✅ Song library with search/filter
- ✅ Setlist builder
- ✅ Real-time Firestore sync
- ✅ Offline-first architecture
- ✅ Dark theme (stage-ready)
- ✅ Auto BPM & key detection
- ✅ Riverpod state management
- ✅ Hive offline caching

### Build & Deploy

**Web (Testing on GitHub Pages):**
```bash
make deploy-test
# Builds Flutter web app with base-href /flutter-FlowGroove-app/
# Copies to docs/
# Commits and pushes to second01 branch
# URL: https://berlogabob.github.io/flutter-FlowGroove-app/
```

**Android (Mobile App):**
```bash
make release
# Builds APK + AAB
# Creates GitHub Release with artifacts
# APK: build/app/outputs/flutter-apk/app-release.apk
```

**Production (FTP - flowgroove.app):**
```bash
make deploy-stable
# Builds Flutter web app with base-href /
# Uploads to flowgroove.app via FTP
# URL: https://flowgroove.app/
```

### Analytics
- **Firebase Analytics:** Integrated in app
- **GA4:** Same ID as landing page (`G-T6YBX0M53W`)

---

## 🔗 HOW THEY CONNECT

### User Journey

```
User visits flowgroove.app (or GitHub Pages)
    ↓
Sees Hugo Landing Page
    ├─ Hero section with "Open App" button
    ├─ Features grid
    ├─ FAQ
    └─ Blog posts
    ↓
Clicks "Open App" button
    ↓
Redirected to Flutter Web App
    ├─ https://berlogabob.github.io/flutter-FlowGroove-app/ (GitHub Pages)
    └─ OR https://flowgroove.app/ (production FTP)
    ↓
User logs in / registers
    ↓
Uses FlowGroove app (songs, setlists, sync)
```

### CTA Links

| Landing Page CTA | Destination | Purpose |
|------------------|-------------|---------|
| "Open App" (primary) | Flutter web app URL | Login and use the app |
| "Support the Dev" (secondary) | https://ko-fi.com/flowgroove | Donate on Ko-fi |

---

## 🚀 DEPLOYMENT MATRIX

### Current: Single Repo, Dual Deploy (GitHub Pages)

| Component | Build Output | Deploy Command | URL |
|-----------|-------------|----------------|-----|
| **Hugo Landing Page** | `docs/` (root) | `make -f Makefile.hugo hugo-build` | `https://berlogabob.github.io/flutter-FlowGroove-app/` |
| **Flutter Web App** | `docs/app/` (subfolder) | `make -f Makefile.hugo app-build` | `https://berlogabob.github.io/flutter-FlowGroove-app/app/` |
| **Both Together** | `docs/` + `docs/app/` | `make -f Makefile.hugo deploy-all` | See above |
| **Android App** | `build/app/outputs/` | `make release` | GitHub Releases |

### Production (FTP - flowgroove.app)

| Component | Deploy Command | URL |
|-----------|---------------|-----|
| **Flutter Web App** | `make deploy-stable` | `https://flowgroove.app/` |
| **Android App** | `make release` | Google Play / GitHub Releases |

**Note:** Hugo landing page is GitHub Pages only. Production FTP serves Flutter app directly.

---

## 📊 TECHNOLOGY STACK

### Hugo Landing Page
- **Hugo** v0.160.0 (extended) - Static site generator
- **PaperMod** - Theme
- **Markdown** - Content format
- **Custom shortcodes** - Reusable components
- **GA4 + Clarity** - Analytics

### Flutter App
- **Flutter** 3.x - Cross-platform framework
- **Dart** - Language
- **Firebase** - Auth, Firestore, Analytics
- **Riverpod** - State management
- **Hive** - Offline caching
- **Material Design** - UI framework (MonoPulse theme)

---

## 📝 WORKFLOW

### Development Workflow

**1. Edit Hugo Landing Page:**
```bash
cd site/
# Edit content/_index.md or other files
make -f Makefile.hugo serve  # Preview locally at localhost:1313
make -f Makefile.hugo hugo-build  # Build to docs/
```

**2. Edit Flutter App:**
```bash
# Edit lib/ files
flutter run  # Run on device
make -f Makefile.hugo app-build  # Build to docs/app/
make -f Makefile.hugo deploy-all  # Deploy both to GitHub Pages
```

**3. Deploy Both (Hugo + Flutter):**
```bash
make -f Makefile.hugo deploy-all
# Builds Hugo → docs/ root
# Builds Flutter → docs/app/
# Commits and pushes docs/ to second01 branch
# GitHub Pages serves from docs/
```

### Folder Structure After Deploy

```
docs/                          ← GitHub Pages source (second01 branch)
├── index.html                 ← Hugo landing page (root)
├── about/, faq/, blog/        ← Hugo subpages
├── assets/, images/           ← Hugo static files
├── .nojekyll                  ← GitHub Pages flag
└── app/                       ← Flutter web app subfolder
    ├── index.html             ← Flutter app entry
    ├── main.dart.js           ← Flutter bundle
    ├── flutter_bootstrap.js   ← Flutter loader
    ├── assets/                ← Flutter assets
    └── config.js              ← Flutter runtime config
```

### URL Routing

| URL | What Loads | Purpose |
|-----|-----------|---------|
| `/` | Hugo `index.html` | Landing page |
| `/about/` | Hugo about page | About section |
| `/blog/` | Hugo blog index | Blog posts |
| `/app/` | Flutter `index.html` | The actual app |
| `/app/#/login` | Flutter app route | Login screen |

---

## 🔒 SECURITY

### Hugo Landing Page
- ✅ No secrets in code
- ✅ Analytics IDs are public (safe)
- ✅ Ko-fi username is public

### Flutter App
- ✅ Firebase config is public (safe)
- ✅ Firestore rules protect data
- ✅ Secrets loaded via config.js at runtime
- ✅ No .env files in git

---

## 📈 FUTURE ENHANCEMENTS

### Landing Page (Hugo)
- [ ] Programmatic SEO song pages (`/songs/wonderwall-bpm-key`)
- [ ] Video demo embed (YouTube)
- [ ] Testimonials section
- [ ] Changelog page
- [ ] Multi-language support (PT, EN)

### Flutter App
- [ ] iOS app
- [ ] Spotify integration
- [ ] Audio playback (metronome, reference tracks)
- [ ] Band collaboration features
- [ ] Advanced setlist features (transposition, capo)

---

## 🆘 TROUBLESHOOTING

### Landing Page Not Showing
```bash
cd site
hugo server -D  # Test locally
make -f Makefile.hugo deploy  # Rebuild and push
```

### Flutter Web App Not Loading
```bash
make deploy-test  # Rebuild and deploy to GitHub Pages
# Check: https://berlogabob.github.io/flutter-FlowGroove-app/
```

### CTA Button Broken
- Check `site/content/_index.md` for correct Flutter app URL
- Rebuild: `make -f Makefile.hugo deploy`

---

**Built with ❤️ for musicians and cover bands**  
**© 2026 Sounding Doubts - Unipessoal Lda. Amadora, Portugal. NIF: 518200736.**
