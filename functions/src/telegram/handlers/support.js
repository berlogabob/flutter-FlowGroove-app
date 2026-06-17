/**
 * Support messaging: forwards a user's private (non-command) text message to the
 * configured support group. Registered last so command handlers take precedence.
 */
const { getSupportGroupId } = require("../config");

function register(bot) {
  bot.on("text", async (ctx) => {
    if (ctx.message.text.startsWith("/")) return;
    if (ctx.chat.type !== "private") return;

    const userId = ctx.from.id.toString();
    const username = ctx.from.username || ctx.from.first_name || "Unknown";
    const groupId = getSupportGroupId();

    if (!groupId) {
      await ctx.reply(`⚠️ Поддержка не настроена. Пишите @flowgroove_support`);
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
}

module.exports = { register };
