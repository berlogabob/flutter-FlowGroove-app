# ARCHIVED

## Status: Deprecated

This directory contains an OLD, unused Python (aiogram) Telegram bot. It is
**NOT deployed and will not be maintained.**

## Canonical implementation

The active production bot is a Node.js Telegraf implementation that runs as a
Firebase Cloud Function:

- Entry point: `functions/index.js` → `exports.telegramWebhook`
- Modules: `functions/src/telegram/` (webhook, handlers, services)

## Warning

**Do not run, deploy, or edit any code in this directory.**

## Why it is retained

Kept solely as a historical reference for the **per-user support-topics logic**
in `bot/services/support_topics.py`, which is being ported to the Node bot.
