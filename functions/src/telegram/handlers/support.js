/**
 * Support messaging, bidirectional:
 *
 *  1. User DM -> support group. The message is routed into the user's own forum
 *     topic (created on demand). If the group is not a forum, it falls back to
 *     flat forwarding (the previous behavior).
 *  2. Support reply in a topic -> user. A (non-command) message posted in a
 *     tracked topic thread is delivered back to the corresponding user.
 *
 * Registered last so command handlers always take precedence.
 */
const { getSupportGroupId } = require("../config");
const { t, pickLang } = require("../i18n");
const { getOrCreateUserTopic, getUserByTopic } = require("../services/topics");

function register(bot) {
  bot.on("text", async (ctx) => {
    const text = ctx.message.text;
    if (text.startsWith("/")) return;

    const groupId = getSupportGroupId();

    // Direction 1: user DM -> support group (into the user's topic if possible).
    if (ctx.chat.type === "private") {
      const lang = pickLang(ctx);
      const userId = ctx.from.id.toString();
      const username = ctx.from.username || ctx.from.first_name || "Unknown";

      if (!groupId) {
        await ctx.reply(t(lang, "support_not_configured"));
        return;
      }

      try {
        const threadId = await getOrCreateUserTopic(
          ctx.telegram,
          groupId,
          userId,
          username,
        );

        const options = { parse_mode: "Markdown" };
        let message;
        if (threadId) {
          options.message_thread_id = threadId;
          message = `📩 *${username}* (\`${userId}\`):\n${text}`;
        } else {
          // Fallback: flat forwarding when the group has no forum topics.
          message = `📩 *Сообщение*\n*От:* ${username} (\`${userId}\`)\n*Текст:* ${text}`;
        }

        await ctx.telegram.sendMessage(groupId, message, options);
        await ctx.reply(t(lang, "support_sent"));
      } catch (error) {
        await ctx.reply(t(lang, "support_error"));
      }
      return;
    }

    // Direction 2: support reply inside a topic thread -> back to the user.
    if (
      groupId &&
      String(ctx.chat.id) === String(groupId) &&
      ctx.message.message_thread_id
    ) {
      try {
        const targetUserId = await getUserByTopic(ctx.message.message_thread_id);
        if (!targetUserId) return; // not a tracked user topic
        await ctx.telegram.sendMessage(targetUserId, `📬 *Support*\n\n${text}`, {
          parse_mode: "Markdown",
        });
      } catch (error) {
        console.error("topic reply routing failed:", error.message);
      }
    }
  });
}

module.exports = { register };
