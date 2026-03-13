# RepSync App - Makefile
# =============================================================================
# Simplified commands for common tasks
# =============================================================================

.PHONY: help deploy deploy-stable deploy-web deploy-android build clean test analyze

# Default target
help:
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║              RepSync App - Build Commands                 ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Available commands:"
	@echo ""
	@echo "  make deploy          Deploy to ALL platforms (web, FTP, GitHub, Firebase, Android)"
	@echo "  make deploy-stable   Same as 'make deploy' - full deployment"
	@echo ""
	@echo "  make deploy-web      Deploy web only (FTP + GitHub Pages + Firebase)"
	@echo "  make deploy-ftp     Deploy to FTP only"
	@echo "  make deploy-github  Deploy to GitHub Pages only"
	@echo "  make deploy-firebase Deploy to Firebase Hosting only"
	@echo ""
	@echo "  make build-web      Build web version"
	@echo "  make build-android  Build Android APK"
	@echo "  make build-all      Build all platforms"
	@echo ""
	@echo "  make clean          Clean build artifacts"
	@echo "  make test           Run tests"
	@echo "  make analyze        Run flutter analyze"
	@echo ""
	@echo "  make version        Show current version"
	@echo "  make bump           Bump build number"
	@echo ""

# Full deployment to all platforms
deploy: deploy-stable

deploy-stable:
	@echo "🚀 Starting full deployment..."
	@./scripts/deploy-stable

# Web deployment only
deploy-web: build-web
	@echo "🌐 Deploying web to all platforms..."
	@./scripts/deploy-all.sh --skip-android

deploy-ftp: build-web
	@./scripts/deploy-to-flowgroove.sh

deploy-github: build-web
	@echo "📄 Deploying to GitHub Pages..."
	@if command -v npx >/dev/null 2>&1; then \
		npx gh-pages -d build/web -b gh-pages -m "Deploy $$(grep '^version:' pubspec.yaml | sed 's/version: //')"; \
	else \
		echo "⚠️  npx not found, install nodejs or use deploy-all.sh"; \
	fi

deploy-firebase: build-web
	@echo "🔥 Deploying to Firebase..."
	@firebase deploy --only hosting

# Build commands
build-web:
	@echo "🔨 Building web..."
	@flutter build web

build-android:
	@echo "📱 Building Android APK..."
	@flutter build apk --release

build-all: build-web build-android
	@echo "✅ All builds complete!"

# Cleanup
clean:
	@echo "🧹 Cleaning..."
	@flutter clean
	@rm -rf build/
	@echo "✅ Clean complete!"

# Testing and analysis
test:
	@echo "🧪 Running tests..."
	@flutter test

analyze:
	@echo "🔍 Analyzing code..."
	@flutter analyze

# Version management
version:
	@echo "📦 Current version:"
	@grep "^version:" pubspec.yaml

bump:
	@echo "🔢 Bumping build number..."
	@perl -i -pe 's/^(version: \d+\.\d+\.\d+)\+(\d+)/$$1 . "+" . ($$2+1)/e' pubspec.yaml
	@echo "✅ Version bumped!"
	@make version

# Development
dev:
	@echo "▶️  Running in development mode..."
	@flutter run -d chrome

dev-web:
	@echo "▶️  Running web with sound null safety..."
	@flutter run -d chrome --web-renderer html

# Firebase
firebase-init:
	@echo "🔥 Initializing Firebase..."
	@firebase init

firebase-deploy:
	@firebase deploy --only hosting,firestore,storage

# GitHub
git-status:
	@git status --short

git-push:
	@echo "📤 Pushing to GitHub..."
	@git push origin main

# Installation checks
doctor:
	@flutter doctor

install-deps:
	@echo "📦 Installing dependencies..."
	@flutter pub get

# Icon generation
icons:
	@echo "🎨 Generating icons..."
	@./scripts/generate-icons.sh

# Version JSON
version-json:
	@echo "📝 Updating version.json..."
	@./scripts/fix-version.sh
