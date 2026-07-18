/**
 * Outbound Telegram notifications (used by triggers/scheduled functions and the
 * share callable). Uses a lazily-created Telegram client so importing this
 * module does not require the bot token until a message is actually sent.
 */
const { db, TELEGRAM_BOT_TOKEN } = require("../config");

let _client;
function telegramClient() {
  // Required lazily so importing this module (pulled in transitively on every
  // cold start via share/reminders) doesn't load the telegraf framework until a
  // message is actually sent.
  if (!_client) {
    const { Telegram } = require("telegraf");
    _client = new Telegram(TELEGRAM_BOT_TOKEN.value());
  }
  return _client;
}

/** Sends a Markdown message to a Telegram chat id (best-effort). */
async function sendToUser(telegramId, text) {
  return telegramClient().sendMessage(telegramId, text, {
    parse_mode: "Markdown",
  });
}

/**
 * Notifies every consented, Telegram-linked member of a band.
 *
 * Reads member uids from the band doc, then each user's telegramId /
 * telegramConsent. Failures for individual members are logged and skipped.
 *
 * @param {object} [opts]
 * @param {string} [opts.exceptUid] - uid to skip (e.g. the actor)
 * @param {function} [opts.send] - injectable send(telegramId, text) for testing
 * @returns {Promise<number>} how many members were notified
 */
async function notifyBandMembers(bandId, text, { exceptUid, send } = {}) {
  const deliver = send || sendToUser;
  const bandDoc = await db.collection("bands").doc(bandId).get();
  if (!bandDoc.exists) return 0;

  const memberUids = bandDoc.data().memberUids || [];
  let notified = 0;

  for (const uid of memberUids) {
    if (uid === exceptUid) continue;
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) continue;
    const user = userDoc.data();
    if (user.telegramId && user.telegramConsent === true) {
      try {
        await deliver(user.telegramId, text);
        notified++;
      } catch (e) {
        console.error(`notifyBandMembers: failed for uid ${uid}:`, e.message);
      }
    }
  }

  return notified;
}

/**
 * Notifies every consented, Telegram-linked user in an explicit uid list
 * (e.g. a rehearsal's invited members, rather than the whole band).
 *
 * @param {string[]} uids
 * @param {object} [opts]
 * @param {string} [opts.exceptUid] - uid to skip (e.g. the actor)
 * @param {function} [opts.send] - injectable send(telegramId, text) for testing
 * @returns {Promise<number>} how many users were notified
 */
async function notifyUids(uids, text, { exceptUid, send } = {}) {
  const deliver = send || sendToUser;
  let notified = 0;

  for (const uid of uids) {
    if (uid === exceptUid) continue;
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) continue;
    const user = userDoc.data();
    if (user.telegramId && user.telegramConsent === true) {
      try {
        await deliver(user.telegramId, text);
        notified++;
      } catch (e) {
        console.error(`notifyUids: failed for uid ${uid}:`, e.message);
      }
    }
  }

  return notified;
}

module.exports = { sendToUser, notifyBandMembers, notifyUids, telegramClient };
