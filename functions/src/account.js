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
const { purgeUserGrants, purgePersonalEventGrants } = require("./events");

async function isDemoUser(uid, token) {
  if (token && token.demo === true) return true;
  const userDoc = await db.collection("users").doc(uid).get();
  return userDoc.exists && userDoc.data().accessRole === "demo";
}

/**
 * Removes `uid` from every band. Per band, in a transaction:
 *  - drop them from members + all effective uid arrays;
 *  - if the band is left with no members or grants, delete it (its songs/setlists
 *    subcollections are cascaded afterwards with recursiveDelete);
 *  - if the band is left with members but no admin, promote the first remaining
 *    member so the band is never orphaned.
 *    ponytail: promote-first-member is the simplest non-orphan rule; swap for an
 *    explicit owner-succession prompt if bands need a say in who inherits admin.
 */
async function removeFromAllBands(uid) {
  const fields = ["memberUids", "adminUids", "editorUids"];
  const snapshots = await Promise.all(fields.map((field) =>
    db.collection("bands").where(field, "array-contains", uid).get(),
  ));
  const bandRefs = new Map();
  for (const snap of snapshots) {
    for (const doc of snap.docs) bandRefs.set(doc.id, doc.ref);
  }
  const emptied = [];
  for (const bandRef of bandRefs.values()) {
    const wasEmptied = await db.runTransaction(async (tx) => {
      const bandDoc = await tx.get(bandRef);
      if (!bandDoc.exists) return false;
      const band = bandDoc.data() || {};
      const members = (Array.isArray(band.members) ? band.members : []).filter(
        (m) => m && m.uid !== uid,
      );
      const arrays = {};
      for (const field of fields) {
        arrays[field] = (Array.isArray(band[field]) ? band[field] : []).filter(
          (memberUid) => memberUid !== uid,
        );
      }
      if (members.length === 0 && fields.every((field) => arrays[field].length === 0)) {
        tx.delete(bandRef);
        return true;
      }
      if (members.length > 0 && arrays.adminUids.length === 0) {
        members[0] = { ...members[0], role: "admin" };
        arrays.adminUids.push(members[0].uid);
      }
      tx.set(bandRef, { members, ...arrays }, { merge: true });
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

    // 1b. Release grants held in other scopes, then clear owned personal
    // event grants, guests' invites and share links. The invite index and
    // personal setlists must still exist for cleanup to find those records.
    await purgeUserGrants(uid);
    await purgePersonalEventGrants(uid);

    // 2. Delete all personal data (user doc + songs/setlists/bands subcollections).
    await db.recursiveDelete(db.collection("users").doc(uid));

    // 2b. Revoke MCP API keys and pending Telegram link tokens (top-level
    // collections, so the recursive delete above never reaches them).
    for (const col of ["apiKeys", "telegramLinkTokens"]) {
      const snap = await db.collection(col).where("uid", "==", uid).get();
      await Promise.all(snap.docs.map((d) => d.ref.delete()));
    }

    // 3. Best-effort delete the profile picture.
    const bucket = (getBucket || (() => admin.storage().bucket()))();
    try {
      await bucket.file(`profile_pictures/${uid}.jpg`).delete();
    } catch (e) {
      // Ignore "object not found" — nothing to remove.
    }

    // 4. Best-effort delete their audio notes. The read rule on this prefix is
    //    `request.auth.uid == uid`, so once the Auth account is gone in step 5
    //    nobody can ever read or remove these — they'd sit in the bucket,
    //    unreachable and billed, forever. Band audio is left alone: it belongs
    //    to the band, not the departing member.
    try {
      await bucket.deleteFiles({ prefix: `lab_audio/user/${uid}/` });
    } catch (e) {
      // Ignore — a leftover object is recoverable, a failed deletion is not.
    }

    // 5. Delete the Auth account last, so a failure above leaves the user able
    //    to retry. Admin SDK delete bypasses the client recent-login rule.
    const auth = (getAuth || (() => admin.auth()))();
    await auth.deleteUser(uid);

    return { ok: true };
  });
}

exports.makeDeleteAccount = makeDeleteAccount;
exports.deleteAccount = makeDeleteAccount();
