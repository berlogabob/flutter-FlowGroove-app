/**
 * Account linking handlers: /link and /unlink, plus the shared handleLink
 * helper (also used by the /start deep-link flow).
 */
const { db, admin, cleanUserId } = require("../config");
const { t, pickLang } = require("../i18n");

/** Links the caller's Telegram account to a FlowGroove user document. */
async function handleLink(ctx, userId) {
  const lang = pickLang(ctx);
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
      await ctx.reply(t(lang, "link_already"), { parse_mode: "Markdown" });
      return;
    }

    const userDoc = await db.collection("users").doc(userId).get();

    if (!userDoc.exists) {
      await ctx.reply(t(lang, "link_not_found", { userId }), {
        parse_mode: "Markdown",
      });
      return;
    }

    await userDoc.ref.update({
      telegramId: telegramId,
      telegramUsername: telegramUsername,
      telegramFirstName: telegramFirstName,
      telegramLastName: telegramLastName,
      telegramLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await ctx.reply(t(lang, "link_done"), { parse_mode: "Markdown" });

    console.log(`✅ User ${userId} linked to Telegram ${telegramId}`);
  } catch (error) {
    await ctx.reply(t(lang, "link_error"), { parse_mode: "Markdown" });
  }
}

function register(bot) {
  bot.command("link", async (ctx) => {
    const lang = pickLang(ctx);
    const args = ctx.message.text.split(" ");
    const userId = args[1];

    if (!userId) {
      await ctx.reply(t(lang, "link_usage"), { parse_mode: "Markdown" });
      return;
    }

    await handleLink(ctx, cleanUserId(userId));
  });

  bot.command("unlink", async (ctx) => {
    const lang = pickLang(ctx);
    const telegramId = ctx.from.id.toString();

    const userSnapshot = await db
      .collection("users")
      .where("telegramId", "==", telegramId)
      .limit(1)
      .get();

    if (userSnapshot.empty) {
      await ctx.reply(t(lang, "unlink_not_linked"));
      return;
    }

    await userSnapshot.docs[0].ref.update({
      telegramId: admin.firestore.FieldValue.delete(),
      telegramUsername: admin.firestore.FieldValue.delete(),
      telegramFirstName: admin.firestore.FieldValue.delete(),
      telegramLastName: admin.firestore.FieldValue.delete(),
      telegramLinkedAt: admin.firestore.FieldValue.delete(),
    });

    await ctx.reply(t(lang, "unlink_done"));
  });
}

module.exports = { register, handleLink };
