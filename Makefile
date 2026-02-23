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
	@echo "  make build-appbundle      - Build for Android App Bundle (Play Store)"
	@echo "  make build-all            - Build for web and Android"
	@echo "  make deploy-web           - Build web + copy to docs/"
	@echo "  make deploy               - Build web + copy + commit + push"
	@echo "  make release              - Full release: increment + build + deploy + GitHub Release"
	@echo "  make github-release       - Create GitHub Release only (with APK + AAB)"
	@echo "  make release-notes        - Generate release notes from git log"
	@echo "  make icons                - Generate app icons from logo (SOURCE=path/to/logo.png)"
	@echo "  make clean                - Clean build artifacts"
	@echo "  make test                 - Run all tests"
	@echo "  make analyze              - Run flutter analyze"
	@echo ""
	@echo "Examples:"
	@echo "  make release              # Full release cycle with GitHub Release"
	@echo "  make deploy               # Quick deploy to GitHub Pages"
	@echo "  make github-release       # Create GitHub Release with artifacts"
	@echo "  make icons SOURCE=logo.png # Generate all app icons from logo"
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
	@echo "🚀 Pushing to GitHub (current branch)..."
	@git push origin HEAD
	@echo ""
	@echo "✅ Deploy complete!"
	@echo "🌐 GitHub Pages: https://berlogabob.github.io/flutter-repsync-app/"
	@echo "⏱️  Deployment takes 1-2 minutes"

# Full release cycle: increment + build + deploy + GitHub Release
release: increment-version build-web build-android build-appbundle
	@echo ""
	@echo "📦 Copying web build to docs/..."
	@cp -r build/web/* docs/
	@echo "✅ Web build copied to docs/"
	@echo ""
	@echo "💾 Committing release..."
	@git add docs/ pubspec.yaml
	@git commit -m "Release $(NEW_VERSION)" || echo "No changes to commit"
	@echo ""
	@echo "🏷️  Creating git tag..."
	@git tag -a "v$(NEW_VERSION)" -m "Release $(NEW_VERSION)" || echo "Tag already exists"
	@echo ""
	@echo "🚀 Pushing to GitHub (current branch)..."
	@git push origin HEAD
	@git push origin "v$(NEW_VERSION)" || echo "Tag already pushed"
	@echo ""
	@echo "📱 Creating GitHub Release..."
	@if command -v gh >/dev/null 2>&1; then \
		if gh auth status >/dev/null 2>&1; then \
			if gh release view "v$(NEW_VERSION)" >/dev/null 2>&1; then \
				echo "⚠️  Release v$(NEW_VERSION) already exists!"; \
				echo "   To update: make github-release"; \
				echo "   To delete: gh release delete v$(NEW_VERSION) --cleanup-tag --yes"; \
			else \
				gh release create "v$(NEW_VERSION)" \
					--title "Release $(NEW_VERSION)" \
					--notes "Release $(NEW_VERSION) - $$(date +%Y-%m-%d)" \
					--target main \
					build/app/outputs/flutter-apk/app-release.apk#android-apk \
					build/app/outputs/bundle/release/app-release.aab#android-aab && \
				echo "✅ GitHub Release created!" || \
				(echo "" && echo "❌ Failed to create GitHub Release!" && echo "   Error: $$?" && echo "   Check files exist:" && ls -lh build/app/outputs/flutter-apk/app-release.apk build/app/outputs/bundle/release/app-release.aab 2>&1); \
			fi; \
		else \
			echo "⚠️  GitHub CLI not authenticated. Run 'gh auth login'"; \
		fi; \
	else \
		echo "⚠️  GitHub CLI not installed. Install from https://cli.github.com/"; \
	fi
	@echo ""
	@echo "🎉 Release $(NEW_VERSION) complete!"
	@echo ""
	@echo "📱 Artifacts:"
	@echo "   Web: https://berlogabob.github.io/flutter-repsync-app/"
	@echo "   Android APK: build/app/outputs/flutter-apk/app-release.apk"
	@echo "   Android AAB: build/app/outputs/bundle/release/app-release.aab"
	@echo "   GitHub Release: https://github.com/berlogabob/flutter-repsync-app/releases/tag/v$(NEW_VERSION)"
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

# Generate app icons from logo
# Usage: make icons SOURCE=path/to/logo.png
icons:
	@echo "🎨 Generating app icons..."
	@if [ -z "$(SOURCE)" ]; then \
		echo "⚠️  Please provide source image: make icons SOURCE=path/to/logo.png"; \
		exit 1; \
	fi
	@if [ ! -f "$(SOURCE)" ]; then \
		echo "❌ Source file not found: $(SOURCE)"; \
		exit 1; \
	fi
	@echo "📱 Generating Android icons..."
	@mkdir -p android/app/src/main/res/mipmap-mdpi
	@mkdir -p android/app/src/main/res/mipmap-hdpi
	@mkdir -p android/app/src/main/res/mipmap-xhdpi
	@mkdir -p android/app/src/main/res/mipmap-xxhdpi
	@mkdir -p android/app/src/main/res/mipmap-xxxhdpi
	@sips -z 48 48 $(SOURCE) --out android/app/src/main/res/mipmap-mdpi/ic_launcher.png 2>/dev/null || convert $(SOURCE) -resize 48x48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
	@sips -z 72 72 $(SOURCE) --out android/app/src/main/res/mipmap-hdpi/ic_launcher.png 2>/dev/null || convert $(SOURCE) -resize 72x72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
	@sips -z 96 96 $(SOURCE) --out android/app/src/main/res/mipmap-xhdpi/ic_launcher.png 2>/dev/null || convert $(SOURCE) -resize 96x96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
	@sips -z 144 144 $(SOURCE) --out android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png 2>/dev/null || convert $(SOURCE) -resize 144x144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
	@sips -z 192 192 $(SOURCE) --out android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png 2>/dev/null || convert $(SOURCE) -resize 192x192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
	@echo "🍎 Generating iOS icons..."
	@mkdir -p ios/Runner/Assets.xcassets/AppIcon.appiconset
	@sips -z 20 20 $(SOURCE) --out ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-20.png 2>/dev/null || convert $(SOURCE) -resize 20x20 ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-20.png
	@sips -z 29 29 $(SOURCE) --out ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-29.png 2>/dev/null || convert $(SOURCE) -resize 29x29 ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-29.png
	@sips -z 40 40 $(SOURCE) --out ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-40.png 2>/dev/null || convert $(SOURCE) -resize 40x40 ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-40.png
	@sips -z 60 60 $(SOURCE) --out ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-60.png 2>/dev/null || convert $(SOURCE) -resize 60x60 ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-60.png
	@sips -z 76 76 $(SOURCE) --out ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-76.png 2>/dev/null || convert $(SOURCE) -resize 76x76 ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-76.png
	@sips -z 83.5 83.5 $(SOURCE) --out ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-83.5.png 2>/dev/null || convert $(SOURCE) -resize 83.5x83.5 ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-83.5.png
	@sips -z 1024 1024 $(SOURCE) --out ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-1024.png 2>/dev/null || convert $(SOURCE) -resize 1024x1024 ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-1024.png
	@echo "🌐 Generating web icons..."
	@mkdir -p web/icons
	@sips -z 192 192 $(SOURCE) --out web/icons/icon-192.png 2>/dev/null || convert $(SOURCE) -resize 192x192 web/icons/icon-192.png
	@sips -z 512 512 $(SOURCE) --out web/icons/icon-512.png 2>/dev/null || convert $(SOURCE) -resize 512x512 web/icons/icon-512.png
	@echo ""
	@echo "✅ Icons generated successfully!"
	@echo ""
	@echo "📱 Android: android/app/src/main/res/mipmap-*/"
	@echo "🍎 iOS: ios/Runner/Assets.xcassets/AppIcon.appiconset/"
	@echo "🌐 Web: web/icons/"
	@echo ""
	@echo "⚠️  Note: You may need to update AndroidManifest.xml and Info.plist to reference new icons"

