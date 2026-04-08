# FlowGroove App - Deployment Makefile
# =====================================
# Version: 0.13.5+180
# Last Updated: April 2, 2026
#
# Quick Start:
#   make deploy-test   → Test on GitHub Pages (no credentials needed)
#   make release       → Build Android APK + GitHub Release
#   make deploy-stable → Production FTP deploy (requires credentials)
#
# Demo Configuration:
#   - Firebase works out of the box (public key included)
#   - Spotify/Twitter disabled (add credentials later if needed)
#   - No .env file required for testing

.PHONY: help deploy-stable deploy-test release build-web build-web-github build-android check-env check-env-test check-env-prod help-env clean-exports

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
	@echo "  make deploy-test     # Test on GitHub Pages (recommended)"
	@echo "  make release         # Build Android APK + GitHub Release"
	@echo "  make deploy-stable   # Production FTP deployment"
	@echo ""
	@echo "📋 All Commands:"
	@echo ""
	@echo "  make deploy-test     - Deploy to GitHub Pages (test)"
	@echo "  make deploy-stable   - Deploy to FTP (flowgroove.app)"
	@echo "  make release         - Build Android APK + AAB + GitHub Release"
	@echo "  make build-android   - Build Android APK only"
	@echo "  make build-web       - Build web app (production)"
	@echo "  make clean-exports   - Archive chat exports"
	@echo "  make help-env        - Show environment variable setup"
	@echo ""
	@echo "📝 Documentation:"
	@echo ""
	@echo "  docs/MODERNIZATION_COMPLETE.md  - Full modernization report"
	@echo "  docs/MAKEFILE_MODERNIZATION_COMPLETE.md - Makefile guide"
	@echo "  DEPLOYMENT_GUIDE.md             - Deployment instructions"
	@echo ""

# =============================================================================
# PRE-DEPLOYMENT VALIDATION
# =============================================================================

check-env:
	@echo "Validating configuration..."

# For GitHub Pages test deployment - uses demo config (no credentials needed)
check-env-test:
	@cp web/config.demo.js web/config.js

# For production FTP deployment - requires environment variables
check-env-prod:
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
# STABLE DEPLOYMENT - FTP (flowgroove.app)
# =============================================================================

deploy-stable: check-env-prod build-web backup-production ftp-upload health-check-prod
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         ✅ FTP Deployment Complete!                       ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🌐 Live URL: https://flowgroove.app/"
	@echo "⏱️  SSL/CDN propagation: 1-5 minutes"
	@echo ""
	@echo "💾 Backup saved to: backup/production-$(shell date +%Y%m%d-%H%M%S)/"
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
	@mkdir -p backup/production-$(shell date +%Y%m%d-%H%M%S)
	@echo "📦 Downloading current production files..."
	@lftp -c "open -u '$(FTP_USER)','$(FTP_PASS)' $(FTP_HOST); cd $(FTP_DIR); mirror backup/production-$(shell date +%Y%m%d-%H%M%S)/" || echo "⚠️  Backup skipped (FTP credentials may be missing)"
	@echo "✅ Backup created"
	@echo ""
	@# Save latest backup path for auto-rollback
	@echo "backup/production-$(shell date +%Y%m%d-%H%M%S)" > /tmp/flowgroove-latest-backup.txt
	@echo "💾 Latest backup: backup/production-$(shell date +%Y%m%d-%H%M%S)/"
	@echo ""

# Upload to FTP with SSL support
ftp-upload:
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Uploading to FTP (flowgroove.app)                 ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📤 Uploading files..."
	@lftp -c "set ftp:ssl-allow yes; set ftp:ssl-protect-data yes; set ftp:ssl-protect-list yes; open -u '$(FTP_USER)','$(FTP_PASS)' $(FTP_HOST); cd $(FTP_DIR); mirror --reverse --delete build/web .; bye"
	@echo "✅ Upload complete"
	@echo ""

# Health check after deployment (with auto-rollback on failure)
health-check-prod:
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Running Post-Deployment Health Check              ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🔍 Checking production site..."
	@sleep 5  # Wait for CDN propagation
	@echo "📊 Checking site accessibility..."
	@if curl -f -s https://flowgroove.app/ > /dev/null; then \
		echo "✅ Site is accessible"; \
	else \
		echo "❌ ERROR: Site is not accessible!"; \
		echo "🚨 Auto-rollback initiated..."; \
		$(MAKE) auto-rollback; \
		exit 1; \
	fi
	@echo "📊 Checking config.js..."
	@if curl -f -s https://flowgroove.app/config.js | grep -q "FIREBASE_API_KEY"; then \
		echo "✅ config.js is present and valid"; \
	else \
		echo "❌ ERROR: config.js missing or invalid!"; \
		echo "🚨 Auto-rollback initiated..."; \
		$(MAKE) auto-rollback; \
		exit 1; \
	fi
	@echo "✅ Health check passed"
	@echo ""
	@echo "💾 Backup retained at: $(shell cat /tmp/flowgroove-latest-backup.txt 2>/dev/null || echo 'N/A')"
	@echo "   (for manual rollback if issues discovered later)"
	@echo ""

