# FlowGroove App - Deployment Makefile
# =====================================
# Version: 0.13.4+190
# Last Updated: April 24, 2026
#
# Quick Start:
#   make -f Makefile.hugo deploy-all → Safe GitHub Pages preview (Hugo + Flutter)
#   make release                     → Build Android APK + GitHub Release
#   make deploy-stable               → Production FTP deploy (Hugo + Flutter)
#
# Demo Configuration:
#   - Firebase works out of the box (public key included)
#   - Spotify/Twitter disabled (add credentials later if needed)
#   - No .env file required for testing

SHELL := /bin/bash

.PHONY: help test-fast test-firebase-emulator deploy-stable deploy-test release build-release-artifacts build-github-pages build-web build-web-prod build-web-github package-github-pages build-android hugo-build-prod check-env check-env-test check-env-prod preflight-prod help-env clean-exports

DEPLOY_TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
BACKUP_DIR := backup/production-$(DEPLOY_TIMESTAMP)
BACKUP_INFO_FILE := /tmp/flowgroove-latest-backup.txt
FTP_DIR_DEFAULT := flowgroove.app
FIREBASE_EMULATOR_TEST_FILES := integration_test/auth_flow_test.dart integration_test/setlist_management_test.dart
GITHUB_PAGES_BASE_HREF ?= /flutter-FlowGroove-app/
GITHUB_PAGES_DIST ?= docs
RELEASE_GIT_PATHS ?= Makefile Makefile.hugo pubspec.yaml web/version.json lib test

# =============================================================================
# HELP
# =============================================================================

help:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         FlowGroove App - Deployment Commands              ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🚀 Quick Start:"
	@echo ""
	@echo "  make -f Makefile.hugo deploy-all  # Safe GitHub Pages preview"
	@echo "  make release         # Build Android APK + GitHub Release"
	@echo "  make build-release-artifacts # Build GitHub Pages web + Android APK"
	@echo "  make deploy-stable   # Production FTP (Hugo + Flutter)"
	@echo "  make test-fast       # Full fast Flutter suite"
	@echo "  make test-firebase-emulator  # Auth/Firestore emulator acceptance suite"
	@echo ""
	@echo "📋 All Commands:"
	@echo ""
	@echo "  make deploy-test     - Deploy Flutter-only build to GitHub Pages"
	@echo "  make deploy-stable   - Deploy Hugo + Flutter to FTP (flowgroove.app)"
	@echo "  make release         - Build Android APK + AAB + GitHub Release"
	@echo "  make build-release-artifacts - Build GitHub Pages web + Android APK"
	@echo "  make build-github-pages - Build GitHub Pages web artifact only"
	@echo "  make build-android   - Build Android APK only"
	@echo "  make build-web       - Build web app (production)"
	@echo "  make test-fast       - Run the canonical fast local Flutter suite"
	@echo "  make test-firebase-emulator - Run emulator-backed auth/setlist acceptance tests"
	@echo "  make clean-exports   - Archive chat exports"
	@echo "  make help-env        - Show environment variable setup"
	@echo ""
	@echo "📝 Documentation:"
	@echo ""
	@echo "  README.md                       - Project overview"
	@echo "  ARCHITECTURE.md                 - Current architecture"
	@echo "  DEPLOYMENT_GUIDE.md             - Deployment instructions"
	@echo "  docs/project-audit-2026-04-24.md - Current audit report"
	@echo ""

# =============================================================================
# PRE-DEPLOYMENT VALIDATION
# =============================================================================

test-fast:
	@flutter test --exclude-tags firebase-emulator

test-firebase-emulator:
	@command -v firebase >/dev/null || (echo "❌ Firebase CLI not found. Install firebase-tools first."; exit 1)
	@java -version >/dev/null 2>&1 || (echo "❌ Java runtime not found. Install Java to run Firebase emulators."; exit 1)
	@firebase emulators:exec --project repsync-app-8685c --only auth,firestore "flutter test -d $${FIREBASE_EMULATOR_TEST_DEVICE:-emulator-5554} --tags firebase-emulator $(FIREBASE_EMULATOR_TEST_FILES)"

check-env:
	@echo "Validating configuration..."

# For GitHub Pages test deployment - uses demo config (no credentials needed)
check-env-test:
	@cp web/config.demo.js web/config.js

# For production FTP deployment - requires environment variables
preflight-prod:
	@./scripts/preflight-ftp-deploy.sh

