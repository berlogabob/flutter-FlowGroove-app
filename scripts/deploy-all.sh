#!/bin/bash
# =============================================================================
# FlowGroove Multi-Platform Deployment Script
# =============================================================================
# Builds and deploys to ALL platforms simultaneously:
# - FTP (flowgroove.app)
# - GitHub Pages
# - Firebase Hosting
# - Android APK
# - Git commit & tag
#
# Usage: ./scripts/deploy-all.sh [--skip-android] [--skip-ftp] [--skip-github] [--skip-firebase]
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# =============================================================================
# Configuration
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
SKIP_ANDROID=false
SKIP_FTP=false
SKIP_GITHUB=false
SKIP_FIREBASE=false

for arg in "$@"; do
    case $arg in
        --skip-android) SKIP_ANDROID=true ;;
        --skip-ftp) SKIP_FTP=true ;;
        --skip-github) SKIP_GITHUB=true ;;
        --skip-firebase) SKIP_FIREBASE=true ;;
    esac
done

# FTP credentials
FTP_HOST="${FTP_HOST:-194.39.124.68}"
FTP_USER="${FTP_USER:-sounding}"
FTP_PASS="${FTP_PASS:-M*9!atF0g43QJv}"
REMOTE_DIR="${REMOTE_DIR:-flowgroove.app}"

# GitHub Pages configuration
GITHUB_REPO="berlogabob/flutter-FlowGroove-app"
GITHUB_PAGES_BRANCH="gh-pages"

