# FlowGroove

[![Flutter Version](https://img.shields.io/badge/Flutter-3.41+-blue.svg)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.11+-blue.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/berlogabob/flutter-repsync-app?style=social)](https://github.com/berlogabob/flutter-repsync-app/stargazers)

**Flutter app for managing band repertoires, setlists, and shared song databases for cover bands**

---

## 🚀 Quick Start

### Test Deployment (GitHub Pages)

```bash
make deploy-test
```

**That's it!** No credentials needed. In 2 minutes, test at:
https://berlogabob.github.io/flutter-FlowGroove-app/

### Android Build

```bash
make release
```

Builds APK + AAB + creates GitHub Release.

### Production Deployment (FTP)

```bash
export FTP_PASS=your_password
make deploy-stable
```

Deploys Hugo landing page (`flowgroove.app/`) + Flutter app (`flowgroove.app/app/`).

---

## ✅ Features

### Core
- ✅ Song management with structure editor
- ✅ Band management with invite codes
- ✅ Setlist creation with drag-and-drop ordering
- ✅ Offline-first architecture with Hive
- ✅ Real-time sync via Firebase
- ✅ CSV import/export
- ✅ PDF export for setlists
- ✅ Responsive design (mobile/tablet/desktop)
- ✅ Dark theme (MonoPulse)

### Tools
- ✅ **Metronome** — Custom time signatures, accent patterns, pattern presets, frequency controls, song library integration
- ✅ **Tuner** — Generate tone & listen modes, pitch detection (YIN algorithm), volume control, A4 calibration (432–445 Hz)
- ✅ **Tuner: Regional Instruments** — Guitar (6-string), Cavaquinho (Brazil), Balalaika (Russia), Ukulele (Hawaii), Sitar (India)
- ✅ **Tuner: Multiple Tunings** — Standard, Drop D, Open G, Open D, DADGAD, Half Step Down, and more per instrument
- ✅ **Tuner: Custom Tuning Editor** — Create and save custom tunings in-session
- ✅ **Tuner: Auto/Manual Detection** — Auto-detect any note or target a specific string
- ✅ **Tuner: Stage Mode** — Auto-hide UI for on-stage use, large note display
- ✅ **Tuner: Haptic Feedback** — Precision-based haptic cues (±1 cent, ±5 cents)
- ✅ **Tuner: Note Scale Ruler** — Visual cents deviation display
- ✅ **Wakelock** — Screen stays on during tool use

---

## 📋 Configuration

### Demo Mode (Default)

**No setup required!** Demo configuration is included:
- ✅ Firebase works (login, database, storage)
- ✅ All core features functional
- ⚠️ Spotify features disabled (not needed yet)
- ⚠️ Twitter features disabled (not needed yet)

### Production Mode (Optional)

When you need Spotify/Twitter integration:

```bash
export FIREBASE_API_KEY=your_key
export SPOTIFY_CLIENT_ID=your_id
export SPOTIFY_CLIENT_SECRET=your_secret
export FTP_PASS=your_password
make deploy-stable
```

---

## 🛠️ Makefile Commands

| Command | Description | Credentials |
|---------|-------------|-------------|
| `make deploy-test` | GitHub Pages deployment | ❌ No |
| `make deploy-stable` | Production FTP (Hugo + Flutter) | ⚠️ FTP only |
| `make release` | Android APK + GitHub Release | ❌ No |
| `make build-android` | Build Android APK | ❌ No |
| `make build-web` | Build web app | ❌ No |
| `make help` | Show all commands | ❌ No |
| `make help-env` | Environment variable setup | ❌ No |

---

## 📚 Documentation

- **DEPLOYMENT_GUIDE.md** - Full deployment instructions
- **docs/MODERNIZATION_COMPLETE.md** - Modernization report
- **docs/MAKEFILE_MODERNIZATION_COMPLETE.md** - Makefile guide
- **docs/SECURITY_BEST_PRACTICES.md** - Security guidelines
- **docs/ROLLBACK_PROCEDURE.md** - Emergency rollback
- **docs/POST_DEPLOY_CHECKLIST.md** - Verification steps
- **memory/CRITICAL_PROBLEMS.md** - Known issues & fixes

---

## 🏗️ Architecture

- **Frontend:** Flutter 3.41 + Dart 3.11
- **State Management:** Riverpod 3.x (Notifiers + Providers)
- **Backend:** Firebase (Auth, Firestore, Storage)
- **Offline:** Hive (local database)
- **Navigation:** GoRouter
- **Theme:** MonoPulse (dark theme)
- **Web Config:** `window.env` via `dart:js`
- **Audio:** audioplayers (tone generation), pcm_stream_recorder + pitch_detector_dart (pitch detection)
- **Dual System:** Hugo landing page (`site/`) → Flutter web app (`docs/app/`) → Firebase backend

### Key Providers
- **Auth:** `authServiceProvider`, `currentUserProvider`
- **Data:** `songsProvider`, `bandsProvider`, `setlistsProvider` (Firestore + Hive cache)
- **Sync:** `syncStatusProvider`, `conflictProvider`
- **Tools:** `metronomeProvider`, `tunerProvider` (with Post-MVP instrument/tuning support)
- **Forms:** `songFormProvider`, `bandFormProvider`
- **Utilities:** `wakelockProvider`, `permissionsProvider`, `songAutocompleteProvider`

---

## 📅 Roadmap

### Completed
- [x] Metronome with custom time signatures and patterns
- [x] Tuner with pitch detection and tone generation
- [x] Regional instruments (Guitar, Cavaquinho, Balalaika, Ukulele, Sitar)
- [x] Custom tuning editor
- [x] Auto/manual note detection
- [x] Stage mode for on-stage use
- [x] Haptic feedback system
- [x] Wakelock support
- [x] Song autocomplete
- [x] Anonymous auth support

### Upcoming
- [ ] Calendar date picker integration
- [ ] User profile base tags system
- [ ] Enhanced role-based permissions
- [ ] Song tag cloud visualization
- [ ] iOS support
- [ ] Spotify integration (when needed)
- [ ] In-app collaboration tools

---

## 🔒 Security

- ✅ No hardcoded credentials
- ✅ Firebase Security Rules enabled
- ✅ Credentials via environment variables only
- ✅ `.env` files gitignored
- ✅ Demo config uses public Firebase key only

**See:** [docs/SECURITY_BEST_PRACTICES.md](docs/SECURITY_BEST_PRACTICES.md)

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run config tests
flutter test test/config/

# Run security audit
bash test/security/git_audit_test.sh
```

**Test Coverage:** 1718 passing, 50 failing, 291 skipped (~950 test files across models, providers, services, screens, widgets, integration)

---

## 🤝 Contributing

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Run tests: `flutter test`
5. Deploy to test: `make deploy-test`
6. Submit a PR

---

## 📞 Support

**Issues:** https://github.com/berlogabob/flutter-repsync-app/issues

**Documentation:**
- [Deployment Guide](DEPLOYMENT_GUIDE.md)
- [Rollback Procedure](docs/ROLLBACK_PROCEDURE.md)
- [Post-Deploy Checklist](docs/POST_DEPLOY_CHECKLIST.md)
- [Critical Problems](memory/CRITICAL_PROBLEMS.md)

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

Built with ❤️ for musicians and cover bands.

---

## 🎯 Quick Reference

```bash
# Test changes
git add . && git commit -m "Your changes"
make deploy-test
# Test at: https://berlogabob.github.io/flutter-FlowGroove-app/

# Build Android
make release
# APK: build/app/outputs/flutter-apk/app-release.apk

# Production deploy
export FTP_PASS=xxx
make deploy-stable
# Live at: https://flowgroove.app/
```

---

**Version:** 0.13.4+183
**Last Updated:** April 9, 2026
**Status:** ✅ Production Ready
