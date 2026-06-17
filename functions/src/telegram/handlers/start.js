/**
 * /start welcome + consent flow (consent_allow / consent_deny callback actions).
 * The Telegram profile photo is intentionally NOT fetched here — it is imported
 * on demand by the `importTelegramAvatar` callable so the bot token is never
 * persisted to Firestore.
 */
const { db, admin, cleanUserId } = require("../config");
const { t, pickLang } = require("../i18n");
const { handleLink } = require("./link");

function register(bot) {
  bot.start(async (ctx) => {
    const lang = pickLang(ctx);
    const userId = ctx.startPayload;

    const keyboard = {
      reply_markup: {
        inline_keyboard: [
          [
            { text: t(lang, "btn_yes"), callback_data: "consent_allow" },
            { text: t(lang, "btn_no"), callback_data: "consent_deny" },
          ],
        ],
      },
      parse_mode: "Markdown",
    };

    await ctx.reply(t(lang, "start_welcome"), keyboard);

    if (userId) {
      await handleLink(ctx, cleanUserId(userId));
    }
  });

  bot.action("consent_allow", async (ctx) => {
    const lang = pickLang(ctx);
    const userId = ctx.from.id.toString();
    const telegramUsername = ctx.from.username || ctx.from.first_name;

    try {
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

        await ctx.answerCbQuery(t(lang, "consent_cb_accepted"));
        await ctx.reply(t(lang, "consent_done", { username: telegramUsername }), {
          parse_mode: "Markdown",
        });
      } else {
        await ctx.answerCbQuery(t(lang, "consent_cb_need_link"));
        await ctx.reply(t(lang, "consent_need_link"), { parse_mode: "Markdown" });
      }
    } catch (error) {
      console.error(`❌ consent_allow error for user ${userId}:`, error);
      await ctx.answerCbQuery(t(lang, "consent_cb_error"));
      await ctx.reply(t(lang, "consent_error"));
    }
  });

  bot.action("consent_deny", async (ctx) => {
    const lang = pickLang(ctx);
    await ctx.answerCbQuery(t(lang, "consent_denied_cb"));
    await ctx.reply(t(lang, "consent_denied"), { parse_mode: "Markdown" });
  });
}

module.exports = { register };
