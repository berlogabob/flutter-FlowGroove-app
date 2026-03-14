# FlowGroove App - Simple Deployment Makefile
# =============================================
# Two commands only:
#   make deploy-stable   - Deploy to FTP (flowgroove.app)
#   make deploy-test     - Deploy to GitHub Pages (test)

.PHONY: help deploy-stable deploy-test build-web build-web-github

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
	@echo ""
	@echo "Examples:"
	@echo "  make deploy-stable   # Production deployment"
	@echo "  make deploy-test     # Test deployment"
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

# =============================================================================
# CONFIGURATION
# =============================================================================

# FTP Configuration (can be overridden with environment variables)
FTP_HOST ?= 194.39.124.68
FTP_USER ?= sounding
FTP_PASS ?= M*9!atF0g43QJv
FTP_DIR ?= flowgroove.app
