#!/bin/bash
# mirror-feed.sh — push the freshly-built Hugo RSS (site/public/index.xml) to a public
# GCS object so the Reddit Devvit bot (reddit-bot/) can fetch it: storage.googleapis.com
# is on Reddit's global fetch allowlist, flowgroove.app is not.
# Called by scripts/deploy-hugo.sh (Pages path) and scripts/devlog-daily.sh (prod drip).
# ponytail: best-effort — never fail the caller if gcloud/auth is missing.
set -u
cd "$(dirname "$0")/.."

FEED_BUCKET="gs://repsync-app-8685c.firebasestorage.app/reddit-feed.xml"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "⚠️  gcloud not found — skipped Reddit feed mirror"
  exit 0
fi
if [ ! -f site/public/index.xml ]; then
  echo "⚠️  site/public/index.xml missing — build Hugo first; skipping feed mirror"
  exit 0
fi

echo "📡 Mirroring feed to $FEED_BUCKET for the Reddit bot..."
# gcloud's python sometimes resolves to a broken interpreter; pin Homebrew python.
export CLOUDSDK_PYTHON="${CLOUDSDK_PYTHON:-$(ls /opt/homebrew/bin/python3.[0-9]* 2>/dev/null | grep -E 'python3\.[0-9]+$' | sort -V | tail -1)}"
# cp resets the object ACL, so re-grant public-read on this one object after each upload.
# Only this object is public; private avatars in the bucket are unaffected (UBLA is off).
if gcloud storage cp site/public/index.xml "$FEED_BUCKET" \
     --content-type=application/rss+xml --cache-control="public,max-age=300" \
   && gcloud storage objects update "$FEED_BUCKET" --add-acl-grant=entity=AllUsers,role=READER; then
  echo "✅ Feed mirrored"
else
  echo "⚠️  Feed mirror failed (Reddit bot will serve stale feed) — skipping"
fi
exit 0
