/**
 * /start welcome + consent flow (consent_allow / consent_deny callback actions).
 * The Telegram profile photo is intentionally NOT fetched here — it is imported
 * on demand by the `importTelegramAvatar` callable so the bot token is never
 * persisted to Firestore.
 */
const { db, admin, cleanUserId } = require("../config");
const { handleLink } = require("./link");

function register(bot) {
  bot.start(async (ctx) => {
    const userId = ctx.startPayload;

    const welcomeMessage =
      `👋 *Привет! Я FlowGroove бот.*\n\n` +
      `Помогу привязать Telegram к FlowGroove и импортировать имя и фото.\n\n` +
      `Разрешаете импортировать профиль?`;

    const keyboard = {
      reply_markup: {
        inline_keyboard: [
          [
            { text: "✅ Да", callback_data: "consent_allow" },
            { text: "❌ Нет", callback_data: "consent_deny" },
          ],
        ],
      },
      parse_mode: "Markdown",
    };

    await ctx.reply(welcomeMessage, keyboard);

    if (userId) {
      await handleLink(ctx, cleanUserId(userId));
    }
  });

  bot.action("consent_allow", async (ctx) => {
    const userId = ctx.from.id.toString();
    const telegramUsername = ctx.from.username || ctx.from.first_name;

    try {
      // Note: the Telegram profile photo is no longer fetched or stored here.
      // Storing the api.telegram.org/file/bot<TOKEN>/... URL leaked the bot
      // token into Firestore. The photo is now imported on demand, server-side,
      // by the `importTelegramAvatar` callable (which never persists the token).
      const userDoc = await db
        .collection("users")
        .where("telegramId", "==", userId)
        .limit(1)
        .get();

      if (!userDoc.empty) {
        await userDoc.docs[0].ref.update({
          telegramConsent: true,
          telegramConsentDate: admin.firestore.FieldValue.serverTimestamp(),
          telegramUsername: telegramUsername,
        });

        await ctx.answerCbQuery("✅ Принято!");

        const replyMsg =
          `✅ *Готово!*\n\nИмпортируем:\n• Имя: \`${telegramUsername}\`\n\n` +
          `Фото можно импортировать в приложении: Profile → Avatar → Use Telegram Photo.\n\n` +
          `Есть вопросы? Пишите в поддержку!`;

        await ctx.reply(replyMsg, { parse_mode: "Markdown" });
      } else {
        await ctx.answerCbQuery("⚠️ Сначала /link");
        await ctx.reply(
          `⚠️ *Сначала привяжите аккаунт*\n\n` +
            `/link <your_user_id>\n\n` +
            `FlowGroove → Profile → Link Telegram`,
          { parse_mode: "Markdown" },
        );
      }
    } catch (error) {
      console.error(`❌ consent_allow error for user ${userId}:`, error);
      await ctx.answerCbQuery("❌ Error");
      await ctx.reply("❌ Ошибка. Попробуйте позже.");
    }
  });

  bot.action("consent_deny", async (ctx) => {
    await ctx.answerCbQuery("❌ Отказано");
    await ctx.reply(
      `❌ *Понял*\n\n` +
        `Профиль не импортируем.\n\n` +
        `Если передумаете - напишите /start`,
      { parse_mode: "Markdown" },
    );
  });
}

module.exports = { register };
