#!/bin/bash
# deploy-hugo.sh — Build Hugo and copy to docs/ for GitHub Pages deploy
set -e
cd "$(dirname "$0")/.."
echo "🔨 Building Hugo site..."
cd site && hugo --minify
cd ..
echo "📦 Copying to docs/..."
rm -rf docs/404 docs/about docs/assets docs/blog docs/categories docs/faq docs/images docs/page docs/privacy docs/tags docs/terms docs/index.html docs/index.xml docs/sitemap.xml docs/robots.txt docs/favicon*.png docs/apple-touch-icon.png docs/safari-pinned-tab.svg 2>/dev/null
cp -r site/public/* docs/
echo "✅ Hugo deployed to docs/"
