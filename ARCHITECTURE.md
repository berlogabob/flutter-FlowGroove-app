# 🏗️ FLOWGROOVE PROJECT ARCHITECTURE

**Last Updated:** April 9, 2026
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
│   ├── screens/      # UI screens (login, songs, setlists, tools)
│   │   ├── auth/     # Login, register screens
│   │   ├── bands/    # Band management screens
│   │   ├── setlists/ # Setlist screens
│   │   ├── songs/    # Song management screens
│   │   └── tools/    # Tool-specific screens (metronome, tuner)
│   ├── providers/    # Riverpod state management
│   │   ├── auth/     # Auth providers
│   │   ├── data/     # Data providers (songs, bands, setlists)
│   │   ├── sync/     # Sync status providers
│   │   ├── tuner_provider.dart      # Tuner state (Post-MVP)
│   │   ├── metronome_selective_providers.dart
│   │   ├── wakelock_provider.dart
│   │   ├── song_autocomplete_provider.dart
│   │   └── global_tone_config_provider.dart
│   ├── models/       # Data models (Song, Band, Setlist, Instrument, etc.)
│   ├── services/     # Business logic (Firebase, audio, analytics)
│   │   ├── audio/    # PitchDetector, ToneGenerator
│   │   └── ...
│   ├── widgets/      # Reusable UI components
│   │   ├── tuner/    # Tuner widgets (11 files, Post-MVP)
│   │   ├── metronome/
│   │   ├── tools/    # Shared tool scaffolding
│   │   └── responsive/
│   ├── theme/        # MonoPulse theme
│   ├── router/       # GoRouter configuration
│   ├── repositories/ # Data access layer
│   ├── config/       # Config validation, web config
│   ├── utils/        # Utilities
│   └── analytics/    # Analytics helpers
├── web/              # Web-specific files
│   ├── index.html    # Web entry point
│   └── config.js     # Runtime config (generated)
├── android/          # Android native code
├── ios/              # iOS native code
├── assets/
│   ├── data/
│   │   └── tunings.json  # Instrument/tuning definitions (Post-MVP)
│   └── sounds/       # Audio samples
├── test/             # Test suite (1718 passing, 50 failing, 291 skipped)
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

### Tuner System (Post-MVP)

The tuner is the most complex tool in the app, with a complete Post-MVP implementation:

```
TunerScreen (lib/screens/tuner_screen.dart)
├── ToolScreenScaffold (shared tool wrapper)
│   ├── ToolModeSwitcher (Generate Tone / Listen & Tune)
│   ├── InstrumentPicker (bottom sheet, 5 instruments)
│   ├── DetectionModeToggle (Auto / Manual)
│   ├── StringSelector (manual mode string picker)
│   ├── CentralDial (frequency display + tick marks)
│   ├── NoteScaleRuler (visual cents deviation)
│   ├── TransportBar (play/stop + settings)
│   └── StageModeOverlay (auto-hide UI after inactivity)
│
TunerProvider (lib/providers/tuner_provider.dart)
├── TunerNotifier (main state manager)
│   ├── ToneGenerator (sine wave tone generation)
│   ├── PitchDetector (YIN algorithm, real-time PCM)
│   ├── Instrument loading (assets/data/tunings.json)
│   ├── Haptic feedback (±1 cent, ±5 cents cues)
│   └── Stage mode management
│
├── Derived Providers
│   ├── tunerModeProvider, tunerFrequencyProvider
│   ├── tunerNoteProvider, tunerCentsProvider
│   ├── tunerIsPlayingProvider, tunerIsListeningProvider
│   ├── selectedInstrumentProvider, selectedTuningProvider
│   ├── detectionModeProvider, manualTargetStringIndexProvider
│   ├── customTuningsProvider
│   └── stageModeActiveProvider, stageModeEnabledProvider
│
└── Models
    ├── Instrument (id, name, subtitle, origin, icon, tunings)
    ├── Tuning (id, name, notes[])
    └── DetectionMode (auto, manual)
```

**Tuner Features:**
- **Generate Mode:** Sine wave tone at configurable frequency (20-2000 Hz)
- **Listen Mode:** Real-time pitch detection via YIN algorithm from microphone
- **Regional Instruments:** Guitar (6-string), Cavaquinho (Brazil), Balalaika (Russia), Ukulele (Hawaii), Sitar (India)
- **Multiple Tunings per Instrument:** Standard, Drop D, Open G, Open D, DADGAD, Half Step Down, and more
- **Custom Tuning Editor:** Create/save custom tunings (in-memory, session-scoped)
- **Auto/Manual Detection:** Auto-detect any note or target a specific string
- **Stage Mode:** Auto-hide UI after inactivity, large note display for on-stage use
- **Haptic Feedback:** Precision-based cues (±1 cent = medium impact, ±5 cents = light impact)
- **A4 Calibration:** Configurable reference A4 (432-445 Hz)
- **Volume Control:** Adjustable output volume (0.0-1.0)

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
# Builds Hugo landing page (site/public/)
# Builds Flutter web app with base-href /app/
# Uploads Hugo → / (root), Flutter → /app/
# URL: https://flowgroove.app/ (landing)
# URL: https://flowgroove.app/app/ (app)
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
| **Hugo Landing** | `make deploy-stable` | `https://flowgroove.app/` |
| **Flutter Web App** | `make deploy-stable` | `https://flowgroove.app/app/` |
| **Android App** | `make release` | Google Play / GitHub Releases |

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
- **Dart** 3.11+ - Language
- **Firebase** - Auth, Firestore, Storage, Analytics
- **Riverpod** 3.x - State management (Notifiers + Providers)
- **Hive** - Offline caching
- **GoRouter** - Navigation
- **Material Design** - UI framework (MonoPulse dark theme)
- **pitch_detector_dart** - YIN algorithm pitch detection
- **pcm_stream_recorder** - Real-time PCM audio capture
- **audioplayers** - Tone generation
- **wakelock_plus** - Screen wake lock prevention
- **dio + http** - HTTP clients
- **pdf + printing** - PDF export
- **csv** - CSV processing
- **flutter_sound** - Audio recording
- **formz** - Form validation
- **equatable** - Value equality

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
- [ ] Calendar date picker integration
- [ ] User profile base tags system
- [ ] Enhanced role-based permissions
- [ ] Song tag cloud visualization
- [ ] In-app collaboration tools

### Completed Recently ✅
- [x] Tuner: Regional instruments (Guitar, Cavaquinho, Balalaika, Ukulele, Sitar)
- [x] Tuner: Auto/manual note detection
- [x] Tuner: Custom tuning editor
- [x] Tuner: Stage mode
- [x] Tuner: Haptic feedback
- [x] Tuner: Note scale ruler
- [x] Wakelock support
- [x] Song autocomplete
- [x] Anonymous auth support
- [x] Metronome: Custom time signatures, accent patterns, presets
- [x] Metronome: Song library integration
- [x] Responsive widget system
- [x] Environment variable injection system
- [x] Hugo landing page + deployment pipeline

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
