/**
 * Per-user API keys for the MCP endpoint. Keys are shown once and stored only as
 * a SHA-256 hash (`apiKeys/{tokenHash}`); the plaintext is never persisted. The
 * `apiKeys` collection is server-only (firestore.rules denies all client access).
 * Mirrors the server-authoritative callable pattern in src/bands.js / src/account.js.
 */
const crypto = require("crypto");
const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

async function isDemoUser(uid, token) {
  if (token && token.demo === true) return true;
  const doc = await db.collection("users").doc(uid).get();
  return doc.exists && doc.data().accessRole === "demo";
}

function hashToken(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

function requireAuth(request) {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  return request.auth.uid;
}

/** Mints an API key. Input: { scope?: 'read'|'write', label?: string }. */
exports.createApiKey = functions.https.onCall(async (request) => {
  const uid = requireAuth(request);
  if (await isDemoUser(uid, request.auth.token || {})) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Demo accounts cannot create API keys.",
    );
  }
  const data = request.data || {};
  const scope = data.scope === "write" ? "write" : "read";
  const label =
    typeof data.label === "string" ? data.label.trim().slice(0, 60) : "";

  const token = `fg_${crypto.randomBytes(32).toString("base64url")}`;
  const tokenHash = hashToken(token);

  await db.collection("apiKeys").doc(tokenHash).set({
    uid,
    scope,
    label,
    prefix: token.slice(0, 9), // "fg_" + 6 chars — for display, not the secret
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastUsedAt: null,
  });

  // The plaintext token is returned exactly once.
  return { token, id: tokenHash, scope, label };
});

/** Lists the caller's keys (metadata only — never the token). */
exports.listApiKeys = functions.https.onCall(async (request) => {
  const uid = requireAuth(request);
  const snap = await db.collection("apiKeys").where("uid", "==", uid).get();
  const keys = snap.docs.map((d) => {
    const k = d.data();
    return {
      id: d.id,
      scope: k.scope,
      label: k.label || "",
      prefix: k.prefix || "fg_…",
      createdAt: k.createdAt ? k.createdAt.toMillis() : null,
      lastUsedAt: k.lastUsedAt ? k.lastUsedAt.toMillis() : null,
    };
  });
  return { keys };
});

/** Revokes one of the caller's keys. Input: { id }. */
exports.revokeApiKey = functions.https.onCall(async (request) => {
  const uid = requireAuth(request);
  const id = typeof request.data?.id === "string" ? request.data.id : "";
  if (!id) {
    throw new functions.https.HttpsError("invalid-argument", "id is required.");
  }
  const ref = db.collection("apiKeys").doc(id);
  const doc = await ref.get();
  if (doc.exists && doc.data().uid === uid) {
    await ref.delete();
  }
  return { ok: true };
});

exports._hashToken = hashToken; // for tests
