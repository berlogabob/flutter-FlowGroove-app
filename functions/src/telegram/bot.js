/**
 * Builds the Telegraf bot instance and registers all handlers.
 *
 * Handler registration order is significant: command/action handlers are
 * registered before the catch-all text handler in `support.js`, so commands
 * always take precedence over support-message forwarding.
 */
const { Telegraf } = require("telegraf");
const { TELEGRAM_BOT_TOKEN } = require("./config");
const { t } = require("./i18n");

const bot = new Telegraf(TELEGRAM_BOT_TOKEN.value());

bot.catch((err, ctx) => console.error(`Error: ${ctx.updateType}`, err));

require("./handlers/start").register(bot);
require("./handlers/link").register(bot);
require("./handlers/help").register(bot);
require("./handlers/status").register(bot);
require("./handlers/admin").register(bot);
require("./handlers/support").register(bot); // must stay last

// Publish the slash-command menu shown in Telegram clients (best-effort; runs
// once per cold start and is idempotent). Failures are non-fatal.
function commandMenu(lang) {
  return [
    { command: "start", description: t(lang, "cmd_start") },
    { command: "link", description: t(lang, "cmd_link") },
    { command: "unlink", description: t(lang, "cmd_unlink") },
    { command: "status", description: t(lang, "cmd_status") },
    { command: "help", description: t(lang, "cmd_help") },
  ];
}

bot.telegram
  .setMyCommands(commandMenu("ru"))
  .catch((e) => console.error("setMyCommands(ru) failed:", e.message));
bot.telegram
  .setMyCommands(commandMenu("en"), { language_code: "en" })
  .catch((e) => console.error("setMyCommands(en) failed:", e.message));

module.exports = { bot };
