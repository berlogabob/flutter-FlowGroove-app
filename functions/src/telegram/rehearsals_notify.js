/**
 * Event-driven Telegram notifications for band rehearsals.
 *
 * Gen-1 Firestore triggers (firebase-functions/v1), matching reminders.js.
 */
const functions = require("firebase-functions/v1");
const { notifyBandMembers } = require("./services/notifications");

/** Notify consented band members when a new rehearsal proposal is created. */
exports.onRehearsalCreated = functions.firestore
  .document("bands/{bandId}/rehearsals/{rehearsalId}")
  .onCreate(async (snap, context) => {
    const { bandId } = context.params;
    const data = snap.data() || {};
    const title = data.title || "Rehearsal";
    const text =
      `🥁 *New rehearsal proposal:* ${title}\n\n` +
      `Open FlowGroove to vote on the times.`;
    const notified = await notifyBandMembers(bandId, text, {
      exceptUid: data.createdBy,
    });
    console.log(
      `onRehearsalCreated: notified ${notified} member(s) in band ${bandId}`,
    );
  });

/** Notify members when a rehearsal flips to confirmed. */
exports.onRehearsalUpdated = functions.firestore
  .document("bands/{bandId}/rehearsals/{rehearsalId}")
  .onUpdate(async (change, context) => {
    const { bandId } = context.params;
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (before.status === after.status || after.status !== "confirmed") {
      return null;
    }

    const title = after.title || "Rehearsal";
    const slot = (after.candidateSlots || []).find(
      (s) => s.id === after.confirmedSlotId,
    );
    const when = slot && slot.startTime ? formatWhen(slot.startTime) : "";
    const where = after.location ? `\n📍 ${after.location}` : "";
    const text =
      `✅ *Rehearsal confirmed:* ${title}` +
      (when ? `\n🗓 ${when}` : "") +
      where;
    const notified = await notifyBandMembers(bandId, text);
    console.log(
      `onRehearsalUpdated: confirmed, notified ${notified} member(s) in band ${bandId}`,
    );
    return null;
  });

/** ISO-8601 -> a short human-readable UTC string (best-effort). */
function formatWhen(iso) {
  try {
    return new Date(iso).toUTCString();
  } catch (e) {
    return iso;
  }
}
