const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

async function isDemoUser(uid, token) {
  if (token && token.demo === true) return true;
  const userDoc = await db.collection("users").doc(uid).get();
  return userDoc.exists && userDoc.data().accessRole === "demo";
}

/**
 * Recomputes the derived UID arrays from a members array so that
 * memberUids / adminUids / editorUids never drift out of sync with members.
 */
function deriveUidArrays(members) {
  const memberUids = members.map((m) => m.uid);
  const adminUids = members
    .filter((m) => m.role === "admin")
    .map((m) => m.uid);
  const editorUids = members
    .filter((m) => m.role === "editor")
    .map((m) => m.uid);
  return { memberUids, adminUids, editorUids };
}

/**
 * Idempotent, server-authoritative band join.
 *
 * Input: { code } (invite code) or { bandId }.
 * - Validates the invite code / band id.
 * - If the caller is already a member, returns { alreadyMember: true } (no error).
 * - Otherwise atomically appends the caller as an `editor` member and rewrites
 *   the derived memberUids/adminUids/editorUids arrays, then registers the band
 *   under users/{uid}/bands/{bandId}.
 * - Demo users are rejected.
 */
exports.joinBand = functions.https.onCall(async (request) => {
  const data = request.data || {};
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
      "Demo users cannot join bands.",
    );
  }

  const payload = data || {};
  const code = cleanString(payload.code).toUpperCase();
  const bandId = cleanString(payload.bandId);

  if (!code && !bandId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "An invite code or band id is required.",
    );
  }

  // Resolve the band reference, by id if provided, otherwise by invite code.
  let bandRef;
  if (bandId) {
    bandRef = db.collection("bands").doc(bandId);
  } else {
    const snapshot = await db
      .collection("bands")
      .where("inviteCode", "==", code)
      .limit(1)
      .get();
    if (snapshot.empty) {
      throw new functions.https.HttpsError(
        "not-found",
        "Invalid invite code.",
      );
    }
    bandRef = snapshot.docs[0].ref;
  }

  const token = context.auth.token || {};
  const userRef = db.collection("users").doc(uid).collection("bands")
    .doc(bandRef.id);

  const result = await db.runTransaction(async (transaction) => {
    const bandDoc = await transaction.get(bandRef);
    if (!bandDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Band not found.");
    }

    const band = bandDoc.data() || {};
    const members = Array.isArray(band.members) ? band.members : [];
    const bandName = band.name || "";

    const alreadyMember = members.some((m) => m && m.uid === uid);
    if (alreadyMember) {
      // Self-heal derived arrays in case they drifted, but do not add a duplicate.
      transaction.set(bandRef, deriveUidArrays(members), { merge: true });
      transaction.set(
        userRef,
        { bandId: bandRef.id, joinedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true },
      );
      return { alreadyMember: true, bandId: bandRef.id, bandName };
    }

    const newMember = {
      uid,
      role: "editor",
      displayName: token.name || null,
      email: token.email || null,
      musicRoles: [],
    };
    const newMembers = [...members, newMember];

    transaction.set(
      bandRef,
      { members: newMembers, ...deriveUidArrays(newMembers) },
      { merge: true },
    );
    transaction.set(
      userRef,
      { bandId: bandRef.id, joinedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );

    return { alreadyMember: false, bandId: bandRef.id, bandName };
  });

  return result;
});

const VALID_ROLES = ["admin", "editor", "viewer"];

/**
 * Admin-only band member management.
 *
 * Input: { bandId, targetUid, action, role?, musicRoles? }
 *   action = "setRole"        -> set targetUid's permission role (requires role)
 *   action = "setMusicRoles"  -> replace targetUid's musicRoles (requires musicRoles[])
 *   action = "remove"         -> remove targetUid from the band
 *
 * The caller must be an admin of the band. The members array and the derived
 * memberUids/adminUids/editorUids arrays are rewritten atomically; removing a
 * member also deletes their users/{uid}/bands/{bandId} reference.
 */
exports.updateBandMember = functions.https.onCall(async (request) => {
  const data = request.data || {};
  const context = { auth: request.auth };
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Request must be authenticated.",
    );
  }

  const callerUid = context.auth.uid;
  if (await isDemoUser(callerUid, context.auth.token || {})) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Demo users cannot manage band members.",
    );
  }

  const payload = data || {};
  const bandId = cleanString(payload.bandId);
  const targetUid = cleanString(payload.targetUid);
  const action = cleanString(payload.action);

  if (!bandId || !targetUid || !action) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "bandId, targetUid and action are required.",
    );
  }
  if (!["setRole", "setMusicRoles", "remove"].includes(action)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Unknown action "${action}".`,
    );
  }

  const role = cleanString(payload.role);
  if (action === "setRole" && !VALID_ROLES.includes(role)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Invalid role "${role}".`,
    );
  }
  const musicRoles = Array.isArray(payload.musicRoles)
    ? payload.musicRoles.filter((r) => typeof r === "string")
    : [];

  const bandRef = db.collection("bands").doc(bandId);
  const targetPersonalRef = db
    .collection("users")
    .doc(targetUid)
    .collection("bands")
    .doc(bandId);

  await db.runTransaction(async (transaction) => {
    const bandDoc = await transaction.get(bandRef);
    if (!bandDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Band not found.");
    }

    const band = bandDoc.data() || {};
    const members = Array.isArray(band.members) ? [...band.members] : [];

    // Authorize: admins can manage any member. A non-admin member may still
    // remove *themselves* (leave the band) — the only self-service action.
    const callerIsAdmin = members.some(
      (m) => m && m.uid === callerUid && m.role === "admin",
    );
    const isSelfRemoval = action === "remove" && targetUid === callerUid;
    if (!callerIsAdmin && !isSelfRemoval) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only band admins can manage members.",
      );
    }

    const targetIndex = members.findIndex((m) => m && m.uid === targetUid);
    if (targetIndex === -1) {
      throw new functions.https.HttpsError(
        "not-found",
        "Target user is not a member of this band.",
      );
    }

    const adminCount = members.filter((m) => m && m.role === "admin").length;
    const target = { ...members[targetIndex] };

    if (action === "remove") {
      // Last member leaving dissolves the band: delete the band document and
      // the leaver's personal ref atomically. Without this a sole admin could
      // never get rid of their band — removeMember would hit the "last admin"
      // guard below forever, surfacing as an error on every leave attempt.
      // ponytail: band subcollections (songs/setlists/commits) are not cascaded
      // here; add a recursiveDelete if orphaned empty-band data shows up.
      if (members.length === 1 && targetUid === callerUid) {
        transaction.delete(bandRef);
        transaction.delete(targetPersonalRef);
        return;
      }
      if (target.role === "admin" && adminCount <= 1) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Cannot remove the last admin. Assign another admin first.",
        );
      }
      members.splice(targetIndex, 1);
      transaction.delete(targetPersonalRef);
    } else if (action === "setRole") {
      if (
        target.role === "admin" &&
        role !== "admin" &&
        adminCount <= 1
      ) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "A band must keep at least one admin.",
        );
      }
      target.role = role;
      members[targetIndex] = target;
    } else {
      target.musicRoles = musicRoles;
      members[targetIndex] = target;
    }

    transaction.set(
      bandRef,
      { members, ...deriveUidArrays(members) },
      { merge: true },
    );
  });

  return { ok: true };
});