# Watch for changes and rebuild (development)
watch:
	@echo "👀 Watching for changes..."
	@flutter pub run build_runner watch

# Create GitHub Release only (without building)
github-release: build-appbundle
	@echo "📱 Creating GitHub Release..."
	@VERSION=$(shell grep '^version:' pubspec.yaml | sed 's/version: //') && \
	if command -v gh >/dev/null 2>&1; then \
		if gh auth status >/dev/null 2>&1; then \
			if gh release view "v$$VERSION" >/dev/null 2>&1; then \
				echo "⚠️  Release v$$VERSION already exists!"; \
				echo "   To delete: gh release delete v$$VERSION --cleanup-tag --yes"; \
				echo "   Or update: gh release upload v$$VERSION build/app/outputs/flutter-apk/app-release.apk build/app/outputs/bundle/release/app-release.aab"; \
			else \
				gh release create "v$$VERSION" \
					--title "Release $$VERSION" \
					--notes-file RELEASE_NOTES.md \
					--target main \
					build/app/outputs/flutter-apk/app-release.apk#android-apk \
					build/app/outputs/bundle/release/app-release.aab#android-aab && \
				echo "✅ GitHub Release created!" || \
				(echo "" && echo "❌ Failed to create GitHub Release!" && echo "   Error: $$?" && echo "   Check files exist:" && ls -lh build/app/outputs/flutter-apk/app-release.apk build/app/outputs/bundle/release/app-release.aab 2>&1); \
			fi; \
		else \
			echo "⚠️  GitHub CLI not authenticated. Run 'gh auth login'"; \
		fi; \
	else \
		echo "⚠️  GitHub CLI not installed. Install from https://cli.github.com/"; \
	fi

# Create release notes from git log
release-notes:
	@echo "📝 Creating release notes..."
	@echo "# Release $(NEW_VERSION)" > RELEASE_NOTES.md
	@echo "" >> RELEASE_NOTES.md
	@echo "**Date:** $$(date +%Y-%m-%d)" >> RELEASE_NOTES.md
	@echo "" >> RELEASE_NOTES.md
	@echo "## What's Changed" >> RELEASE_NOTES.md
	@echo "" >> RELEASE_NOTES.md
	@git log --oneline --no-merges -20 | sed 's/^/- /' >> RELEASE_NOTES.md
	@echo "" >> RELEASE_NOTES.md
	@echo "## Full Changelog" >> RELEASE_NOTES.md
	@echo "" >> RELEASE_NOTES.md
	@echo "https://github.com/berlogabob/flutter-repsync-app/compare/v$(CURRENT_VERSION)+$(shell echo $$(($(CURRENT_BUILD)-1)))...v$(NEW_VERSION)" >> RELEASE_NOTES.md
	@echo "✅ Release notes created: RELEASE_NOTES.md"
	@cat RELEASE_NOTES.md