# Automatic rollback (called by health-check-prod on failure)
auto-rollback:
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         🚨 AUTO-ROLLBACK INITIATED                        ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ -f /tmp/flowgroove-latest-backup.txt ]; then \
		BACKUP_DIR=$$(cat /tmp/flowgroove-latest-backup.txt); \
		if [ -d "$$BACKUP_DIR" ]; then \
			echo "📦 Restoring from: $$BACKUP_DIR"; \
			lftp -c "open -u '$(FTP_USER)','$(FTP_PASS)' $(FTP_HOST); cd $(FTP_DIR); mirror --reverse $$BACKUP_DIR/ .; bye"; \
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
	@if [ ! -f web/config.js ]; then cp web/config.demo.js web/config.js; fi
	@echo "🔨 Building web app..."
	@echo "   Base href: / (FTP - flowgroove.app)"
	@flutter build web --release
	@echo ""
	@cp web/config.js build/web/config.js
	@echo "✅ Build complete!"
	@echo "📊 Build size: $$(du -sh build/web | cut -f1)"
	@echo ""

# Build for GitHub Pages - with subdirectory
build-web-github:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Building Web (GitHub Pages / Subdirectory)        ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📝 Updating version.json..."
	@./scripts/update-version-json.sh
	@echo ""
	@echo "🔨 Building web app..."
	@echo "   Base href: /flutter-FlowGroove-app/ (GitHub Pages)"
	@flutter build web --release --base-href "/flutter-FlowGroove-app/"
	@echo ""
	@cp web/config.js build/web/config.js
	@echo "✅ Build complete!"
	@echo "📊 Build size: $$(du -sh build/web | cut -f1)"
	@echo ""

# Build for Android APK - uses demo config
build-android:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║              Building Android APK                         ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ ! -f assets/env.json ]; then cp assets/env.demo.json assets/env.json; fi
	@echo "🤖 Building Android APK..."
	@flutter build apk --release
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
	@if [ ! -f assets/env.json ]; then cp assets/env.demo.json assets/env.json; fi
	@echo "🤖 Building Android App Bundle..."
	@flutter build appbundle --release
	@echo ""
	@echo "✅ AAB build complete!"
	@echo "📦 AAB: build/app/outputs/bundle/release/app-release.aab"
	@echo ""

# =============================================================================
# CONFIGURATION
# =============================================================================

# FTP Configuration (only needed for make deploy-stable)
FTP_HOST := $(FTP_HOST)
FTP_USER := $(FTP_USER)
FTP_PASS := $(FTP_PASS)
FTP_DIR := $(or $(FTP_DIR),flowgroove.app)

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
	@echo "💾 Committing changes..."
	@git add -A
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
	@if [ -f /tmp/flowgroove-latest-backup.txt ]; then \
		BACKUP_DIR=$$(cat /tmp/flowgroove-latest-backup.txt); \
		echo "📦 Latest backup: $$BACKUP_DIR"; \
		echo ""; \
		read -p "Use this backup for rollback? (y/N): " -n 1 -r; \
		echo ""; \
		if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
			if [ -d "$$BACKUP_DIR" ]; then \
				echo "📤 Restoring from $$BACKUP_DIR..."; \
				lftp -c "open -u '$(FTP_USER)','$(FTP_PASS)' $(FTP_HOST); cd $(FTP_DIR); mirror --reverse $$BACKUP_DIR/ .; bye"; \
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
				lftp -c "open -u '$(FTP_USER)','$(FTP_PASS)' $(FTP_HOST); cd $(FTP_DIR); mirror --reverse $$BACKUP_DIR/ .; bye"; \
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
			lftp -c "open -u '$(FTP_USER)','$(FTP_PASS)' $(FTP_HOST); cd $(FTP_DIR); mirror --reverse $$BACKUP_DIR/ .; bye"; \
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
	@echo "📋 DEFAULT (No credentials needed):"
	@echo ""
	@echo "  make deploy-test   → GitHub Pages (demo config)"
	@echo "  make build-android → Android APK (demo config)"
	@echo "  make build-web     → Web build (demo config)"
	@echo ""
	@echo "  ✅ Firebase works (public key included)"
	@echo "  ⚠️  Spotify/Twitter disabled"
	@echo ""
	@echo "📝 For PRODUCTION (with Spotify/Twitter):"
	@echo ""
	@echo "  export FIREBASE_API_KEY=your_key"
	@echo "  export SPOTIFY_CLIENT_ID=your_id"
	@echo "  export SPOTIFY_CLIENT_SECRET=your_secret"
	@echo "  export FTP_PASS=your_password"
	@echo ""
	@echo "  Then: make deploy-stable"
	@echo ""
