# FlowGroove App - Deployment Makefile
# =====================================
# Version: 0.13.4+194
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

.PHONY: help test-fast test-firebase-emulator deploy-rules deploy-stable deploy-test release release-all build-all bump-version build-appbundle build-release-artifacts build-github-pages build-web build-web-prod build-web-github package-github-pages build-android hugo-build-prod check-env check-env-test check-env-prod preflight-prod help-env clean-exports

DEPLOY_TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
BACKUP_DIR := backup/production-$(DEPLOY_TIMESTAMP)
BACKUP_INFO_FILE := /tmp/flowgroove-latest-backup.txt
FTP_DIR_DEFAULT := flowgroove.app
FIREBASE_EMULATOR_TEST_FILES := integration_test/auth_flow_test.dart integration_test/setlist_management_test.dart
GITHUB_PAGES_BASE_HREF ?= /flutter-FlowGroove-app/
GITHUB_PAGES_DIST ?= docs
FTP_WEB_DIST ?= dist/ftp-web
RELEASE_GIT_PATHS ?= Makefile Makefile.hugo pubspec.yaml web/version.json assets firestore.indexes.json firestore.rules ios android macos docs lib scripts test

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
	@echo "  make build-all       # Build all 3 release artifacts (FTP + Pages + Android), no deploy"
	@echo "  make release-all     # Deploy all 3 channels (FTP + Pages + Android release)"
	@echo "  make -f Makefile.hugo deploy-all  # Safe GitHub Pages preview"
	@echo "  make release         # Build Android APK + GitHub Release"
	@echo "  make build-release-artifacts # Build GitHub Pages web + Android APK"
	@echo "  make deploy-stable   # Production FTP (Hugo + Flutter)"
	@echo "  make test-fast       # Full fast Flutter suite"
	@echo "  make test-firebase-emulator  # Auth/Firestore emulator acceptance suite"
	@echo ""
	@echo "📦 Combined (all three release types):"
	@echo ""
	@echo "  make build-all       - Build FTP web + GitHub Pages web + Android APK/AAB (no deploy)"
	@echo "  make release-all     - Deploy FTP + GitHub Pages + Android release (outward-facing!)"
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
	@echo "📤 Uploading .well-known/ (Android App Links assetlinks.json) → /.well-known/ (merge, no delete)..."
	@source ./scripts/load-deploy-env.sh && \
		if [ -d site/public/.well-known ]; then \
			lftp -c "set ssl:verify-certificate $${FTP_SSL_VERIFY:-yes}; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes; set ftp:ssl-protect-list yes; open -u '$$FTP_USER','$$FTP_PASS' $$FTP_HOST; cd $${FTP_DIR:-$(FTP_DIR_DEFAULT)}; mkdir -p .well-known; mirror --reverse site/public/.well-known/ .well-known/; bye"; \
		fi
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
# COMBINED RELEASE TARGETS (all three channels)
# =============================================================================

# Build all three release artifacts locally — no upload, no git push, no tag.
#   1. FTP web      (base-href /app/, production config) → $(FTP_WEB_DIST)/
#   2. GitHub Pages (base-href $(GITHUB_PAGES_BASE_HREF), demo config) → $(GITHUB_PAGES_DIST)/
#   3. Android      (APK + AAB)                          → build/app/outputs/
#
# Order matters: the FTP build needs the production web/config.js, and the
# GitHub Pages step overwrites web/config.js with the demo config — so the FTP
# build runs first and its output is copied aside before the Pages build
# clobbers build/web/. Requires production env (.env / .ftp-env) for the FTP step.
build-all: check-env-prod build-web-prod
	@echo "📦 Packaging FTP web build → $(FTP_WEB_DIST)/..."
	@rm -rf "$(FTP_WEB_DIST)"
	@mkdir -p "$(FTP_WEB_DIST)"
	@cp -R build/web/. "$(FTP_WEB_DIST)/"
	@$(MAKE) package-github-pages
	@$(MAKE) build-android
	@$(MAKE) build-appbundle
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         ✅ All Release Artifacts Built                    ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🌐 FTP web (/app/):  $(FTP_WEB_DIST)/"
	@echo "🌐 GitHub Pages:     $(GITHUB_PAGES_DIST)/"
	@echo "📱 Android APK:      build/app/outputs/flutter-apk/app-release.apk"
	@echo "📦 Android AAB:      build/app/outputs/bundle/release/app-release.aab"
	@echo ""
	@echo "ℹ️  Nothing was deployed. To publish all three, run: make release-all"
	@echo ""

