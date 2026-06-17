/** /help — lists the available user commands. */
function register(bot) {
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
}

module.exports = { register };
