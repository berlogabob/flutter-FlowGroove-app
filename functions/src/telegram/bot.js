/**
 * Builds the Telegraf bot instance and registers all handlers.
 *
 * Handler registration order is significant: command/action handlers are
 * registered before the catch-all text handler in `support.js`, so commands
 * always take precedence over support-message forwarding.
 */
const { Telegraf } = require("telegraf");
const { TELEGRAM_BOT_TOKEN } = require("./config");

const bot = new Telegraf(TELEGRAM_BOT_TOKEN.value());

bot.catch((err, ctx) => console.error(`Error: ${ctx.updateType}`, err));

require("./handlers/start").register(bot);
require("./handlers/link").register(bot);
require("./handlers/help").register(bot);
require("./handlers/status").register(bot);
require("./handlers/admin").register(bot);
require("./handlers/support").register(bot); // must stay last

module.exports = { bot };
