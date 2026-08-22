# FlowGroove Poster

Pick commits → scaffold a Hugo blog draft → fill prose + social text → publish to
Telegram. You (or the agent) write the prose; the CLI only does git reading, file
scaffolding, and the Telegram API call — with double-post protection.

Reddit crossposting lives in `../reddit-bot` (a Devvit app), not here.

## Setup

```bash
cd poster
uv sync
cp .env.example .env   # fill in Telegram creds (.env is gitignored)
```

## Workflow

```bash
# 1. See recent commits, pick the ones worth a post
uv run poster.py changes --last-days 7

# 2. Scaffold the draft (creates site/content/blog/<date>-<slug>.md + .social.yaml)
uv run poster.py draft --title "Tuner workflow update" --commits abc123,def456

# 3. Write the post body + the telegram text:
#    - edit site/content/blog/<date>-tuner-workflow-update.md   (prose, draft:true)
#    - edit site/content/blog/<date>-tuner-workflow-update.social.yaml
#      (telegram.text — canonical_url is prefilled)

# 4. Publish (dry-run first; re-running after success is refused)
uv run poster.py publish telegram tuner-workflow-update --dry-run
uv run poster.py publish telegram tuner-workflow-update

# 5. Go live (production = flowgroove.app over FTP), then refresh the Reddit feed:
#    flip draft:false in the .md, then —
make -C .. deploy-hugo && ../scripts/mirror-feed.sh
```

`make deploy-hugo` uploads the site over FTP but does **not** mirror the feed, so run
`mirror-feed.sh` after it. (`../scripts/deploy-hugo.sh` is the GitHub-Pages/dev path —
it copies to `docs/` and mirrors the feed itself; it does *not* touch flowgroove.app.)
The old nightly launchd job that chained both is disabled — deploys are manual now.

Reddit is automatic once the feed is refreshed: the `../reddit-bot` Devvit app (live in
r/FlowGroove since 2026-06-29) crossposts on its daily `0 11 UTC` cron, or via its
"Publish latest devlog now" mod menu. **It posts only the newest `/blog/` item per feed
refresh** — if you flip several posts to `draft:false` and deploy at once, only the
latest reaches Reddit; the rest go live on the site but skip it. Deploy one at a time
when you want each on Reddit.

`uv run poster.py selftest` checks the slug + dup-guard logic.

## X / Instagram (manual)

The `.social.yaml` sidecar can also carry `x` and `instagram` blocks. **No automation
reads them** — they're a place to pre-write the copy and paste it by hand:

- `x.text` — keep it ~280 chars; the blog link is clickable on X.
- `instagram.caption` — IG caption links are **not** clickable, so use "link in bio"
  and a hashtag block; `instagram.image` points at a shared asset in
  `site/static/images/` (there are no per-post images).

See `site/content/blog/2026-06-29-getting-ready-for-tinylaunch.social.yaml` for the shape.

## Notes

- The slug arg to `publish` is the title-derived slug (no date prefix).
- **Telegram needs a `.social.yaml` sidecar** (`telegram.text`); web + Reddit don't.
  The 2026-06-25 devlog series posts ship *without* sidecars, so they reach web + Reddit
  but not Telegram — add a sidecar (copy an existing one) before `publish telegram`.
- Reddit crossposting moved to `../reddit-bot` (Devvit) — Reddit killed self-service
  `/prefs/apps` script apps, so PRAW-from-here no longer works.
- Telegram: the bot must be an admin of the target channel with post permission.
- Not built (YAGNI): scheduler, queue/status machine, SQLite, audit log, LLM
  drafting. Add them only when manual `uv run` stops being enough.
