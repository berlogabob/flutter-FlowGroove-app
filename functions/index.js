/**
 * RepSync Telegram Bot - Simplified & Clean
 *
 * User Commands:
 * /start - Welcome + consent buttons
 * /link <user_id> - Link Telegram account
 * /help - Show help
 * /unlink - Unlink account
 * /status - Check status
 *
 * Admin Commands:
 * /get_id - Get chat ID
 * /reply <user_id> <message> - Reply to user
 * /close_topic - Close topic
 * /reopen_topic - Reopen topic
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { Telegraf } = require("telegraf");
const { defineString } = require("firebase-functions/params");

admin.initializeApp();
const db = admin.firestore();

const TELEGRAM_BOT_TOKEN = defineString("TELEGRAM_BOT_TOKEN");
const SUPPORT_GROUP_ID_PARAM = defineString("SUPPORT_GROUP_ID");
const ADMIN_IDS_PARAM = defineString("ADMIN_IDS");

const bot = new Telegraf(TELEGRAM_BOT_TOKEN.value());

function getSupportGroupId() {
  try {
    return SUPPORT_GROUP_ID_PARAM.value() || null;
  } catch (e) {
    return null;
  }
}

function getAdminIds() {
  try {
    const value = ADMIN_IDS_PARAM.value();
    if (!value) return [];
    return value.split(",").map((id) => parseInt(id.trim()));
  } catch (e) {
    return [];
  }
}

function isAdmin(userId) {
  return getAdminIds().includes(userId);
}

bot.catch((err, ctx) => console.error(`Error: ${ctx.updateType}`, err));

// ============================================
// USER COMMANDS
// ============================================

bot.start(async (ctx) => {
  const userId = ctx.startPayload;

  const welcomeMessage =
    `👋 *Привет! Я RepSync бот.*\n\n` +
    `Помогу привязать Telegram к RepSync и импортировать имя и фото.\n\n` +
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
      await ctx.reply(
        `✅ *Готово!*\n\n` +
          `Импортируем:\n` +
          `• Имя: \`${telegramUsername}\`\n` +
          `• Фото: из Telegram\n\n` +
          `Есть вопросы? Пишите в поддержку!`,
        { parse_mode: "Markdown" },
      );
    } else {
      await ctx.answerCbQuery("⚠️ Сначала /link");
      await ctx.reply(
        `⚠️ *Сначала привяжите аккаунт*\n\n` +
          `/link <your_user_id>\n\n` +
          `RepSync → Profile → Link Telegram`,
        { parse_mode: "Markdown" },
      );
    }
  } catch (error) {
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

bot.command("link", async (ctx) => {
  const args = ctx.message.text.split(" ");
  const userId = args[1];

  if (!userId) {
    await ctx.reply(
      `❌ *Использование:* /link <your_user_id>\n\n` +
        `RepSync → Profile → там ваш ID`,
      { parse_mode: "Markdown" },
    );
    return;
  }

  await handleLink(ctx, cleanUserId(userId));
});

bot.help((ctx) => {
  ctx.reply(
    `📖 *Команды:*\n\n` +
      `/start - Начать\n` +
      `/link <id> - Привязать аккаунт\n` +
      `/unlink - Отвязать\n` +
      `/status - Статус\n` +
      `/help - Эта справка\n\n` +
      `Вопросы? Пишите в поддержку!`,
    { parse_mode: "Markdown" },
  );
});

bot.command("unlink", async (ctx) => {
  const telegramId = ctx.from.id.toString();

  const userSnapshot = await db
    .collection("users")
    .where("telegramId", "==", telegramId)
    .limit(1)
    .get();

  if (userSnapshot.empty) {
    await ctx.reply("❌ Telegram не привязан к RepSync.");
    return;
  }

  await userSnapshot.docs[0].ref.update({
    telegramId: admin.firestore.FieldValue.delete(),
    telegramUsername: admin.firestore.FieldValue.delete(),
    telegramFirstName: admin.firestore.FieldValue.delete(),
    telegramLastName: admin.firestore.FieldValue.delete(),
    telegramLinkedAt: admin.firestore.FieldValue.delete(),
  });

  await ctx.reply("✅ Telegram отвязан от RepSync.");
});

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

// ============================================
// HELPER FUNCTIONS
// ============================================

function cleanUserId(userId) {
  return userId.startsWith("link_") ? userId.substring(5) : userId;
}

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
          `Проверьте ID в RepSync.`,
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
        `Telegram привязан к RepSync.\n\n` +
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

// ============================================
// ADMIN COMMANDS
// ============================================

bot.command("get_id", (ctx) => {
  const chatId = ctx.chat.id;
  const chatType = ctx.chat.type;
  const chatTitle = ctx.chat.title || "Private Chat";

  let message = `📋 *Chat Info*\n\n`;
  message += `*ID:* \`${chatId}\`\n`;
  message += `*Type:* ${chatType}\n`;
  message += `*Title:* ${chatTitle}\n\n`;

  if (chatType === "group" || chatType === "supergroup") {
    message += `*For Config:*\nSUPPORT_GROUP_ID=\`${chatId}\``;
  }

  ctx.reply(message, { parse_mode: "Markdown" });
});

bot.command("reply", async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;

  const args = ctx.message.text.split(" ");

  if (args.length < 3) {
    await ctx.reply(`❌ *Usage:* /reply <user_id> <message>`, {
      parse_mode: "Markdown",
    });
    return;
  }

  const userId = args[1];
  const message = args.slice(2).join(" ");

  try {
    await ctx.telegram.sendMessage(userId, `📬 *Support*\n\n${message}`, {
      parse_mode: "Markdown",
    });
    await ctx.reply(`✅ Отправлено пользователю \`${userId}\``, {
      parse_mode: "Markdown",
    });
  } catch (error) {
    await ctx.reply(`❌ Ошибка: ${error.message}`, { parse_mode: "Markdown" });
  }
});

bot.command("close_topic", async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;
  if (!ctx.message.message_thread_id) {
    await ctx.reply(`❌ Используйте в топике.`);
    return;
  }
  try {
    await ctx.telegram.closeForumTopic(
      getSupportGroupId(),
      ctx.message.message_thread_id,
    );
    await ctx.reply(`✅ Топик закрыт.`);
  } catch (error) {
    await ctx.reply(`❌ Ошибка: ${error.message}`);
  }
});

bot.command("reopen_topic", async (ctx) => {
  if (!isAdmin(ctx.from.id)) return;
  if (!ctx.message.message_thread_id) {
    await ctx.reply(`❌ Используйте в топике.`);
    return;
  }
  try {
    await ctx.telegram.reopenForumTopic(
      getSupportGroupId(),
      ctx.message.message_thread_id,
    );
    await ctx.reply(`✅ Топик открыт.`);
  } catch (error) {
    await ctx.reply(`❌ Ошибка: ${error.message}`);
  }
});

// ============================================
// SUPPORT MESSAGES
// ============================================

bot.on("text", async (ctx) => {
  if (ctx.message.text.startsWith("/")) return;
  if (ctx.chat.type !== "private") return;

  const userId = ctx.from.id.toString();
  const username = ctx.from.username || ctx.from.first_name || "Unknown";
  const groupId = getSupportGroupId();

  if (!groupId) {
    await ctx.reply(`⚠️ Поддержка не настроена. Пишите @repsync_support`);
    return;
  }

  try {
    await ctx.telegram.sendMessage(
      groupId,
      `📩 *Сообщение*\n*От:* ${username} (\`${userId}\`)\n*Текст:* ${ctx.message.text}`,
      { parse_mode: "Markdown" },
    );

    await ctx.reply(`✅ Отправлено в поддержку. Ответим скоро!`);
  } catch (error) {
    await ctx.reply(`❌ Ошибка отправки. Попробуйте позже.`);
  }
});

// ============================================
// EXPORT
// ============================================

exports.telegramWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method === "POST") {
    await bot.handleUpdate(req.body, res);
  } else if (req.method === "GET") {
    res.status(200).send("RepSync Bot 🤖");
  } else {
    res.status(405).send("Method Not Allowed");
  }
});
