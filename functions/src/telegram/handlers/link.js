/**
 * Account linking handlers: /link and /unlink, plus the shared handleLink
 * helper (also used by the /start deep-link flow).
 */
const { db, admin, cleanUserId } = require("../config");

/** Links the caller's Telegram account to a FlowGroove user document. */
async function handleLink(ctx, userId) {
  const telegramId = ctx.from.id.toString();
  const telegramUsername = ctx.from.username;
  const telegramFirstName = ctx.from.first_name;
  const telegramLastName = ctx.from.last_name;

  try {
    const existingLink = await db
      .collection("users")
      .where("telegramId", "==", telegramId)
      .limit(1)
      .get();

    if (!existingLink.empty) {
      await ctx.reply(
        `⚠️ *Уже привязан*\n\n` +
          `Telegram уже привязан к аккаунту.\n\n` +
          `/unlink чтобы отвязать.`,
        { parse_mode: "Markdown" },
      );
      return;
    }

    const userDoc = await db.collection("users").doc(userId).get();

    if (!userDoc.exists) {
      await ctx.reply(
        `❌ *Не найден*\n\n` +
          `User ID \`${userId}\` не найден.\n\n` +
          `Проверьте ID в FlowGroove.`,
        { parse_mode: "Markdown" },
      );
      return;
    }

    await userDoc.ref.update({
      telegramId: telegramId,
      telegramUsername: telegramUsername,
      telegramFirstName: telegramFirstName,
      telegramLastName: telegramLastName,
      telegramLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await ctx.reply(
      `✅ *Готово!*\n\n` +
        `Telegram привязан к FlowGroove.\n\n` +
        `Теперь можно импортировать имя и фото.`,
      { parse_mode: "Markdown" },
    );

    console.log(`✅ User ${userId} linked to Telegram ${telegramId}`);
  } catch (error) {
    await ctx.reply(
      `❌ *Ошибка*\n\n` + `Не получилось привязать. Попробуйте позже.`,
      { parse_mode: "Markdown" },
    );
  }
}

function register(bot) {
  bot.command("link", async (ctx) => {
    const args = ctx.message.text.split(" ");
    const userId = args[1];

    if (!userId) {
      await ctx.reply(
        `❌ *Использование:* /link <your_user_id>\n\n` +
          `FlowGroove → Profile → там ваш ID`,
        { parse_mode: "Markdown" },
      );
      return;
    }

    await handleLink(ctx, cleanUserId(userId));
  });

  bot.command("unlink", async (ctx) => {
    const telegramId = ctx.from.id.toString();

    const userSnapshot = await db
      .collection("users")
      .where("telegramId", "==", telegramId)
      .limit(1)
      .get();

    if (userSnapshot.empty) {
      await ctx.reply("❌ Telegram не привязан к FlowGroove.");
      return;
    }

    await userSnapshot.docs[0].ref.update({
      telegramId: admin.firestore.FieldValue.delete(),
      telegramUsername: admin.firestore.FieldValue.delete(),
      telegramFirstName: admin.firestore.FieldValue.delete(),
      telegramLastName: admin.firestore.FieldValue.delete(),
      telegramLinkedAt: admin.firestore.FieldValue.delete(),
    });

    await ctx.reply("✅ Telegram отвязан от FlowGroove.");
  });
}

module.exports = { register, handleLink };
