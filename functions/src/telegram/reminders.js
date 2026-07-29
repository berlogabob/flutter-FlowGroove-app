/**
 * Event-driven and scheduled Telegram notifications for bands.
 *
 * Uses the gen-1 trigger/scheduler APIs (firebase-functions/v1) to match the
 * existing functions' deployment model.
 */
const functions = require("firebase-functions/v1");
const { db } = require("./config");
const { notifyBandMembers } = require("./services/notifications");

/** Notify consented band members when a new setlist is created. */
exports.onBandSetlistCreated = functions.firestore
  .document("bands/{bandId}/setlists/{setlistId}")
  .onCreate(async (snap, context) => {
    const { bandId } = context.params;
    const data = snap.data() || {};
    const name = data.name || "Setlist";
    const text = `🎵 *New setlist:* ${name}\n\nOpen FlowGroove to view it.`;
    const notified = await notifyBandMembers(bandId, text);
    console.log(
      `onBandSetlistCreated: notified ${notified} member(s) in band ${bandId}`,
    );
  });

/**
 * Daily reminder for band events/rehearsals happening within the next 24 hours.
 *
 * `eventDateTime` is written by the app as an ISO-8601 string, which sorts
 * chronologically, so string range bounds give a correct window. The
 * collection-group query also matches personal (users/{uid}/setlists) lists;
 * those resolve to a non-existent "band" doc and are safely skipped by
 * notifyBandMembers.
 *
 * Requires Cloud Scheduler enabled on the project and a single-field index on
 * the `setlists` collection-group `eventDateTime` (Firestore prompts for it).
 */
exports.dailyEventReminder = functions.pubsub
  .schedule("every 24 hours")
  .onRun(() => runDailyEventReminder());

/** Core scan, injectable for tests: `notify(bandId, text)`, `now`. */
async function runDailyEventReminder({
  notify = notifyBandMembers,
  now = new Date(),
} = {}) {
  const soon = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  const snap = await db
    .collectionGroup("setlists")
    .where("eventDateTime", ">=", now.toISOString())
    .where("eventDateTime", "<=", soon.toISOString())
    .get();

  for (const doc of snap.docs) {
    const bandId = doc.ref.parent.parent && doc.ref.parent.parent.id;
    if (!bandId) continue;
    const data = doc.data();
    const name = data.name || "Event";
    const text = `⏰ *Reminder:* "${name}" is coming up in the next 24 hours.`;
    await notify(bandId, text);
  }

  // Confirmed rehearsals starting within the window (#57). The confirmed
  // slot's startTime lives inside the candidateSlots array, so the window
  // check happens in code; confirmed rehearsals per band are few.
  const rehearsals = await db
    .collectionGroup("rehearsals")
    .where("status", "==", "confirmed")
    .get();

  for (const doc of rehearsals.docs) {
    const bandId = doc.ref.parent.parent && doc.ref.parent.parent.id;
    if (!bandId) continue;
    const data = doc.data();
    const slot = (data.candidateSlots || []).find(
      (s) => s && s.id === data.confirmedSlotId,
    );
    if (!slot || !slot.startTime) continue;
    const start = new Date(slot.startTime);
    if (isNaN(start) || start < now || start > soon) continue;
    const title = data.title || "Rehearsal";
    const where = data.location ? ` at ${data.location}` : "";
    const text =
      `🥁 *Rehearsal reminder:* "${title}"${where} ` +
      `is coming up in the next 24 hours.`;
    await notify(bandId, text);
  }

  return null;
}

exports.runDailyEventReminder = runDailyEventReminder;
