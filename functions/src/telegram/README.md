# FlowGroove Telegram Bot

This is a Telegraf-based bot served by the `telegramWebhook` Firebase Cloud
Function; source code is located in `functions/src/telegram/`.

## Environment Parameters

Set these via Firebase Functions parameters or `.env`:

- `TELEGRAM_BOT_TOKEN` (Required): Bot token from @BotFather.
- `SUPPORT_GROUP_ID` (Optional): Group chat ID for support messages.
- `ADMIN_IDS` (Optional): Comma-separated Telegram user IDs allowed to run admin commands.
- `TELEGRAM_WEBHOOK_SECRET` (Recommended): Secret token to authenticate incoming webhook calls.

## Webhook Security

When `TELEGRAM_WEBHOOK_SECRET` is set, the function rejects any POST request
where the `X-Telegram-Bot-Api-Secret-Token` header does not match. When it is
**not** set, the check is skipped (no-op) so existing deployments keep working.

**IMPORTANT — deployment order** (to avoid locking out a live bot):

1. Deploy the Cloud Function with the secret parameter set.
2. Register the webhook WITH the same secret:

```bash
curl "https://api.telegram.org/bot<TOKEN>/setWebhook?url=<FUNCTION_URL>&secret_token=<SECRET>"
```

If you reverse the order (register without the secret, then deploy with it set),
Telegram will not send the header and every update will be rejected with 401.

## Commands

- **User:** `/start`, `/link <id>`, `/unlink`, `/status`, `/help`
- **Admin** (requires the caller's id in `ADMIN_IDS`): `/get_id`, `/reply`, `/close_topic`, `/reopen_topic`

> [!IMPORTANT]
> The old Python bot in `telegram_bot/` is **ARCHIVED**; this Node.js function
> is the canonical implementation.