check-env-prod: preflight-prod
	@./scripts/generate-web-config.sh

# =============================================================================
# TEST DEPLOYMENT - GitHub Pages (second01 branch)
# =============================================================================

deploy-test: check-env-test build-web-github
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║  ⚠️  WARNING: This destroys the Hugo landing page!        ║"
	@echo "║  This target is for Flutter-only deploy.                  ║"
	@echo "║  For Hugo + Flutter dual-deploy, use:                     ║"
	@echo "║    make -f Makefile.hugo deploy-all                       ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] || (echo "Aborted."; exit 1)
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║      Deploying to GitHub Pages (second01 branch)          ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Copying to docs/..."
	@if [ -f docs/config.js ]; then cp docs/config.js /tmp/docs-config.js.backup; fi
	@rm -rf docs/*
	@cp -r build/web/* docs/
	@if [ -f /tmp/docs-config.js.backup ]; then cp /tmp/docs-config.js.backup docs/config.js; rm /tmp/docs-config.js.backup; fi
	@echo "✅ Files copied to docs/"
	@echo ""
	@echo "📝 Committing changes..."
	@git add docs/
	@git commit -m "docs: Deploy test build $$(cat web/version.json | grep version | head -1)" || echo "No changes to commit"
	@echo ""
	@echo "🚀 Pushing to second01 branch..."
	@git push origin second01
	@echo ""
	@echo "✅ GitHub Pages deployment complete!"
	@echo "🌐 Test URL: https://berlogabob.github.io/flutter-FlowGroove-app/"
	@echo "⏱️  GitHub Pages build: 1-2 minutes"
	@echo ""

# =============================================================================
# PRODUCTION HUGO BUILD
# =============================================================================

hugo-build-prod:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Building Hugo (Production / flowgroove.app)       ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@cd site && hugo --minify --baseURL "https://flowgroove.app/"
	@echo "✅ Hugo production build complete"
	@echo ""

# =============================================================================
# STABLE DEPLOYMENT - FTP (flowgroove.app)
# =============================================================================

deploy-stable: check-env-prod hugo-build-prod build-web-prod backup-production ftp-upload health-check-prod
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         ✅ FTP Deployment Complete!                       ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🌐 Live URL: https://flowgroove.app/"
	@echo "🌐 App URL:  https://flowgroove.app/app/"
	@echo "⏱️  SSL/CDN propagation: 1-5 minutes"
	@echo ""
	@echo "💾 Backup saved to: $(BACKUP_DIR)/"
	@echo ""
	@echo "📝 To rollback if needed:"
	@echo "   make rollback-production"
	@echo ""

# Backup current production before deploying
backup-production:
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Creating Production Backup                        ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@mkdir -p $(BACKUP_DIR)
	@echo "📦 Downloading current production files..."
	@source ./scripts/load-deploy-env.sh && \
		lftp -c "set ssl:verify-certificate $${FTP_SSL_VERIFY:-yes}; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes; set ftp:ssl-protect-list yes; open -u '$$FTP_USER','$$FTP_PASS' $$FTP_HOST; cd $${FTP_DIR:-$(FTP_DIR_DEFAULT)}; lcd $(BACKUP_DIR); mirror . .; bye"
	@echo "✅ Backup created at $(BACKUP_DIR)/"
	@echo ""
	@# Save latest backup path for auto-rollback
	@echo "$(BACKUP_DIR)" > $(BACKUP_INFO_FILE)
	@echo "💾 Latest backup: $(BACKUP_DIR)/"
	@echo ""

# Upload to FTP with SSL support
ftp-upload:
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Uploading to FTP (flowgroove.app)                 ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📤 Uploading Hugo (site/public/) → / (root)..."
	@source ./scripts/load-deploy-env.sh && \
		lftp -c "set ssl:verify-certificate $${FTP_SSL_VERIFY:-yes}; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes; set ftp:ssl-protect-list yes; open -u '$$FTP_USER','$$FTP_PASS' $$FTP_HOST; cd $${FTP_DIR:-$(FTP_DIR_DEFAULT)}; mirror --reverse --delete --exclude-glob .well-known/** --exclude-glob app/** site/public/ .; bye"
	@echo "📤 Uploading Flutter (build/web/) → /app/..."
	@source ./scripts/load-deploy-env.sh && \
		lftp -c "set ssl:verify-certificate $${FTP_SSL_VERIFY:-yes}; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes; set ftp:ssl-protect-list yes; open -u '$$FTP_USER','$$FTP_PASS' $$FTP_HOST; cd $${FTP_DIR:-$(FTP_DIR_DEFAULT)}; mkdir -p app; cd app; mirror --reverse --delete build/web/ .; bye"
	@echo "✅ Upload complete"
	@echo ""

# Health check after deployment (with auto-rollback on failure)
health-check-prod:
	@BACKUP_INFO_FILE="$(BACKUP_INFO_FILE)" ./scripts/health-check-prod.sh

# Automatic rollback (called by health-check-prod on failure)
auto-rollback:
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         🚨 AUTO-ROLLBACK INITIATED                        ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ -f $(BACKUP_INFO_FILE) ]; then \
		BACKUP_DIR=$$(cat $(BACKUP_INFO_FILE)); \
		if [ -d "$$BACKUP_DIR" ]; then \
			echo "📦 Restoring from: $$BACKUP_DIR"; \
			source ./scripts/load-deploy-env.sh && \
			lftp -c "set ssl:verify-certificate $${FTP_SSL_VERIFY:-yes}; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes; set ftp:ssl-protect-list yes; open -u '$$FTP_USER','$$FTP_PASS' $$FTP_HOST; cd $${FTP_DIR:-$(FTP_DIR_DEFAULT)}; lcd $$BACKUP_DIR; mirror --reverse --delete . .; bye"; \
			echo "✅ Auto-rollback complete!"; \
			echo "🌐 Production restored to previous version"; \
		else \
			echo "❌ ERROR: Backup directory not found: $$BACKUP_DIR"; \
			echo "🚨 Manual intervention required!"; \
		fi; \
	else \
		echo "❌ ERROR: No backup info found!"; \
		echo "🚨 Manual intervention required!"; \
		echo "📝 Available backups:"; \
		ls -1 backup/production-*/ 2>/dev/null || echo "   None found"; \
	fi
	@echo ""

