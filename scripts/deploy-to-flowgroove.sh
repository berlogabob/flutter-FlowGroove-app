#!/bin/bash
# Deploy to flowgroove.app via FTP
# Usage: ./scripts/deploy-to-flowgroove.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Configuration from FileZilla export & FTP_data.md
# Using IP address directly (from FileZilla export)
FTP_HOST="${FTP_HOST:-194.39.124.68}"
FTP_USER="${FTP_USER:-sounding}"
FTP_PASS="${FTP_PASS:-M*9!atF0g43QJv}"
# Deploy to flowgroove.app subdirectory (as per FTP_data.md: /home/sounding/flowgroove.app/)
REMOTE_DIR="${REMOTE_DIR:-flowgroove.app}"

# Load from .ftp-env if it exists
if [ -f ".ftp-env" ]; then
    echo "📋 Loading credentials from .ftp-env..."
    source .ftp-env
fi

# Check if build/web exists
if [ ! -d "build/web" ]; then
    echo "❌ Build directory not found!"
    echo "Please run 'flutter build web' first"
    exit 1
fi

echo "🚀 Deploying to flowgroove.app..."
echo "   FTP Host: $FTP_HOST (194.39.124.68)"
echo "   FTP User: $FTP_USER"
echo "   Remote Dir: /$REMOTE_DIR/"
echo ""

# Use lftp for reliable FTP deployment with mirror
if command -v lftp >/dev/null 2>&1; then
    echo "📤 Uploading files via lftp..."
    lftp -c "
        set ftp:ssl-allow no
        open -u '$FTP_USER','$FTP_PASS' '$FTP_HOST'
        cd $REMOTE_DIR
        mirror --reverse --delete --only-newer '$PROJECT_DIR/build/web' .
        bye
    "
else
    # Fallback to curl-based upload
    echo "⚠️  lftp not found, using curl (slower)..."
    echo "💡 Install lftp for faster deployments: brew install lftp"
    echo ""
    
    # Create remote directory if it doesn't exist
    curl -s -u "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST/$REMOTE_DIR/" --create-dirs || true
    
    # Upload files
    find build/web -type f | while read file; do
        relative_path="${file#build/web/}"
        remote_path="$REMOTE_DIR/$relative_path"
        echo "  Uploading: $relative_path"
        curl -s -T "$file" -u "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST/$remote_path"
    done
fi

echo ""
echo "✅ Deployment to flowgroove.app complete!"
echo "🌐 URL: https://flowgroove.app/"
echo ""
echo "⏱️  SSL certificate and CDN propagation may take 1-5 minutes"
