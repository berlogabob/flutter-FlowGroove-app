/**
 * Tiny i18n helper for the Telegram bot.
 *
 * Strings live in the `ru` (default) and `en` tables. `t(lang, key, vars)`
 * interpolates {placeholders} and falls back to Russian when a key or language
 * is missing. `pickLang(ctx)` chooses the language from the Telegram client's
 * `language_code` (English clients get English; everything else gets Russian).
 */
const DEFAULT_LANG = "ru";

const STRINGS = {
  ru: {
    start_welcome:
      "👋 *Привет! Я FlowGroove бот.*\n\nПомогу привязать Telegram к FlowGroove и импортировать имя и фото.\n\nРазрешаете импортировать профиль?",
    btn_yes: "✅ Да",
    btn_no: "❌ Нет",
    consent_done:
      "✅ *Готово!*\n\nИмпортируем:\n• Имя: `{username}`\n\nФото можно импортировать в приложении: Profile → Avatar → Use Telegram Photo.\n\nЕсть вопросы? Пишите в поддержку!",
    consent_need_link:
      "⚠️ *Сначала привяжите аккаунт*\n\n/link <your_user_id>\n\nFlowGroove → Profile → Link Telegram",
    consent_cb_accepted: "✅ Принято!",
    consent_cb_need_link: "⚠️ Сначала /link",
    consent_error: "❌ Ошибка. Попробуйте позже.",
    consent_cb_error: "❌ Error",
    consent_denied_cb: "❌ Отказано",
    consent_denied:
      "❌ *Понял*\n\nПрофиль не импортируем.\n\nЕсли передумаете - напишите /start",
    link_usage:
      "❌ *Использование:* /link <your_user_id>\n\nFlowGroove → Profile → там ваш ID",
    link_already:
      "⚠️ *Уже привязан*\n\nTelegram уже привязан к аккаунту.\n\n/unlink чтобы отвязать.",
    link_not_found:
      "❌ *Не найден*\n\nUser ID `{userId}` не найден.\n\nПроверьте ID в FlowGroove.",
    link_done:
      "✅ *Готово!*\n\nTelegram привязан к FlowGroove.\n\nТеперь можно импортировать имя и фото.",
    link_error:
      "❌ *Ошибка*\n\nНе получилось привязать. Попробуйте позже.",
    unlink_not_linked: "❌ Telegram не привязан к FlowGroove.",
    unlink_done: "✅ Telegram отвязан от FlowGroove.",
    help_text:
      "📖 *Команды:*\n\n/start - Начать\n/link <id> - Привязать аккаунт\n/unlink - Отвязать\n/status - Статус\n/help - Эта справка\n\nВопросы? Пишите в поддержку!",
    status_not_linked: "❌ *Не привязан*\n\n/link <your_user_id>",
    status_ok:
      "✅ *Статус*\n\nID: `{id}`\nИмя: {name}\nEmail: {email}\nTelegram: привязан",
    support_not_configured:
      "⚠️ Поддержка не настроена. Пишите @flowgroove_support",
    support_sent: "✅ Отправлено в поддержку. Ответим скоро!",
    support_error: "❌ Ошибка отправки. Попробуйте позже.",
    cmd_start: "Начать",
    cmd_link: "Привязать аккаунт",
    cmd_unlink: "Отвязать",
    cmd_status: "Статус",
    cmd_help: "Справка",
  },
  en: {
    start_welcome:
      "👋 *Hi! I'm the FlowGroove bot.*\n\nI'll help link Telegram to FlowGroove and import your name and photo.\n\nAllow importing your profile?",
    btn_yes: "✅ Yes",
    btn_no: "❌ No",
    consent_done:
      "✅ *Done!*\n\nImporting:\n• Name: `{username}`\n\nYou can import a photo in the app: Profile → Avatar → Use Telegram Photo.\n\nQuestions? Message support!",
    consent_need_link:
      "⚠️ *Link your account first*\n\n/link <your_user_id>\n\nFlowGroove → Profile → Link Telegram",
    consent_cb_accepted: "✅ Accepted!",
    consent_cb_need_link: "⚠️ /link first",
    consent_error: "❌ Error. Please try again later.",
    consent_cb_error: "❌ Error",
    consent_denied_cb: "❌ Declined",
    consent_denied:
      "❌ *Got it*\n\nWe won't import your profile.\n\nIf you change your mind - send /start",
    link_usage:
      "❌ *Usage:* /link <your_user_id>\n\nFlowGroove → Profile → your ID is there",
    link_already:
      "⚠️ *Already linked*\n\nTelegram is already linked to an account.\n\n/unlink to unlink.",
    link_not_found:
      "❌ *Not found*\n\nUser ID `{userId}` not found.\n\nCheck your ID in FlowGroove.",
    link_done:
      "✅ *Done!*\n\nTelegram linked to FlowGroove.\n\nYou can now import your name and photo.",
    link_error: "❌ *Error*\n\nCouldn't link. Please try again later.",
    unlink_not_linked: "❌ Telegram is not linked to FlowGroove.",
    unlink_done: "✅ Telegram unlinked from FlowGroove.",
    help_text:
      "📖 *Commands:*\n\n/start - Start\n/link <id> - Link account\n/unlink - Unlink\n/status - Status\n/help - This help\n\nQuestions? Message support!",
    status_not_linked: "❌ *Not linked*\n\n/link <your_user_id>",
    status_ok:
      "✅ *Status*\n\nID: `{id}`\nName: {name}\nEmail: {email}\nTelegram: linked",
    support_not_configured:
      "⚠️ Support is not configured. Message @flowgroove_support",
    support_sent: "✅ Sent to support. We'll reply soon!",
    support_error: "❌ Failed to send. Please try again later.",
    cmd_start: "Start",
    cmd_link: "Link account",
    cmd_unlink: "Unlink",
    cmd_status: "Status",
    cmd_help: "Help",
  },
};

function pickLang(ctx) {
  const code = ctx && ctx.from && ctx.from.language_code;
  return code && code.startsWith("en") ? "en" : "ru";
}

function t(lang, key, vars = {}) {
  const table = STRINGS[lang] || STRINGS[DEFAULT_LANG];
  let str = table[key] != null ? table[key] : STRINGS[DEFAULT_LANG][key];
  if (str == null) return key;
  for (const [k, v] of Object.entries(vars)) {
    str = str.split(`{${k}}`).join(String(v));
  }
  return str;
}

module.exports = { t, pickLang, STRINGS, DEFAULT_LANG };
