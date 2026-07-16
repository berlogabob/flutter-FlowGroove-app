const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const { runDailyEventReminder } = require("../src/telegram/reminders");
const db = admin.firestore();

async function clearAll() {
  for (const name of ["bands"]) {
    const snap = await db.collection(name).get();
    for (const d of snap.docs) {
      for (const sub of ["setlists", "rehearsals"]) {
        const subSnap = await d.ref.collection(sub).get();
        await Promise.all(subSnap.docs.map((x) => x.ref.delete()));
      }
      await d.ref.delete();
    }
  }
}

describe("runDailyEventReminder (#57)", function () {
  this.timeout(20000);
  beforeEach(clearAll);
  after(clearAll);

  const now = new Date("2026-07-16T12:00:00Z");
  const inTwelveHours = new Date("2026-07-17T00:00:00Z").toISOString();
  const inTwoDays = new Date("2026-07-18T12:00:00Z").toISOString();

  it("notifies for a confirmed rehearsal within 24h, skips others", async () => {
    await db.collection("bands").doc("b1").set({ memberUids: [] });
    const rehearsals = db.collection("bands").doc("b1").collection("rehearsals");

    await rehearsals.doc("r-soon").set({
      title: "Full run-through",
      location: "Garage",
      status: "confirmed",
      confirmedSlotId: "s1",
      candidateSlots: [
        { id: "s1", startTime: inTwelveHours, endTime: inTwelveHours },
      ],
    });
    await rehearsals.doc("r-later").set({
      title: "Next week",
      status: "confirmed",
      confirmedSlotId: "s1",
      candidateSlots: [{ id: "s1", startTime: inTwoDays, endTime: inTwoDays }],
    });
    await rehearsals.doc("r-collecting").set({
      title: "Still voting",
      status: "collecting",
      candidateSlots: [
        { id: "s1", startTime: inTwelveHours, endTime: inTwelveHours },
      ],
    });

    const sent = [];
    await runDailyEventReminder({
      now,
      notify: async (bandId, text) => sent.push({ bandId, text }),
    });

    assert.equal(sent.length, 1);
    assert.equal(sent[0].bandId, "b1");
    assert.match(sent[0].text, /Rehearsal reminder/);
    assert.match(sent[0].text, /Full run-through/);
    assert.match(sent[0].text, /Garage/);
  });

  it("still notifies for setlist events within 24h", async () => {
    await db.collection("bands").doc("b2").set({ memberUids: [] });
    await db
      .collection("bands")
      .doc("b2")
      .collection("setlists")
      .doc("sl1")
      .set({ name: "Club gig", eventDateTime: inTwelveHours });

    const sent = [];
    await runDailyEventReminder({
      now,
      notify: async (bandId, text) => sent.push({ bandId, text }),
    });

    assert.equal(sent.length, 1);
    assert.match(sent[0].text, /Club gig/);
  });

  it("ignores rehearsals whose confirmed slot is missing", async () => {
    await db.collection("bands").doc("b3").set({ memberUids: [] });
    await db
      .collection("bands")
      .doc("b3")
      .collection("rehearsals")
      .doc("r-broken")
      .set({
        title: "Broken",
        status: "confirmed",
        confirmedSlotId: "nope",
        candidateSlots: [
          { id: "s1", startTime: inTwelveHours, endTime: inTwelveHours },
        ],
      });

    const sent = [];
    await runDailyEventReminder({
      now,
      notify: async (bandId, text) => sent.push({ bandId, text }),
    });
    assert.equal(sent.length, 0);
  });
});
