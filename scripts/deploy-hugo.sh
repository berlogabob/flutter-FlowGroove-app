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

# Mirror the RSS feed to a public GCS object so the Reddit Devvit bot (reddit-bot/) can
# fetch it: storage.googleapis.com is on Reddit's global fetch allowlist, flowgroove.app
# is not. ponytail: best-effort — don't fail the site deploy if gcloud/auth is missing.
FEED_BUCKET="gs://repsync-app-8685c.firebasestorage.app/reddit-feed.xml"
if command -v gcloud >/dev/null 2>&1; then
  echo "📡 Mirroring feed to $FEED_BUCKET for the Reddit bot..."
  # cp resets the object ACL, so re-grant public-read on this one object after each upload.
  # Only this object is public; private avatars in the bucket are unaffected (UBLA is off).
  export CLOUDSDK_PYTHON="${CLOUDSDK_PYTHON:-$(ls /opt/homebrew/bin/python3.[0-9]* 2>/dev/null | grep -E 'python3\.[0-9]+$' | sort -V | tail -1)}"
  if gcloud storage cp site/public/index.xml "$FEED_BUCKET" \
       --content-type=application/rss+xml --cache-control="public,max-age=300" \
     && gcloud storage objects update "$FEED_BUCKET" --add-acl-grant=entity=AllUsers,role=READER; then
    echo "✅ Feed mirrored"
  else
    echo "⚠️  Feed mirror failed (Reddit bot will serve stale feed) — skipping"
  fi
else
  echo "⚠️  gcloud not found — skipped Reddit feed mirror"
fi
