/**
 * Server-authoritative band avatar management.
 *
 * Band-admin status is verified with the Admin SDK and the upload is performed
 * server-side, so this does NOT rely on cross-service Storage rules (which were
 * unreliable). Mirrors the server-authoritative pattern used for band
 * membership (src/bands.js) and the Telegram avatar import (src/avatars.js).
 *
 * The client sends the (already resized) image as base64; avatars are small.
 */
const crypto = require("crypto");
const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const MAX_BYTES = 5 * 1024 * 1024;

async function assertBandAdmin(bandId, uid) {
  const doc = await db.collection("bands").doc(bandId).get();
  if (!doc.exists) {
    throw new functions.https.HttpsError("not-found", "Band not found.");
  }
  const adminUids = (doc.data() || {}).adminUids || [];
  if (!adminUids.includes(uid)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only band admins can change the band avatar.",
    );
  }
}

/** Builds the setBandAvatar callable; `getBucket` is injectable for testing. */
function makeSetBandAvatar({ getBucket } = {}) {
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
    const bandId =
      data && typeof data.bandId === "string" ? data.bandId.trim() : "";
    const imageBase64 =
      data && typeof data.imageBase64 === "string" ? data.imageBase64 : "";
    if (!bandId || !imageBase64) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "bandId and imageBase64 are required.",
      );
    }

    await assertBandAdmin(bandId, uid);

    const buffer = Buffer.from(imageBase64, "base64");
    if (buffer.length === 0 || buffer.length > MAX_BYTES) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Image is empty or too large.",
      );
    }

    const bucket = (getBucket || (() => admin.storage().bucket()))();
    const filePath = `band_avatars/${bandId}`;
    const token = crypto.randomUUID();
    await bucket.file(filePath).save(buffer, {
      contentType: "image/jpeg",
      metadata: { metadata: { firebaseStorageDownloadTokens: token } },
    });

    const photoURL =
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
      `${encodeURIComponent(filePath)}?alt=media&token=${token}`;

    await db.collection("bands").doc(bandId).set(
      {
        photoURL,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { photoURL };
  });
}

/** Builds the removeBandAvatar callable; `getBucket` is injectable for testing. */
function makeRemoveBandAvatar({ getBucket } = {}) {
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
    const bandId =
      data && typeof data.bandId === "string" ? data.bandId.trim() : "";
    if (!bandId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "bandId is required.",
      );
    }

    await assertBandAdmin(bandId, uid);

    const bucket = (getBucket || (() => admin.storage().bucket()))();
    try {
      await bucket.file(`band_avatars/${bandId}`).delete();
    } catch (e) {
      // Ignore "object not found" — nothing to remove.
    }

    await db.collection("bands").doc(bandId).set(
      {
        photoURL: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { ok: true };
  });
}

exports.makeSetBandAvatar = makeSetBandAvatar;
exports.makeRemoveBandAvatar = makeRemoveBandAvatar;
exports.setBandAvatar = makeSetBandAvatar();
exports.removeBandAvatar = makeRemoveBandAvatar();