# =============================================================================
# BUILD COMMANDS
# =============================================================================

# Build for web (production FTP) - uses demo config
build-web:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║              Building Web (FTP / Root)                    ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📝 Updating version.json..."
	@./scripts/update-version-json.sh
	@echo ""
	@cp web/config.demo.js web/config.js
	@echo "🔨 Building web app..."
	@echo "   Base href: / (FTP - flowgroove.app)"
	@flutter build web --release
	@echo ""
	@cp web/config.js build/web/config.js
	@echo "✅ Build complete!"
	@echo "📊 Build size: $$(du -sh build/web | cut -f1)"
	@echo ""

# Build for web (production FTP with Hugo) - uses /app/ subdirectory
build-web-prod:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Building Web (FTP / Hugo + Flutter / /app/)       ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📝 Updating version.json..."
	@./scripts/update-version-json.sh
	@echo ""
	@if [ ! -f web/config.js ]; then \
		echo "❌ ERROR: web/config.js is missing. Run make check-env-prod first."; \
		exit 1; \
	fi
	@if ! grep -q "Generated at build time" web/config.js; then \
		echo "❌ ERROR: web/config.js must be generated by scripts/generate-web-config.sh for production builds."; \
		exit 1; \
	fi
	@echo "🔨 Building web app..."
	@echo "   Base href: /app/ (FTP - flowgroove.app/app/)"
	@flutter build web --release --base-href "/app/"
	@echo ""
	@cp web/config.js build/web/config.js
	@echo "✅ Build complete!"
	@echo "📊 Build size: $$(du -sh build/web | cut -f1)"
	@echo ""

# Build for GitHub Pages - with subdirectory.
# Override GITHUB_PAGES_BASE_HREF for forks/repo renames, for example:
#   make build-github-pages GITHUB_PAGES_BASE_HREF=/my-repo/
build-github-pages: check-env-test build-web-github

build-web-github:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Building Web (GitHub Pages / Subdirectory)        ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📝 Updating version.json..."
	@./scripts/update-version-json.sh
	@echo ""
	@cp web/config.demo.js web/config.js
	@echo "🔨 Building web app..."
	@echo "   Base href: $(GITHUB_PAGES_BASE_HREF) (GitHub Pages)"
	@flutter build web --release --base-href "$(GITHUB_PAGES_BASE_HREF)"
	@echo ""
	@cp web/config.js build/web/config.js
	@touch build/web/.nojekyll
	@echo "✅ Build complete!"
	@echo "📊 Build size: $$(du -sh build/web | cut -f1)"
	@echo ""

