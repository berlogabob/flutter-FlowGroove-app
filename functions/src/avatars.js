const crypto = require("crypto");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { defineString } = require("firebase-functions/params");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const TELEGRAM_BOT_TOKEN = defineString("TELEGRAM_BOT_TOKEN");

function defaultTelegram() {
  // Required lazily so a cold start that never imports a telegram avatar (e.g.
  // joining a band) doesn't pay to load the telegraf bot framework.
  const { Telegram } = require("telegraf");
  return new Telegram(TELEGRAM_BOT_TOKEN.value());
}

function defaultBucket() {
  return admin.storage().bucket();
}

/**
 * Builds the `importTelegramAvatar` callable. Dependencies are injectable for
 * testing; production uses the real bot token / default bucket.
 *
 * getTelegram/getBucket are invoked lazily at request time so the real ones
 * don't call TELEGRAM_BOT_TOKEN.value() / admin.storage() at module load.
 */
function makeImportTelegramAvatar({ getTelegram, getBucket, fetchImpl } = {}) {
  return functions.https.onCall(async (request) => {
    const data = request.data || {};
    const context = { auth: request.auth };
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

    // Telegram returns each photo as a PhotoSize[] sorted ascending by size;
    // the last element is the highest resolution.
    const sizes = photos.photos[0];
    const fileId = sizes[sizes.length - 1].file_id;
    const fileLink = await telegram.getFileLink(fileId);
    const fetchFn = fetchImpl || fetch;
    const res = await fetchFn(fileLink.toString());
    if (!res.ok) {
      throw new functions.https.HttpsError(
        "internal",
        `Failed to fetch Telegram file: ${res.status}`,
      );
    }
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

/**
 * Builds the `importGoogleAvatar` callable: mirrors the signed-in user's Google
 * account photo into our bucket server-side. Doing the download server-side
 * avoids the browser CORS wall that breaks a client-side fetch on web, and
 * sidesteps dart:io File (unavailable on web) entirely.
 *
 * getAuth/getBucket/fetchImpl are injectable for testing.
 */
function makeImportGoogleAvatar({ getAuth, getBucket, fetchImpl } = {}) {
  return functions.https.onCall(async (request) => {
    const context = { auth: request.auth };
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Request must be authenticated.",
      );
    }
    const uid = context.auth.uid;

    const auth = (getAuth || (() => admin.auth()))();
    const userRecord = await auth.getUser(uid);
    const googleProvider = (userRecord.providerData || []).find(
      (p) => p.providerId === "google.com",
    );
    const googleUrl =
      (googleProvider && googleProvider.photoURL) || userRecord.photoURL;
    if (!googleUrl) {
      throw new functions.https.HttpsError(
        "not-found",
        "No Google profile photo is available to import.",
      );
    }

    const fetchFn = fetchImpl || fetch;
    const res = await fetchFn(googleUrl);
    if (!res.ok) {
      throw new functions.https.HttpsError(
        "internal",
        `Failed to fetch Google photo: ${res.status}`,
      );
    }
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

    await db.collection("users").doc(uid).set({
      photoURL,
      photoSource: "google",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { photoURL };
  });
}

exports.makeImportTelegramAvatar = makeImportTelegramAvatar;
exports.importTelegramAvatar = makeImportTelegramAvatar();
exports.makeImportGoogleAvatar = makeImportGoogleAvatar;
exports.importGoogleAvatar = makeImportGoogleAvatar();
