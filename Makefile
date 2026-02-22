# Makefile for Flutter RepSync App
# Build, Deploy, and Release Automation

.PHONY: help build-web build-android build-all deploy-web deploy-android release increment-version clean test analyze

# Default target
help:
	@echo "Flutter RepSync App - Build Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make increment-version    - Increment build number (e.g., 0.10.1+1 → 0.10.1+2)"
	@echo "  make build-web            - Build for web (GitHub Pages)"
	@echo "  make build-android        - Build for Android (APK)"
	@echo "  make build-all            - Build for web and Android"
	@echo "  make deploy-web           - Build web + copy to docs/"
	@echo "  make deploy               - Build web + copy to docs/ + commit + push"
	@echo "  make release              - Full release: increment + build + deploy"
	@echo "  make clean                - Clean build artifacts"
	@echo "  make test                 - Run all tests"
	@echo "  make analyze              - Run flutter analyze"
	@echo ""
	@echo "Examples:"
	@echo "  make release              # Full release cycle"
	@echo "  make deploy               # Quick deploy to GitHub Pages"
	@echo ""

# Get current version from pubspec.yaml
CURRENT_VERSION := $(shell grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
CURRENT_BUILD := $(shell grep '^version:' pubspec.yaml | sed 's/version: .*+//')
NEW_BUILD := $(shell echo $$(($(CURRENT_BUILD) + 1)))
NEW_VERSION := $(CURRENT_VERSION)+$(NEW_BUILD)

# Increment build number in pubspec.yaml
increment-version:
	@echo "📦 Current version: $(CURRENT_VERSION)+$(CURRENT_BUILD)"
	@echo "📦 New version: $(NEW_VERSION)"
	@sed -i '' 's/^version: .*/version: $(NEW_VERSION)/' pubspec.yaml
	@echo "✅ Version updated in pubspec.yaml"
	@grep '^version:' pubspec.yaml

# Build for Web (GitHub Pages)
build-web:
	@echo "🔨 Building web app..."
	@flutter build web --release --base-href "/flutter-repsync-app/"
	@echo "✅ Web build complete: build/web/"
	@ls -lh build/web/ | tail -5

# Build for Android (APK)
build-android:
	@echo "🤖 Building Android APK..."
	@flutter build apk --release
	@echo "✅ Android build complete: build/app/outputs/flutter-apk/app-release.apk"
	@ls -lh build/app/outputs/flutter-apk/app-release.apk

# Build for Android App Bundle (Play Store)
build-appbundle:
	@echo "🤖 Building Android App Bundle..."
	@flutter build appbundle --release
	@echo "✅ Android App Bundle complete: build/app/outputs/bundle/release/app-release.aab"
	@ls -lh build/app/outputs/bundle/release/app-release.aab

# Build for both Web and Android
build-all: build-web build-android
	@echo ""
	@echo "✅ All builds complete!"
	@echo "   Web: build/web/"
	@echo "   Android: build/app/outputs/flutter-apk/app-release.apk"

# Deploy web to docs/ (for GitHub Pages)
deploy-web: build-web
	@echo ""
	@echo "📦 Copying web build to docs/..."
	@cp -r build/web/* docs/
	@echo "✅ Web build copied to docs/"
	@echo ""
	@echo "📝 Next steps:"
	@echo "   git add docs/"
	@echo "   git commit -m 'Deploy web build $(NEW_VERSION)'"
	@echo "   git push origin main"

# Full deploy: build + copy + commit + push
deploy: build-web
	@echo ""
	@echo "📦 Copying web build to docs/..."
	@cp -r build/web/* docs/
	@echo "✅ Web build copied to docs/"
	@echo ""
	@echo "💾 Committing changes..."
	@git add docs/
	@git commit -m "Deploy web build $(NEW_VERSION)" || echo "No changes to commit"
	@echo ""
	@echo "🚀 Pushing to GitHub..."
	@git push origin main
	@echo ""
	@echo "✅ Deploy complete!"
	@echo "🌐 GitHub Pages: https://berlogabob.github.io/flutter-repsync-app/"
	@echo "⏱️  Deployment takes 1-2 minutes"

# Full release cycle: increment + build + deploy
release: increment-version build-web build-android
	@echo ""
	@echo "📦 Copying web build to docs/..."
	@cp -r build/web/* docs/
	@echo "✅ Web build copied to docs/"
	@echo ""
	@echo "💾 Committing release..."
	@git add docs/ pubspec.yaml
	@git commit -m "Release $(NEW_VERSION)"
	@echo ""
	@echo "🏷️  Creating git tag..."
	@git tag -a "v$(NEW_VERSION)" -m "Release $(NEW_VERSION)"
	@echo ""
	@echo "🚀 Pushing to GitHub..."
	@git push origin main
	@git push origin "v$(NEW_VERSION)"
	@echo ""
	@echo "🎉 Release $(NEW_VERSION) complete!"
	@echo ""
	@echo "📱 Artifacts:"
	@echo "   Web: https://berlogabob.github.io/flutter-repsync-app/"
	@echo "   Android APK: build/app/outputs/flutter-apk/app-release.apk"
	@echo "   Android AAB: build/app/outputs/bundle/release/app-release.aab"
	@echo ""
	@echo "📝 Next steps:"
	@echo "   1. Test web deployment"
	@echo "   2. Test Android APK on device"
	@echo "   3. Upload AAB to Google Play Console (if needed)"
	@echo "   4. Update CHANGELOG.md"

# Quick release (increment + web deploy only)
release-web: increment-version deploy
	@echo ""
	@echo "🎉 Web release $(NEW_VERSION) complete!"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@flutter clean
	@rm -rf build/
	@echo "✅ Clean complete"

# Run all tests
test:
	@echo "🧪 Running tests..."
	@flutter test --coverage
	@echo ""
	@echo "✅ Tests complete!"
	@echo "📊 Coverage report: coverage/lcov.info"
	@echo "📊 HTML report: coverage/html/index.html"
	@echo ""
	@echo "To view HTML report:"
	@echo "  genhtml coverage/lcov.info -o coverage/html"
	@echo "  open coverage/html/index.html"

# Run flutter analyze
analyze:
	@echo "🔍 Running flutter analyze..."
	@flutter analyze
	@echo ""
	@echo "✅ Analysis complete"

# Show current version
version:
	@echo "📦 Current version: $(CURRENT_VERSION)+$(CURRENT_BUILD)"
	@echo "📦 Next version: $(NEW_VERSION)"

# Show build info
info:
	@echo "Flutter RepSync App - Build Info"
	@echo "================================"
	@echo ""
	@echo "Version: $(CURRENT_VERSION)+$(CURRENT_BUILD)"
	@echo "Next Version: $(NEW_VERSION)"
	@echo ""
	@echo "Flutter version:"
	@flutter --version
	@echo ""
	@echo "Dependencies:"
	@flutter pub get
	@echo ""

# Install dependencies
deps:
	@echo "📦 Installing dependencies..."
	@flutter pub get
	@echo "✅ Dependencies installed"

# Run on connected device
run:
	@echo "🚀 Running on connected device..."
	@flutter run --release

# Run on web (Chrome)
run-web:
	@echo "🌐 Running on Chrome..."
	@flutter run -d chrome

# Run on Android device
run-android:
	@echo "🤖 Running on Android device..."
	@flutter run -d android

# Generate mocks for tests
mocks:
	@echo "🔨 Generating mocks..."
	@flutter pub run build_runner build --delete-conflicting-outputs
	@echo "✅ Mocks generated"

# Watch for changes and rebuild (development)
watch:
	@echo "👀 Watching for changes..."
	@flutter pub run build_runner watch

# Create release notes
release-notes:
	@echo "📝 Creating release notes..."
	@echo "# Release $(NEW_VERSION)" > RELEASE_NOTES.md
	@echo "" >> RELEASE_NOTES.md
	@echo "**Date:** $$(date +%Y-%m-%d)" >> RELEASE_NOTES.md
	@echo "" >> RELEASE_NOTES.md
	@echo "## Changes" >> RELEASE_NOTES.md
	@echo "" >> RELEASE_NOTES.md
	@git log --oneline --no-merges -10 >> RELEASE_NOTES.md
	@echo "" >> RELEASE_NOTES.md
	@echo "✅ Release notes created: RELEASE_NOTES.md"
	@cat RELEASE_NOTES.md
