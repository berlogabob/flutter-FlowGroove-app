/**
 * Server-authoritative account deletion (Google Play data-deletion requirement).
 *
 * Runs entirely with the Admin SDK, so it deletes the Firebase Auth user
 * directly — no client `requires-recent-login` re-auth dance needed. It detaches
 * the user from every band, deletes all of their personal data
 * (users/{uid} + songs/setlists/bands subcollections), their profile picture,
 * and finally the Auth account. Mirrors the server-authoritative pattern in
 * src/bands.js / src/band_avatar.js.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Duplicated from src/bands.js — a 4-line helper not worth a shared module.
function deriveUidArrays(members) {
  return {
    memberUids: members.map((m) => m.uid),
    adminUids: members.filter((m) => m.role === "admin").map((m) => m.uid),
    editorUids: members.filter((m) => m.role === "editor").map((m) => m.uid),
  };
}

async function isDemoUser(uid, token) {
  if (token && token.demo === true) return true;
  const userDoc = await db.collection("users").doc(uid).get();
  return userDoc.exists && userDoc.data().accessRole === "demo";
}

/**
 * Removes `uid` from every band. Per band, in a transaction:
 *  - drop them from members + the derived uid arrays;
 *  - if the band is left with no members, delete it (its songs/setlists
 *    subcollections are cascaded afterwards with recursiveDelete);
 *  - if the band is left with members but no admin, promote the first remaining
 *    member so the band is never orphaned.
 *    ponytail: promote-first-member is the simplest non-orphan rule; swap for an
 *    explicit owner-succession prompt if bands need a say in who inherits admin.
 */
async function removeFromAllBands(uid) {
  const snap = await db
    .collection("bands")
    .where("memberUids", "array-contains", uid)
    .get();
  const emptied = [];
  for (const doc of snap.docs) {
    const bandRef = doc.ref;
    const wasEmptied = await db.runTransaction(async (tx) => {
      const bandDoc = await tx.get(bandRef);
      if (!bandDoc.exists) return false;
      const band = bandDoc.data() || {};
      const members = (Array.isArray(band.members) ? band.members : []).filter(
        (m) => m && m.uid !== uid,
      );
      if (members.length === 0) {
        tx.delete(bandRef);
        return true;
      }
      if (!members.some((m) => m.role === "admin")) {
        members[0] = { ...members[0], role: "admin" };
      }
      tx.set(bandRef, { members, ...deriveUidArrays(members) }, { merge: true });
      return false;
    });
    if (wasEmptied) emptied.push(bandRef);
  }
  for (const ref of emptied) {
    await db.recursiveDelete(ref);
  }
}

/** Builds the deleteAccount callable; getAuth/getBucket injectable for testing. */
function makeDeleteAccount({ getAuth, getBucket } = {}) {
  return functions.https.onCall(async (request) => {
    const context = { auth: request.auth };
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Request must be authenticated.",
      );
    }
    const uid = context.auth.uid;
    if (await isDemoUser(uid, context.auth.token || {})) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Demo accounts cannot be deleted.",
      );
    }

    // 1. Detach from shared band data first.
    await removeFromAllBands(uid);

    // 2. Delete all personal data (user doc + songs/setlists/bands subcollections).
    await db.recursiveDelete(db.collection("users").doc(uid));

    // 3. Best-effort delete the profile picture.
    const bucket = (getBucket || (() => admin.storage().bucket()))();
    try {
      await bucket.file(`profile_pictures/${uid}.jpg`).delete();
    } catch (e) {
      // Ignore "object not found" — nothing to remove.
    }

    // 4. Delete the Auth account last, so a failure above leaves the user able
    //    to retry. Admin SDK delete bypasses the client recent-login rule.
    const auth = (getAuth || (() => admin.auth()))();
    await auth.deleteUser(uid);

    return { ok: true };
  });
}

exports.makeDeleteAccount = makeDeleteAccount;
exports.deleteAccount = makeDeleteAccount();