# Deploy Firestore + Storage security rules to Firebase.
# These are committed by the release flow but NOT auto-deployed, so production
# rules can drift behind the code. Deploy them here so a release never ships an
# app build whose required rules aren't live yet. Hard-fails if the firebase CLI
# is missing so a release can't silently skip rules. Uses the .firebaserc default
# project (repsync-app-8685c).
deploy-rules:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Deploying Firestore + Storage Rule                ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@command -v firebase >/dev/null 2>&1 || { \
		echo "❌ firebase CLI not installed — cannot deploy rules. Aborting release."; \
		exit 1; \
	}
	firebase deploy --only firestore:rules,storage
	@echo "✅ Firestore + Storage rules deployed"

# Deploy all three release channels — OUTWARD-FACING and largely irreversible.
#   0. Rules   → Firestore + Storage security rules (deployed FIRST)
#   1. FTP     → flowgroove.app (Hugo root + Flutter /app/, with backup + health check)
#   2. Pages   → GitHub Pages (Hugo + Flutter), git commit + push
#   3. Android → version bump + git tag + push + GitHub Release (APK + AAB)
release-all: deploy-rules deploy-stable
	@$(MAKE) -f Makefile.hugo deploy-all
	@$(MAKE) release
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         🎉 All Release Channels Deployed                  ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🌐 FTP:          https://flowgroove.app/  (app: /app/)"
	@echo "🌐 GitHub Pages: https://berlogabob.github.io/flutter-FlowGroove-app/"
	@echo "📱 Android:      see GitHub Releases"
	@echo ""

# =============================================================================
# CONFIGURATION
# =============================================================================

# FTP Configuration (loaded by scripts/load-deploy-env.sh)

# =============================================================================
# RELEASE - ANDROID APK + GITHUB RELEASE
# =============================================================================

# Bump the build number (default) or a semver level: make bump-version LEVEL=patch
bump-version:
	@./scripts/bump-build-number.sh $(LEVEL)

# Full release: bump version FIRST so the built artifacts carry the new number,
# then build APK + AAB, tag, push, and create the GitHub Release.
# Override the bump with: make release LEVEL=patch|minor|major
release:
	@echo "🔢 Bumping version before build..."
	@./scripts/bump-build-number.sh $(LEVEL)
	@$(MAKE) build-android
	@$(MAKE) build-appbundle
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Creating GitHub Release with Android APK          ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📝 Updating version.json..."
	@./scripts/update-version-json.sh
	@echo ""
	@set -e; \
	NEW_VERSION="$$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d '[:space:]')"; \
	echo "📦 Version: $$NEW_VERSION"; \
	echo ""; \
	if git rev-parse "v$$NEW_VERSION" >/dev/null 2>&1 || git ls-remote --exit-code --tags origin "v$$NEW_VERSION" >/dev/null 2>&1; then \
		echo "❌ Tag v$$NEW_VERSION already exists locally or on the remote — aborting before tagging."; \
		echo "   Run 'make release' again to bump to the next build number."; \
		exit 1; \
	fi; \
	echo "💾 Committing release-scoped changes..."; \
	git add $(RELEASE_GIT_PATHS); \
	git commit -m "Release $$NEW_VERSION" || echo "No changes to commit"; \
	echo ""; \
	echo "🏷️  Creating git tag..."; \
	git tag -a "v$$NEW_VERSION" -m "Release $$NEW_VERSION"; \
	echo ""; \
	echo "🚀 Pushing to GitHub..."; \
	git push origin HEAD; \
	git push origin "v$$NEW_VERSION"; \
	echo ""; \
	echo "📱 Creating GitHub Release..."; \
	if command -v gh >/dev/null 2>&1; then \
		if gh auth status >/dev/null 2>&1; then \
			if gh release view "v$$NEW_VERSION" >/dev/null 2>&1; then \
				echo "⚠️  Release v$$NEW_VERSION already exists!"; \
			else \
				gh release create "v$$NEW_VERSION" \
					--title "Release $$NEW_VERSION" \
					--notes "Release $$NEW_VERSION - $$(date +%Y-%m-%d)" \
					--target "$$(git rev-parse --abbrev-ref HEAD)" \
					build/app/outputs/flutter-apk/app-release.apk#flowgroove-android.apk \
					build/app/outputs/bundle/release/app-release.aab#aab && \
				echo "✅ GitHub Release created!"; \
			fi; \
		else \
			echo "⚠️  GitHub CLI not authenticated. Run 'gh auth login'"; \
		fi; \
	else \
		echo "⚠️  GitHub CLI not installed."; \
	fi; \
	echo ""; \
	echo "╔═══════════════════════════════════════════════════════════╗"; \
	echo "║              🎉 Release Complete! 🎉                      ║"; \
	echo "╚═══════════════════════════════════════════════════════════╝"; \
	echo ""; \
	echo "📱 APK: build/app/outputs/flutter-apk/app-release.apk"; \
	echo "📦 AAB: build/app/outputs/bundle/release/app-release.aab"; \
	echo "🔗 Release: https://github.com/berlogabob/flutter-FlowGroove-app/releases/tag/v$$NEW_VERSION"; \
	echo ""

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
