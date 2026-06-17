# Telegram Bot Improvements — Plan

## Context

FlowGroove's Telegram bot is deployed as a **Telegraf** Cloud Function
(`functions/index.js`, exported as `telegramWebhook`). It handles account
linking, status, a consent flow, simple admin commands, and forwards user DMs to
a single support group as flat messages. Problems we are solving:

1. **Duplication / drift.** A second, *undeployed* Python bot
   (`telegram_bot/`, aiogram, "Support Group + Topics") duplicates much of the
   logic and confuses ownership.
2. **Monolith.** All bot logic plus every other Cloud Function export lives in
   one ~430-line `functions/index.js` with hardcoded Russian strings.
3. **Security gap.** `telegramWebhook` (`functions/index.js:409`) accepts *any*
   POST — there is no `X-Telegram-Bot-Api-Secret-Token` verification, so the
   webhook is spoofable.
4. **Weaker support UX.** The Node bot forwards all DMs into one group chat
   (`bot.on("text")`, `functions/index.js:379`) instead of per-user forum
   topics (which the Python bot already implements).
5. **Missing UX niceties & features.** No `/help`, no command menu, no
   notifications, no setlist/song sharing.

**Decision (confirmed):** stay on **Node/Telegraf on Cloud Functions** (no new
runtime/infra), modularize it, and port the good ideas from the Python bot.
Reminders/notifications are a Firebase-scheduled/triggered-function concern, not
a bot-framework one.

## Execution methodology — local model does the bulk, Claude controls

Per request, offload as much generation as possible to the **local Ollama model
`gemma4:12b-it-qat`** (confirmed installed at `/usr/local/bin/ollama`), using
**draft-and-review**: gemma drafts, Claude reviews/integrates every change.

- **Invoke gemma cleanly via the HTTP API** (not the noisy CLI):
  ```bash
  curl -s http://localhost:11434/api/generate -d '{
    "model": "gemma4:12b-it-qat",
    "prompt": "<precise unit spec>",
    "stream": false
  }' | jq -r '.response'
  ```
  (~30s per moderate prompt; strip any leading "Thinking..."/markdown fences.)
- **gemma drafts:** i18n string tables (RU + EN), handler boilerplate, `/help`
  text, JSDoc, README/CHANGELOG, mocha test scaffolds.
- **Claude controls (never delegated):** the module split, webhook-secret
  verification logic, topic-routing integration, scheduled/triggered function
  wiring, and **review of every gemma draft** before it lands. gemma output is
  treated as a first draft, never committed unread.
- **Per-unit loop:** Claude writes a tight spec → gemma drafts → Claude
  reviews/edits → test → commit.

## Target file structure

Extract the bot out of `functions/index.js` into a `functions/src/telegram/`
module (mirrors the existing `functions/src/bands.js` / `src/avatars.js`
convention):

```
functions/src/telegram/
  webhook.js        # onRequest: verify secret header, then bot.handleUpdate
  bot.js            # builds the Telegraf instance, registers all handlers
  config.js         # defineString params + getSupportGroupId/getAdminIds/isAdmin
  i18n.js           # t(key, lang, vars); ru + en string tables
  handlers/
    start.js        # /start + consent_allow/deny
    link.js         # /link, handleLink, /unlink
    status.js       # /status
    help.js         # /help
    admin.js        # /get_id, /reply, /close_topic, /reopen_topic
    support.js      # bot.on("text") -> route DM into the user's topic
  services/
    topics.js       # createTopicForUser / getUserTopic / routeToTopic (Firestore)
    notifications.js# sendToUser(telegramId, text): lookup chat + sendMessage
  reminders.js      # (Phase 4) scheduled/triggered notification functions
  share.js          # (Phase 4) callable: share setlist/song to Telegram
```

`functions/index.js` shrinks to wiring only:
`exports.telegramWebhook = require('./src/telegram/webhook').telegramWebhook;`
plus the existing canonical/bands/avatars exports (unchanged).

**Reuse, don't reinvent:** existing `defineString` params (`TELEGRAM_BOT_TOKEN`,
`SUPPORT_GROUP_ID`, `ADMIN_IDS`), `db = admin.firestore()`, the `bot.catch`
handler, and the mocha + `firebase-functions-test` + emulator harness in
`functions/test/` (see `callable-import-telegram-avatar.test.js`). Port topic
logic from `telegram_bot/bot/services/support_topics.py`
(`create_forum_topic` → store `support_topics/{telegramId}`).

## Phased work

