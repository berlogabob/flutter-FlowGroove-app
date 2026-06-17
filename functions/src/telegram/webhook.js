/**
 * HTTPS entry point for the Telegram bot webhook. Telegram POSTs updates here;
 * GET returns a health-check string.
 *
 * Security: when TELEGRAM_WEBHOOK_SECRET is configured, every POST must carry a
 * matching `X-Telegram-Bot-Api-Secret-Token` header (Telegram sends this when
 * the webhook is registered with `secret_token`). The check is a NO-OP when the
 * secret is not configured, so enabling it cannot lock out the live bot before
 * the webhook is re-registered with the secret.
 */
const functions = require("firebase-functions");
const { defineString } = require("firebase-functions/params");

const TELEGRAM_WEBHOOK_SECRET = defineString("TELEGRAM_WEBHOOK_SECRET");

function getConfiguredSecret() {
  try {
    return TELEGRAM_WEBHOOK_SECRET.value() || null;
  } catch (e) {
    return null;
  }
}

// Lazily required so tests (and module load / deploy-time analysis) don't
// instantiate the real Telegraf bot, which needs TELEGRAM_BOT_TOKEN.
function defaultBot() {
  return require("./bot").bot;
}

/**
 * Builds the webhook onRequest handler. Dependencies are injectable for testing;
 * production uses the configured secret and the real bot.
 */
function makeTelegramWebhook({ getBot, getSecret } = {}) {
  return functions.https.onRequest(async (req, res) => {
    if (req.method === "GET") {
      res.status(200).send("FlowGroove Bot 🤖");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const secret = (getSecret || getConfiguredSecret)();
    if (secret) {
      const provided = req.get("X-Telegram-Bot-Api-Secret-Token");
      if (provided !== secret) {
        res.status(401).send("Unauthorized");
        return;
      }
    }

    const bot = (getBot || defaultBot)();
    await bot.handleUpdate(req.body, res);
  });
}

exports.makeTelegramWebhook = makeTelegramWebhook;
exports.telegramWebhook = makeTelegramWebhook();
