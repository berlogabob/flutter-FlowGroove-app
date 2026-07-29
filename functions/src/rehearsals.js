/**
 * Event-driven Telegram notifications and server-side actions for rehearsal
 * plans (bands/{bandId}/rehearsals/{rehearsalId}).
 *
 * Firestore triggers mirror functions/src/telegram/reminders.js (injectable
 * core function + thin trigger wrapper); the callable mirrors the
 * factory/auth pattern in functions/src/band_avatar.js.
 */
const functionsV1 = require("firebase-functions/v1");
const functions = require("firebase-functions");
const { db } = require("./telegram/config");
const { notifyUids } = require("./telegram/services/notifications");

/** Required + optional invited uids, falling back to every band member. */
async function resolveInvited(bandId, data) {
  const required = Array.isArray(data.requiredMemberUids)
    ? data.requiredMemberUids
    : [];
  const optional = Array.isArray(data.optionalMemberUids)
    ? data.optionalMemberUids
    : [];
  const invited = [...new Set([...required, ...optional])];
  if (invited.length > 0) return invited;

  const bandDoc = await db.collection("bands").doc(bandId).get();
  return bandDoc.exists ? bandDoc.data().memberUids || [] : [];
}

/** Core logic for onRehearsalCreated, injectable for tests. */
async function notifyRehearsalCreated(bandId, data, { notify = notifyUids } = {}) {
  const title = data.title || "Rehearsal";
  const uids = await resolveInvited(bandId, data);
  const text =
    `🗳️ *New rehearsal proposal:* ${title}\n\n` +
    `Vote on the best time in FlowGroove.`;
  return notify(uids, text);
}

/** Core logic for onRehearsalConfirmed, injectable for tests. */
async function notifyRehearsalConfirmed(
  bandId,
  before,
  after,
  { notify = notifyUids } = {},
) {
  if (before.status === after.status || after.status !== "confirmed") {
    return 0;
  }
  const title = after.title || "Rehearsal";
  const slot = (after.candidateSlots || []).find(
    (s) => s && s.id === after.confirmedSlotId,
  );
  const when =
    slot && slot.startTime
      ? ` on ${new Date(slot.startTime).toDateString()}`
      : "";
  const where = after.location ? ` at ${after.location}` : "";
  const text = `✅ *Rehearsal confirmed:* ${title}${when}${where}`;
  const uids = await resolveInvited(bandId, after);
  return notify(uids, text);
}

/** Notify invited members when a new rehearsal proposal needs their vote. */
exports.onRehearsalCreated = functionsV1.firestore
  .document("bands/{bandId}/rehearsals/{rehearsalId}")
  .onCreate(async (snap, context) => {
    const { bandId } = context.params;
    const notified = await notifyRehearsalCreated(bandId, snap.data() || {});
    console.log(
      `onRehearsalCreated: notified ${notified} member(s) in band ${bandId}`,
    );
  });

/** Notify invited members once a rehearsal is confirmed. */
exports.onRehearsalConfirmed = functionsV1.firestore
  .document("bands/{bandId}/rehearsals/{rehearsalId}")
  .onUpdate(async (change, context) => {
    const { bandId } = context.params;
    const notified = await notifyRehearsalConfirmed(
      bandId,
      change.before.data() || {},
      change.after.data() || {},
    );
    console.log(
      `onRehearsalConfirmed: notified ${notified} member(s) in band ${bandId}`,
    );
  });

/**
 * Builds the remindRehearsalVoters callable; `notify` is injectable for
 * testing.
 *
 * Input: { bandId, rehearsalId }. Caller must be an editor/admin of the band
 * (same tier that can confirm a rehearsal in the app). Pings invited members
 * who haven't voted yet.
 */
function makeRemindRehearsalVoters({ notify = notifyUids } = {}) {
  return functions.https.onCall(async (request) => {
    const data = request.data || {};
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Request must be authenticated.",
      );
    }
    const uid = request.auth.uid;
    const bandId = typeof data.bandId === "string" ? data.bandId.trim() : "";
    const rehearsalId =
      typeof data.rehearsalId === "string" ? data.rehearsalId.trim() : "";
    if (!bandId || !rehearsalId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "bandId and rehearsalId are required.",
      );
    }

    const bandDoc = await db.collection("bands").doc(bandId).get();
    if (!bandDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Band not found.");
    }
    const band = bandDoc.data() || {};
    const canEdit =
      (band.adminUids || []).includes(uid) ||
      (band.editorUids || []).includes(uid);
    if (!canEdit) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only band editors/admins can send reminders.",
      );
    }

    const rehearsalRef = db
      .collection("bands")
      .doc(bandId)
      .collection("rehearsals")
      .doc(rehearsalId);
    const rehearsalDoc = await rehearsalRef.get();
    if (!rehearsalDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Rehearsal not found.",
      );
    }
    const rehearsal = rehearsalDoc.data() || {};

    const votesSnap = await rehearsalRef.collection("votes").get();
    // A vote doc can exist with no answers (a member left a suggestion via
    // "suggest a time" without voting on any slot) — that doesn't count as
    // having responded.
    const voted = new Set(
      votesSnap.docs
        .filter((d) => Object.keys(d.data().answers || {}).length > 0)
        .map((d) => d.id),
    );
    const invited = await resolveInvited(bandId, rehearsal);
    const notVoted = invited.filter((u) => !voted.has(u));

    const title = rehearsal.title || "Rehearsal";
    const text = `⏰ *Reminder:* please vote on "${title}" in FlowGroove.`;
    const notified = await notify(notVoted, text);

    return { notified };
  });
}

exports.makeRemindRehearsalVoters = makeRemindRehearsalVoters;
exports.remindRehearsalVoters = makeRemindRehearsalVoters();
exports.notifyRehearsalCreated = notifyRehearsalCreated;
exports.notifyRehearsalConfirmed = notifyRehearsalConfirmed;
