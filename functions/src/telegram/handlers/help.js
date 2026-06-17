/** /help — lists the available user commands. */
const { t, pickLang } = require("../i18n");

function register(bot) {
  bot.help((ctx) => {
    const lang = pickLang(ctx);
    ctx.reply(t(lang, "help_text"), { parse_mode: "Markdown" });
  });
}

module.exports = { register };