### Phase 1 — Consolidate + modularize (no behavior change)
- Create `functions/src/telegram/` modules above; move each existing handler
  verbatim first, then refactor. `bot.js` registers handlers; `config.js` holds
  the params/helpers currently at `functions/index.js:26-52`.
- Slim `functions/index.js` to exports only.
- Archive the Python bot: add `telegram_bot/ARCHIVED.md` explaining Node is
  canonical; keep the dir as reference (do not delete in same PR).
- gemma: draft module headers/JSDoc and the `ARCHIVED.md`. Claude: do the actual
  code moves and verify `node --check` + existing callable tests still pass.

### Phase 2 — Security hardening
- Add `TELEGRAM_WEBHOOK_SECRET` (`defineString`). In `webhook.js`, reject
  requests whose `X-Telegram-Bot-Api-Secret-Token` header ≠ the secret with
  `401` before `bot.handleUpdate`.
- Document the one-time `setWebhook(url, { secret_token })` step (a small admin
  script or `setMyCommands`/setup function) in the bot README.
- Audit admin commands: ensure every privileged command calls `isAdmin`
  (`/get_id` currently does not); validate `/link`/`/reply` arguments.
- gemma: draft the README setup section + a `functions/test/telegram-webhook.test.js`
  scaffold. Claude: write/verify the header-check logic and the test assertions
  (valid secret passes, missing/wrong secret → 401).

### Phase 3 — UX + i18n + per-user topics
- `i18n.js`: move all hardcoded RU strings into `t(key, lang, vars)` with `ru`
  and `en` tables; default `ru`, optionally pick lang from
  `ctx.from.language_code`.
- `/help` handler + `bot.telegram.setMyCommands([...])` so the command menu
  shows in Telegram.
- Port per-user **forum topics**: on first DM (or `/start`), `topics.js`
  creates a forum topic via `ctx.telegram.createForumTopic(groupId, name,
  {icon_color})`, stores `support_topics/{telegramId} -> {threadId}`, and
  `support.js` routes subsequent DMs into that thread (`sendMessage(groupId,
  text, {message_thread_id})`); admin `/reply` and group replies route back to
  the user. Falls back to flat forwarding if `SUPPORT_GROUP_ID` lacks forum mode.
- gemma: draft the full `i18n.js` ru/en tables and `/help` text (bulk text work
  it is good at). Claude: review translations, wire topic routing, integrate.

### Phase 4 — New features (depends on Phases 1–3)
- **Notifications** (`notifications.js` + `reminders.js`): start with an
  **event-driven** notification that reuses existing data — a Firestore trigger
  on band setlist create/update that messages linked members
  (members with `telegramId`) via `sendToUser`. *Verify first* whether a
  rehearsal/events model exists; **scheduled rehearsal reminders**
  (`onSchedule` + Cloud Scheduler) are only added if such a data source exists,
  otherwise deferred. Reuse the avatar callable pattern for any callable.
- **Share to Telegram** (`share.js`): a callable `shareToTelegram({type:
  'setlist'|'song', id})` that formats the item and sends it to the caller's
  linked Telegram chat (or returns a `t.me` deep link for sharing into a group).
- gemma: draft message formatting/templates and tests scaffolds. Claude: wire
  triggers/callables, Firestore queries, and member-lookup logic.

## Verification

- **Local:** `cd functions && node --check index.js src/telegram/*.js`;
  `npm run test:callables` (existing + new telegram tests) against the Firestore
  emulator (needs JDK ≥21 on PATH).
- **Security:** unit test that `telegramWebhook` returns 401 without the correct
  secret header and 200/handles update with it.
- **Manual (test bot):** point a **test** bot's webhook (with `secret_token`) at
  a deployed/emulated function; verify `/start`, `/help`, `/link`, `/status`,
  command menu; in a forum-enabled **test** group verify a DM creates a per-user
  topic and admin `/reply` routes back; trigger a setlist change and confirm a
  linked member receives a DM.
- **Deploy:** `firebase deploy --only functions` (and re-run `setWebhook` with
  the secret once). Nothing in `storage.rules`/Flutter changes here.

## Notes / open dependencies
- Confirm a rehearsal/events data model before building scheduled reminders;
  otherwise Phase 4 ships only event-driven notifications + sharing.
- Keep each phase a separate PR/commit series; Phase 1 must be behavior-neutral
  (pure refactor) and verified before later phases build on it.
- Mirror of the approved plan at `~/.claude/plans/eager-churning-breeze.md`.
