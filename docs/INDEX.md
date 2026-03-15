# 📚 RepSync Documentation Index

**Last Updated:** March 15, 2026  
**Project Version:** 0.13.2+170

---

## 📁 Directory Structure

```
docs/
├── agents/           # Agent system documentation
├── archive/          # Historical/archived documents
├── deployment/       # Deployment guides and instructions
├── reports/          # Fix reports and analysis
└── INDEX.md          # This file
```

---

## 🎯 Quick Links

| Document | Location | Description |
|----------|----------|-------------|
| **README.md** | Root | Main project documentation |
| **Makefile** | Root | Build and deployment commands |
| **DEPLOYMENT_GUIDE.md** | Root | Production deployment guide |
| **WIP/** | Root | Work in progress documents |

---

## 📂 Documentation Categories

### 👥 Agent System (`docs/agents/`)

Documentation for the autonomous agent system.

| File | Description |
|------|-------------|
| `AGENT_MASTER_CONTROL.md` | Master control document for all agents |
| `mr-*.md` | Individual agent documentation |

---

### 🚀 Deployment (`docs/deployment/`)

Guides for deploying RepSync to various platforms.

| File | Description |
|------|-------------|
| `DEPLOYMENT_GUIDE.md` | Main deployment guide (also in root) |
| `DEPLOYMENT_READY.md` | Pre-deployment checklist |
| `QUICK_SETUP_DEPLOYMENT.md` | Quick start deployment |
| `FTP_data.md` | FTP configuration (sensitive) |

---

### 📊 Reports & Analysis (`docs/reports/`)

Technical reports, fix documentation, and analysis.

#### Recent Fixes
| File | Description |
|------|-------------|
| `FIREBASE_HOSTING_WHITE_SCREEN_FIX.md` | Firebase Hosting white screen fix |
| `GITHUB_PAGES_VERSION_FIX.md` | GitHub Pages version display fix |
| `VERSION_DISPLAY_CONSISTENCY.md` | Version consistency improvements |
| `COLOR_THEME_CLEANUP_COMPLETE.md` | Color theme standardization |

#### Analysis Reports
| File | Description |
|------|-------------|
| `FIREBASE_ANALYTICS_FIX.md` | Firebase Analytics implementation |
| `FIREBASE_ANALYTICS_IMPLEMENTATION.md` | Detailed analytics setup |
| `FINAL_COMPREHENSIVE_AUDIT_REPORT.md` | Comprehensive code audit |
| `CHAT_EXPORTS_ANALYSIS.md` | Chat export analysis |

#### Complete Reports
| File | Description |
|------|-------------|
| `CLEANUP_COMPLETE_REPORT.md` | Project cleanup completion |
| `FINAL_WEB_VERSION_FIX.md` | Web version fix report |
| `ISSUE_24_COMPLETE.md` | Issue #24 resolution |

---

### 📦 Archive (`docs/archive/`)

Historical documents and auto-generated exports.

#### Auto-generated Exports
- `qwen-code-export-*.md` - Qwen Code session exports
- `chat-export-*.json` - Chat export backups

#### Historical Documentation
- `GIT_HISTORY_REFERENCE.md` - Git history analysis
- `MARCH_*_WORK_SUMMARY.md` - Work summaries
- `ICONS_*.md` - Icon generation documentation
- `README_ICONS.md` - Icon usage guide
- `MAKEFILE_*.md` - Makefile maintenance reports
- `ToDO-issues.md` - Old TODO list
- `cleanup.md` - Cleanup notes
- `comapre_metronome.md` - Metronome comparison
- `recomendation_upgrade_034.md` - Upgrade recommendations
- `firebase_analytics.md` - Old analytics docs

---

## 🔧 Configuration Files

| File | Location | Description |
|------|----------|-------------|
| `pubspec.yaml` | Root | Flutter dependencies and assets |
| `analysis_options.yaml` | Root | Dart analyzer configuration |
| `firebase.json` | Root | Firebase configuration |
| `firestore.rules` | Root | Firestore security rules |
| `riverpod_lint.yaml` | Root | Riverpod lint configuration |
| `flutter_launcher_icons.yaml` | Root | App icon configuration |

---

## 📱 Platform-Specific Folders

| Folder | Description |
|--------|-------------|
| `android/` | Android platform code |
| `ios/` | iOS platform code |
| `web/` | Web platform source |
| `linux/` | Linux platform code |
| `macos/` | macOS platform code |
| `windows/` | Windows platform code |

---

## 🛠️ Development Folders

| Folder | Description |
|--------|-------------|
| `lib/` | Main Dart source code |
| `test/` | Unit and widget tests |
| `agents/` | Agent system implementation |
| `scripts/` | Build and utility scripts |
| `assets/` | App assets (images, configs) |
| `functions/` | Firebase Cloud Functions |

---

## 📝 Work in Progress (`WIP/`)

Active development documents.

| File | Description |
|------|-------------|
| `COLOR_THEME_IMPROVEMENT_PLAN.md` | Color theme cleanup plan |
| `COLOR_THEME_CLEANUP_COMPLETE.md` | Color theme completion report |
| `GITHUB_PAGES_VERSION_FIX.md` | GitHub Pages version fix |
| `FIREBASE_HOSTING_USAGE.md` | Firebase Hosting usage guide |
| `FIREBASE_HOSTING_WHITE_SCREEN_FIX.md` | Firebase white screen fix |

---

## 🔐 Sensitive Files

⚠️ **Do not commit these files to public repositories:**

| File | Description |
|------|-------------|
| `.env` | Environment variables (API keys) |
| `.ftp-env.example` | FTP credentials template |
| `FTP_data.md` | FTP configuration details |

---

## 📞 External Links

- **GitHub Repository:** https://github.com/berlogabob/flutter-repsync-app
- **Web App (Test):** https://berlogabob.github.io/flutter-FlowGroove-app/
- **Firebase Console:** https://console.firebase.google.com/project/repsync-app-8685c
- **Production:** https://flowgroove.app

---

## 📖 How to Use This Index

1. **Looking for deployment info?** → Check [`docs/deployment/`](#-deployment-deployment)
2. **Need to understand agents?** → Check [`docs/agents/`](#-agent-system-docsagents)
3. **Researching a fix?** → Check [`docs/reports/`](#-reports--analysis-docsreports)
4. **Historical documents?** → Check [`docs/archive/`](#-archive-docsarchive)
5. **Active work?** → Check [`WIP/`](#-work-in-progress-wip)

---

**Maintainer:** FlowGroove Team  
**Last Review:** March 15, 2026
