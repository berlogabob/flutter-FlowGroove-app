/**
 * Callable: shareToTelegram({ text }) delivers an app-formatted message (a
 * setlist or song summary built client-side) to the CALLER'S OWN linked
 * Telegram chat, from where they can forward it. Sending only to the caller's
 * own chat keeps this safe — it cannot message arbitrary users.
 */
const functions = require("firebase-functions");
const { db } = require("./config");
const { sendToUser } = require("./services/notifications");

const MAX_LEN = 4096; // Telegram message limit

/** Builds the callable; `getSend` is injectable for testing. */
function makeShareToTelegram({ getSend } = {}) {
  return functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Request must be authenticated.",
      );
    }

    const text =
      data && typeof data.text === "string" ? data.text.trim() : "";
    if (!text) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "A non-empty `text` is required.",
      );
    }
    if (text.length > MAX_LEN) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Message is too long.",
      );
    }

    const uid = context.auth.uid;
    const userDoc = await db.collection("users").doc(uid).get();
    const telegramId = userDoc.exists ? userDoc.data().telegramId : null;
    if (!telegramId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Telegram is not linked to this account.",
      );
    }

    const send = getSend ? getSend() : sendToUser;
    await send(telegramId, text);
    return { ok: true };
  });
}

exports.makeShareToTelegram = makeShareToTelegram;
exports.shareToTelegram = makeShareToTelegram();
