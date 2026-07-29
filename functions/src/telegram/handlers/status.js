/** /status — reports whether the caller's Telegram is linked to FlowGroove. */
const { db } = require("../config");
const { t, pickLang } = require("../i18n");

function register(bot) {
  bot.command("status", async (ctx) => {
    const lang = pickLang(ctx);
    const telegramId = ctx.from.id.toString();

    const userSnapshot = await db
      .collection("users")
      .where("telegramId", "==", telegramId)
      .limit(1)
      .get();

    if (userSnapshot.empty) {
      await ctx.reply(t(lang, "status_not_linked"), { parse_mode: "Markdown" });
      return;
    }

    const userDoc = userSnapshot.docs[0];
    const userData = userDoc.data();

    await ctx.reply(
      t(lang, "status_ok", {
        id: userDoc.id,
        name: userData.displayName || "N/A",
        email: userData.email || "N/A",
      }),
      { parse_mode: "Markdown" },
    );
  });
}

module.exports = { register };
