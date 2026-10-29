/**
 * Proof of account ownership for Telegram linking. The signed-in app user mints
 * a short-lived single-use token; the bot only links a Telegram account to the
 * user that minted the token it receives (never to a bare uid).
 */
const crypto = require("crypto");
const functions = require("firebase-functions");
const { db, admin } = require("./config");

const TTL_MS = 15 * 60 * 1000;
const hash = (token) => crypto.createHash("sha256").update(token).digest("hex");

exports.createTelegramLinkToken = functions.https.onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in first.");
  }
  const userDoc = await db.collection("users").doc(auth.uid).get();
  if ((auth.token && auth.token.demo === true) ||
      (userDoc.exists && userDoc.data().accessRole === "demo")) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Demo users cannot link Telegram.",
    );
  }
  const token = crypto.randomBytes(32).toString("base64url"); // 43 chars, /start-safe
  await db.collection("telegramLinkTokens").doc(hash(token)).set({
    uid: auth.uid,
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + TTL_MS),
  });
  return { token };
});

/** Consumes [token]; returns the owning uid or null if unknown/expired/used. */
exports.consumeTelegramLinkToken = async (token) => {
  if (typeof token !== "string" || !/^[A-Za-z0-9_-]{20,64}$/.test(token)) return null;
  const ref = db.collection("telegramLinkTokens").doc(hash(token));
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    tx.delete(ref);
    const { uid, expiresAt } = snap.data();
    return expiresAt && expiresAt.toMillis() > Date.now() ? uid : null;
  });
};
