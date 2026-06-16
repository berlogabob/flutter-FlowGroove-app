const crypto = require("crypto");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { defineString } = require("firebase-functions/params");
const { Telegram } = require("telegraf");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const TELEGRAM_BOT_TOKEN = defineString("TELEGRAM_BOT_TOKEN");

function defaultTelegram() {
  return new Telegram(TELEGRAM_BOT_TOKEN.value());
}

function defaultBucket() {
  return admin.storage().bucket();
}

/**
 * Builds the `importTelegramAvatar` callable. Dependencies are injectable for
 * testing; production uses the real bot token / default bucket.
 */
function makeImportTelegramAvatar({ getTelegram, getBucket, fetchImpl } = {}) {
  return functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Request must be authenticated.",
      );
    }
    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();
    const telegramId = snap.exists ? snap.data().telegramId : null;
    if (!telegramId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Telegram is not linked to this account.",
      );
    }

    const telegram = (getTelegram || defaultTelegram)();
    const photos = await telegram.getUserProfilePhotos(Number(telegramId), {
      limit: 1,
    });
    if (!photos || !photos.total_count) {
      throw new functions.https.HttpsError(
        "not-found",
        "No Telegram profile photo found.",
      );
    }

    const fileId = photos.photos[0][0].file_id;
    const fileLink = await telegram.getFileLink(fileId);
    const fetchFn = fetchImpl || fetch;
    const res = await fetchFn(fileLink.toString());
    const buffer = Buffer.from(await res.arrayBuffer());

    const bucket = (getBucket || defaultBucket)();
    const filePath = `profile_pictures/${uid}.jpg`;
    const token = crypto.randomUUID();
    await bucket.file(filePath).save(buffer, {
      contentType: "image/jpeg",
      metadata: { metadata: { firebaseStorageDownloadTokens: token } },
    });

    const photoURL =
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
      `${encodeURIComponent(filePath)}?alt=media&token=${token}`;

    await userRef.set({
      photoURL,
      photoSource: "telegram",
      telegramPhotoURL: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { photoURL };
  });
}

exports.makeImportTelegramAvatar = makeImportTelegramAvatar;
exports.importTelegramAvatar = makeImportTelegramAvatar();
