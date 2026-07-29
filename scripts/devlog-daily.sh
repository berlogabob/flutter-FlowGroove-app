#!/bin/bash
# devlog-daily.sh — launch-window job for the 2026-06-29..2026-08-12 devlog series drip.
# Rebuilds + FTP-deploys the Hugo site (so each newly-live future-dated post resolves at
# flowgroove.app/blog/{slug}/) and mirrors the RSS to GCS (so the Reddit bot, cron 11:00
# UTC, sees that day's post as the newest /blog/ item and crossposts it).
#
# Triggered daily by ~/Library/LaunchAgents/app.flowgroove.devlog-daily.plist (09:00 local
# = 08:00 UTC, before the bot's cron). ponytail: a launch-window job — unload the agent and
# delete this script once the series has fully dripped (after 2026-08-12).
set -u

# launchd gives a minimal PATH; add Homebrew + pyenv shims so make/hugo/lftp/gcloud resolve.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/Users/berloga/.pyenv/shims:$PATH"
export CLOUDSDK_PYTHON="${CLOUDSDK_PYTHON:-$(ls /opt/homebrew/bin/python3.[0-9]* 2>/dev/null | grep -E 'python3\.[0-9]+$' | sort -V | tail -1)}"

cd "$(dirname "$0")/.." || exit 1

echo "=== devlog-daily $(date '+%Y-%m-%d %H:%M:%S %z') ==="
make deploy-hugo          # prod Hugo build + FTP (self-sources .env for FTP creds)
./scripts/mirror-feed.sh  # push site/public/index.xml -> GCS reddit-feed.xml
echo "=== devlog-daily done $(date '+%H:%M:%S') ==="