package-github-pages: build-github-pages
	@echo "📦 Packaging GitHub Pages build into $(GITHUB_PAGES_DIST)/..."
	@rm -rf "$(GITHUB_PAGES_DIST)"
	@mkdir -p "$(GITHUB_PAGES_DIST)"
	@cp -R build/web/. "$(GITHUB_PAGES_DIST)/"
	@echo "✅ GitHub Pages package ready: $(GITHUB_PAGES_DIST)/"
	@echo ""

build-release-artifacts: build-github-pages build-android
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Release Artifacts Ready                           ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🌐 GitHub Pages web: build/web/"
	@echo "📱 Android APK: build/app/outputs/flutter-apk/app-release.apk"
	@echo ""

# Build for Android APK - uses demo config
build-android:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║              Building Android APK                         ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🤖 Building Android APK..."
	@./scripts/build-mobile-with-env.sh apk
	@echo ""
	@echo "✅ Android build complete!"
	@echo "📱 APK: build/app/outputs/flutter-apk/app-release.apk"
	@echo ""

# Build for Android App Bundle (Play Store) - uses demo config
build-appbundle:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Building Android App Bundle (AAB)                 ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🤖 Building Android App Bundle..."
	@./scripts/build-mobile-with-env.sh appbundle
	@echo ""
	@echo "✅ AAB build complete!"
	@echo "📦 AAB: build/app/outputs/bundle/release/app-release.aab"
	@echo ""

# =============================================================================
# CONFIGURATION
# =============================================================================

# FTP Configuration (loaded by scripts/load-deploy-env.sh)

# =============================================================================
# RELEASE - ANDROID APK + GITHUB RELEASE
# =============================================================================

release: build-android build-appbundle
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Creating GitHub Release with Android APK          ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📝 Updating version.json..."
	@./scripts/update-version-json.sh
	@echo ""
	$(eval NEW_VERSION := $(shell grep "^version:" pubspec.yaml | sed 's/version: //'))
	@echo "📦 Version: $(NEW_VERSION)"
	@echo ""
	@echo "💾 Committing release-scoped changes..."
	@git add $(RELEASE_GIT_PATHS)
	@git commit -m "Release $(NEW_VERSION)" || echo "No changes to commit"
	@echo ""
	@echo "🏷️  Creating git tag..."
	@git tag -a "v$(NEW_VERSION)" -m "Release $(NEW_VERSION)" || echo "Tag already exists"
	@echo ""
	@echo "🚀 Pushing to GitHub..."
	@git push origin HEAD
	@git push origin "v$(NEW_VERSION)" || echo "Tag already pushed"
	@echo ""
	@echo "📱 Creating GitHub Release..."
	@if command -v gh >/dev/null 2>&1; then \
		if gh auth status >/dev/null 2>&1; then \
			if gh release view "v$(NEW_VERSION)" >/dev/null 2>&1; then \
				echo "⚠️  Release v$(NEW_VERSION) already exists!"; \
			else \
				gh release create "v$(NEW_VERSION)" \
					--title "Release $(NEW_VERSION)" \
					--notes "Release $(NEW_VERSION) - $$(date +%Y-%m-%d)" \
					--target $(CURRENT_BRANCH) \
					build/app/outputs/flutter-apk/app-release.apk#android-apk \
					build/app/outputs/bundle/release/app-release.aab#aab && \
				echo "✅ GitHub Release created!"; \
			fi; \
		else \
			echo "⚠️  GitHub CLI not authenticated. Run 'gh auth login'"; \
		fi; \
	else \
		echo "⚠️  GitHub CLI not installed."; \
	fi
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║              🎉 Release Complete! 🎉                      ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📱 APK: build/app/outputs/flutter-apk/app-release.apk"
	@echo "📦 AAB: build/app/outputs/bundle/release/app-release.aab"
	@echo "🔗 Release: https://github.com/berlogabob/flutter-FlowGroove-app/releases/tag/v$(NEW_VERSION)"
	@echo ""

CURRENT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

# =============================================================================
# UTILITIES
# =============================================================================

clean-exports:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Moving Chat Exports to Archive                    ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@./scripts/move-chat-exports.sh
	@echo ""

