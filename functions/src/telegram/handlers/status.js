/** /status — reports whether the caller's Telegram is linked to FlowGroove. */
const { db } = require("../config");

function register(bot) {
  bot.command("status", async (ctx) => {
    const telegramId = ctx.from.id.toString();

    const userSnapshot = await db
      .collection("users")
      .where("telegramId", "==", telegramId)
      .limit(1)
      .get();

    if (userSnapshot.empty) {
      await ctx.reply(`❌ *Не привязан*\n\n` + `/link <your_user_id>`, {
        parse_mode: "Markdown",
      });
      return;
    }

    const userDoc = userSnapshot.docs[0];
    const userData = userDoc.data();

    await ctx.reply(
      `✅ *Статус*\n\n` +
        `ID: \`${userDoc.id}\`\n` +
        `Имя: ${userData.displayName || "N/A"}\n` +
        `Email: ${userData.email || "N/A"}\n` +
        `Telegram: привязан`,
      { parse_mode: "Markdown" },
    );
  });
}

module.exports = { register };
