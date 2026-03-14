# FlowGroove App - Simple Deployment Makefile
# =============================================
# Three commands:
#   make deploy-stable   - Deploy to FTP (flowgroove.app)
#   make deploy-test     - Deploy to GitHub Pages (test)
#   make release         - Build Android + GitHub Release

.PHONY: help deploy-stable deploy-test release build-web build-web-github build-android

# Default target
help:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         FlowGroove App - Deployment Commands              ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Available commands:"
	@echo ""
	@echo "  make deploy-stable   - Build + Deploy to FTP (flowgroove.app)"
	@echo "  make deploy-test     - Build + Deploy to GitHub Pages (test)"
	@echo "  make release         - Build Android APK + GitHub Release"
	@echo ""
	@echo "Examples:"
	@echo "  make deploy-stable   # Production deployment"
	@echo "  make deploy-test     # Test deployment"
	@echo "  make release         # Android release with GitHub Release"
	@echo ""

# =============================================================================
# STABLE DEPLOYMENT - FTP (flowgroove.app)
# =============================================================================
deploy-stable: build-web
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Deploying to FTP (flowgroove.app)                 ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📤 Uploading to FTP..."
	@lftp -c "set ftp:ssl-allow no; open -u '$(FTP_USER)','$(FTP_PASS)' $(FTP_HOST); cd $(FTP_DIR); rm -rf *; mirror --reverse --delete build/web .; bye"
	@echo ""
	@echo "✅ FTP deployment complete!"
	@echo "🌐 Live URL: https://flowgroove.app/"
	@echo "⏱️  SSL/CDN propagation: 1-5 minutes"
	@echo ""

# =============================================================================
# TEST DEPLOYMENT - GitHub Pages (second01 branch, /docs folder)
# =============================================================================
deploy-test: build-web-github
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║      Deploying to GitHub Pages (second01 branch)          ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Copying to docs/..."
	@rm -rf docs/*
	@cp -r build/web/* docs/
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
# BUILD COMMANDS
# =============================================================================

# Build for FTP (flowgroove.app) - root domain
build-web:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║              Building Web (FTP / Root)                    ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📝 Updating version.json..."
	@./scripts/update-version-json.sh
	@echo ""
	@echo "🔨 Building web app..."
	@echo "   Base href: / (FTP - flowgroove.app)"
	@flutter build web --release
	@echo ""
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
	@echo "✅ Build complete!"
	@echo "📊 Build size: $$(du -sh build/web | cut -f1)"
	@echo ""

# Build for Android APK
build-android:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║              Building Android APK                         ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🤖 Building Android APK..."
	@flutter build apk --release
	@echo ""
	@echo "✅ Android build complete!"
	@APK_SIZE=$$(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1); \
	echo "   APK size: $$APK_SIZE"
	@echo ""
	@echo "📱 APK location: build/app/outputs/flutter-apk/app-release.apk"
	@echo ""

# =============================================================================
# CONFIGURATION
# =============================================================================

# FTP Configuration (can be overridden with environment variables)
FTP_HOST ?= 194.39.124.68
FTP_USER ?= sounding
FTP_PASS ?= M*9!atF0g43QJv
FTP_DIR ?= flowgroove.app

# =============================================================================
# RELEASE - ANDROID APK + GITHUB RELEASE
# =============================================================================
release: build-android
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║         Creating GitHub Release with Android APK          ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📝 Getting version info..."
	$(eval NEW_VERSION := $(shell grep "^version:" pubspec.yaml | sed 's/version: //'))
	@echo "   Version: $(NEW_VERSION)"
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
				echo "   To update: gh release upload v$(NEW_VERSION) build/app/outputs/flutter-apk/app-release.apk"; \
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
		echo "⚠️  GitHub CLI not installed. Install from https://cli.github.com/"; \
	fi
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║              🎉 Release Complete! 🎉                      ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Version: $(NEW_VERSION)"
	@echo "📱 Android APK: build/app/outputs/flutter-apk/app-release.apk"
	@echo "📦 Android AAB: build/app/outputs/bundle/release/app-release.aab"
	@echo "🔗 GitHub Release: https://github.com/berlogabob/flutter-FlowGroove-app/releases/tag/v$(NEW_VERSION)"
	@echo ""
	@echo "📝 Next steps:"
	@echo "   1. Test Android APK on device"
	@echo "   2. Upload AAB to Google Play Console (if needed)"
	@echo "   3. Share GitHub Release link with testers"
	@echo ""

# Get current branch
CURRENT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
