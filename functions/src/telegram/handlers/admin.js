/**
 * Admin/support commands: /get_id, /reply, /close_topic, /reopen_topic.
 * All privileged commands (except the informational /get_id) require the caller
 * to be in ADMIN_IDS.
 */
const { isAdmin, getSupportGroupId } = require("../config");

function register(bot) {
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
}

module.exports = { register };