# Firebase project
FIREBASE_PROJECT="repsync-app-8685c"

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📍 $1${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# =============================================================================
# Main Deployment Process
# =============================================================================

echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         FlowGroove Multi-Platform Deployment              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Read version from pubspec.yaml
VERSION_LINE=$(grep "^version:" pubspec.yaml)
VERSION=$(echo $VERSION_LINE | sed 's/version: \([0-9.]*\)+.*/\1/')
BUILD_NUMBER=$(echo $VERSION_LINE | sed 's/version: .*+\([0-9]*\)/\1/')

echo "📦 Current Version: ${YELLOW}$VERSION+$BUILD_NUMBER${NC}"
echo ""

# Get current time in Lisbon timezone
LISBON_TIME=$(TZ="Europe/Lisbon" date +"%Y-%m-%dT%H:%M:%SZ")
echo "🕐 Build Time (Lisbon): ${YELLOW}$LISBON_TIME${NC}"
echo ""

# =============================================================================
# Step 1: Update version.json
# =============================================================================
log_step "Step 1: Updating version.json"

cat > web/version.json << EOF
{
  "version": "$VERSION",
  "buildNumber": "$BUILD_NUMBER",
  "buildDate": "$LISBON_TIME"
}
EOF

log_success "version.json updated"

# =============================================================================
# Step 2: Clean and Build Web
# =============================================================================
log_step "Step 2: Building Web Version"

log_info "Cleaning previous builds..."
flutter clean

log_info "Building web release..."
flutter build web --release

if [ -d "build/web" ]; then
    log_success "Web build completed"
    log_info "Build size: $(du -sh build/web | cut -f1)"
else
    log_error "Web build failed!"
    exit 1
fi

# =============================================================================
# Step 3: Deploy to FTP (flowgroove.app)
# =============================================================================
if [ "$SKIP_FTP" = false ]; then
    log_step "Step 3: Deploying to FTP (flowgroove.app)"

    if command -v lftp >/dev/null 2>&1; then
        log_info "Uploading via lftp..."
        lftp -c "
            set ftp:ssl-allow no
            open -u '$FTP_USER','$FTP_PASS' '$FTP_HOST'
            cd $REMOTE_DIR
            mirror --reverse --delete --only-newer '$PROJECT_DIR/build/web' .
            bye
        "
        log_success "FTP deployment complete"
    else
        log_warning "lftp not installed, using curl (slower)..."
        log_info "Install lftp for faster deployments: brew install lftp"

        curl -s -u "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST/$REMOTE_DIR/" --create-dirs || true

        find build/web -type f | while read file; do
            relative_path="${file#build/web/}"
            remote_path="$REMOTE_DIR/$relative_path"
            curl -s -T "$file" -u "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST/$remote_path"
        done
        log_success "FTP deployment complete (curl mode)"
    fi

    log_info "🌐 Live URL: https://flowgroove.app/"
    log_warning "⏱️  SSL/CDN propagation may take 1-5 minutes"
else
    log_warning "Skipping FTP deployment (--skip-ftp)"
fi

# =============================================================================
# Step 4: Deploy to GitHub Pages
# =============================================================================
if [ "$SKIP_GITHUB" = false ]; then
    log_step "Step 4: Deploying to GitHub Pages"

    # Check if gh-pages branch exists
    if git rev-parse --verify origin/$GITHUB_PAGES_BRANCH >/dev/null 2>&1; then
        log_info "Found existing $GITHUB_PAGES_BRANCH branch"
    else
        log_info "Creating $GITHUB_PAGES_BRANCH branch..."
        git checkout --orphan $GITHUB_PAGES_BRANCH
        git reset --hard
        git commit --allow-empty -m "Initial commit"
        git checkout -
    fi

    # Deploy using gh-pages package or git
    if [ -f "package.json" ] && command -v npx >/dev/null 2>&1; then
        log_info "Deploying via gh-pages package..."
        npx gh-pages -d build/web -b $GITHUB_PAGES_BRANCH -m "Deploy $VERSION+$BUILD_NUMBER"
    else
        log_info "Deploying via git..."
        git worktree add -f gh-pages-temp $GITHUB_PAGES_BRANCH
        cd gh-pages-temp
        rm -rf ./*
        cp -r ../build/web/. .
        git add -A
        git commit -m "Deploy $VERSION+$BUILD_NUMBER to GitHub Pages"
        git push origin $GITHUB_PAGES_BRANCH
        cd ..
        git worktree remove gh-pages-temp
    fi

    log_success "GitHub Pages deployment complete"
    log_info "🌐 URL: https://$GITHUB_REPO.github.io/"
else
    log_warning "Skipping GitHub Pages deployment (--skip-github)"
fi

# =============================================================================
# Step 5: Deploy to Firebase Hosting
# =============================================================================
if [ "$SKIP_FIREBASE" = false ]; then
    log_step "Step 5: Deploying to Firebase Hosting"

    if command -v firebase >/dev/null 2>&1; then
        log_info "Deploying to Firebase..."
        firebase deploy --only hosting --project $FIREBASE_PROJECT

        log_success "Firebase deployment complete"
        log_info "🌐 URL: https://$FIREBASE_PROJECT.web.app/"
    else
        log_warning "Firebase CLI not installed. Skipping Firebase deployment."
        log_info "Install: npm install -g firebase-tools"
    fi
else
    log_warning "Skipping Firebase deployment (--skip-firebase)"
fi

# =============================================================================
# Step 6: Build Android APK
# =============================================================================
if [ "$SKIP_ANDROID" = false ]; then
    log_step "Step 6: Building Android APK"

    if command -v flutter >/dev/null 2>&1; then
        log_info "Building Android release APK..."

        # Check if Android platform exists
        if [ -d "android" ]; then
            flutter build apk --release

            if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
                log_success "Android APK built successfully"
                log_info "📱 APK location: build/app/outputs/flutter-apk/app-release.apk"
                log_info "📊 APK size: $(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)"
            else
                log_error "APK build failed - file not found"
            fi
        else
            log_warning "Android platform not found. Run: flutter create ."
        fi
    else
        log_warning "Flutter not found. Skipping Android build."
    fi
else
    log_warning "Skipping Android build (--skip-android)"
fi

# =============================================================================
# Step 7: Git Commit and Tag
# =============================================================================
log_step "Step 7: Git Commit and Tag"

# Check for changes
if [ -n "$(git status --porcelain)" ]; then
    log_info "Committing changes..."
    git add -A
    git commit -m "chore: deploy v$VERSION+$BUILD_NUMBER

Platforms:
- Web: flowgroove.app
- GitHub Pages: berlogabob.github.io/flutter-FlowGroove-app
- Firebase: $FIREBASE_PROJECT.web.app
- Android APK: build/app/outputs/flutter-apk/app-release.apk

Build: $LISBON_TIME"

    log_success "Changes committed"
else
    log_info "No changes to commit"
fi

# Create git tag
TAG_NAME="v$VERSION+$BUILD_NUMBER"
if ! git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    log_info "Creating tag: $TAG_NAME"
    git tag -a "$TAG_NAME" -m "Release $VERSION+$BUILD_NUMBER - $LISBON_TIME"
    log_success "Tag created: $TAG_NAME"
else
    log_warning "Tag already exists: $TAG_NAME"
fi

# Push to GitHub
log_info "Pushing to GitHub..."
git push origin main
git push origin "$TAG_NAME"
log_success "Git push complete"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              🎉 Deployment Complete! 🎉                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo "📦 Version: ${YELLOW}$VERSION+$BUILD_NUMBER${NC}"
echo "🕐 Build Time: ${YELLOW}$LISBON_TIME${NC}"
echo ""

if [ "$SKIP_FTP" = false ]; then
    echo "✅ FTP (flowgroove.app): ${BLUE}https://flowgroove.app/${NC}"
fi

if [ "$SKIP_GITHUB" = false ]; then
    echo "✅ GitHub Pages: ${BLUE}https://berlogabob.github.io/flutter-FlowGroove-app/${NC}"
fi

if [ "$SKIP_FIREBASE" = false ]; then
    echo "✅ Firebase Hosting: ${BLUE}https://$FIREBASE_PROJECT.web.app/${NC}"
fi

if [ "$SKIP_ANDROID" = false ]; then
    echo "✅ Android APK: ${BLUE}build/app/outputs/flutter-apk/app-release.apk${NC}"
fi

echo ""
echo "📝 Git Tag: ${YELLOW}$TAG_NAME${NC}"
echo "🔗 GitHub: ${BLUE}https://github.com/$GITHUB_REPO/releases/tag/$TAG_NAME${NC}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
