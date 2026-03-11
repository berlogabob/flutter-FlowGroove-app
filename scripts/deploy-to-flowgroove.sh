#!/bin/bash
# Deploy to flowgroove.app via FTP
# Usage: ./deploy-to-flowgroove.sh [version]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Configuration
FTP_HOST="${FTP_HOST:-ftp.flowgroove.app}"
FTP_USER="${FTP_USER:-}"
FTP_PASS="${FTP_PASS:-}"
REMOTE_DIR="${REMOTE_DIR:-public_html}"

# Check if credentials are provided
if [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ]; then
    echo "❌ FTP credentials not set!"
    echo ""
    echo "Please set environment variables:"
    echo "  export FTP_USER=your_ftp_username"
    echo "  export FTP_PASS=your_ftp_password"
    echo ""
    echo "Or create a .ftp-env file (added to .gitignore):"
    echo "  FTP_USER=your_ftp_username"
    echo "  FTP_PASS=your_ftp_password"
    echo ""
    exit 1
fi

# Check if build/web exists
if [ ! -d "build/web" ]; then
    echo "❌ Build directory not found!"
    echo "Please run 'flutter build web' first"
    exit 1
fi

echo "🚀 Deploying to flowgroove.app..."
echo "   FTP Host: $FTP_HOST"
echo "   FTP User: $FTP_USER"
echo "   Remote Dir: $REMOTE_DIR"
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