# Rollback production deployment
rollback-production:
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Rolling Back Production Deployment                ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ -f $(BACKUP_INFO_FILE) ]; then \
		BACKUP_DIR=$$(cat $(BACKUP_INFO_FILE)); \
		echo "📦 Latest backup: $$BACKUP_DIR"; \
		echo ""; \
		read -p "Use this backup for rollback? (y/N): " -n 1 -r; \
		echo ""; \
		if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
			if [ -d "$$BACKUP_DIR" ]; then \
				echo "📤 Restoring from $$BACKUP_DIR..."; \
				source ./scripts/load-deploy-env.sh && \
				lftp -c "set ssl:verify-certificate $${FTP_SSL_VERIFY:-yes}; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes; set ftp:ssl-protect-list yes; open -u '$$FTP_USER','$$FTP_PASS' $$FTP_HOST; cd $${FTP_DIR:-$(FTP_DIR_DEFAULT)}; mirror --reverse $$BACKUP_DIR/ .; bye"; \
				echo "✅ Rollback complete!"; \
				echo "🌐 Production restored to previous version"; \
			else \
				echo "❌ ERROR: Backup directory not found: $$BACKUP_DIR"; \
				exit 1; \
			fi; \
		else \
			echo "📦 Available backups:"; \
			ls -1 backup/production-*/ 2>/dev/null | sed 's/^/   /' || echo "   No backups found!"; \
			echo ""; \
			read -p "Enter backup directory to restore: " BACKUP_DIR; \
			if [ -d "$$BACKUP_DIR" ]; then \
				echo "📤 Restoring from $$BACKUP_DIR..."; \
				source ./scripts/load-deploy-env.sh && \
				lftp -c "set ssl:verify-certificate $${FTP_SSL_VERIFY:-yes}; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes; set ftp:ssl-protect-list yes; open -u '$$FTP_USER','$$FTP_PASS' $$FTP_HOST; cd $${FTP_DIR:-$(FTP_DIR_DEFAULT)}; mirror --reverse $$BACKUP_DIR/ .; bye"; \
				echo "✅ Rollback complete!"; \
			else \
				echo "❌ ERROR: Backup directory not found: $$BACKUP_DIR"; \
				exit 1; \
			fi; \
		fi; \
	else \
		echo "📦 Available backups:"; \
		ls -1 backup/production-*/ 2>/dev/null | sed 's/^/   /' || echo "   No backups found!"; \
		echo ""; \
		read -p "Enter backup directory to restore: " BACKUP_DIR; \
		if [ -d "$$BACKUP_DIR" ]; then \
			echo "📤 Restoring from $$BACKUP_DIR..."; \
			source ./scripts/load-deploy-env.sh && \
			lftp -c "set ssl:verify-certificate $${FTP_SSL_VERIFY:-yes}; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes; set ftp:ssl-protect-list yes; open -u '$$FTP_USER','$$FTP_PASS' $$FTP_HOST; cd $${FTP_DIR:-$(FTP_DIR_DEFAULT)}; mirror --reverse $$BACKUP_DIR/ .; bye"; \
			echo "✅ Rollback complete!"; \
		else \
			echo "❌ ERROR: Backup directory not found: $$BACKUP_DIR"; \
			exit 1; \
		fi; \
	fi
	@echo ""

help-env:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║      Setting Environment Variables for Deployment         ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📋 PREVIEW / DEFAULT:"
	@echo ""
	@echo "  make -f Makefile.hugo deploy-all → GitHub Pages preview (safe)"
	@echo "  make deploy-test   → GitHub Pages Flutter-only publish"
	@echo "  make build-android → Android APK (demo config)"
	@echo "  make build-web     → Web build (demo config)"
	@echo ""
	@echo "  ✅ Firebase works (public key included)"
	@echo "  ⚠️  Spotify/Twitter disabled"
	@echo ""
	@echo "📝 For PRODUCTION (Hugo root + Flutter /app/ on FTP):"
	@echo ""
	@echo "  cp .env.example .env"
	@echo "  cp .ftp-env.example .ftp-env   # optional override for FTP-only values"
	@echo "  edit placeholders in .env / .ftp-env"
	@echo "  optional: export FTP_SSL_VERIFY=no   # when direct-IP FTPS fallback is required"
	@echo ""
	@echo "  Then: make deploy-stable"
	@echo ""
	@echo "  deploy-stable runs a preflight gate:"
	@echo "    - validates local non-tracked env sources"
	@echo "    - blocks tracked web/config.js"
	@echo "    - blocks staged backup/archive/secret-bearing paths"
	@echo ""
