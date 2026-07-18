const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const {
  notifyRehearsalCreated,
  notifyRehearsalConfirmed,
} = require("../src/rehearsals");
const db = admin.firestore();

async function clearBands() {
  const snap = await db.collection("bands").get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

describe("rehearsal Telegram notifications", function () {
  this.timeout(20000);
  beforeEach(clearBands);
  after(clearBands);

  describe("notifyRehearsalCreated", () => {
    it("notifies required + optional invitees, not the whole band", async () => {
      const sent = [];
      const notified = await notifyRehearsalCreated(
        "b1",
        {
          title: "Friday jam",
          requiredMemberUids: ["u1"],
          optionalMemberUids: ["u2"],
        },
        { notify: async (uids, text) => (sent.push({ uids, text }), uids.length) },
      );
      assert.equal(notified, 2);
      assert.deepEqual(sent[0].uids.sort(), ["u1", "u2"]);
      assert.match(sent[0].text, /Friday jam/);
    });

    it("falls back to every band member when no one is explicitly invited", async () => {
      await db.collection("bands").doc("b1").set({ memberUids: ["u1", "u2", "u3"] });
      const sent = [];
      await notifyRehearsalCreated(
        "b1",
        { title: "Open rehearsal" },
        { notify: async (uids, text) => (sent.push({ uids, text }), uids.length) },
      );
      assert.deepEqual(sent[0].uids.sort(), ["u1", "u2", "u3"]);
    });
  });

  describe("notifyRehearsalConfirmed", () => {
    it("notifies on collecting -> confirmed transition", async () => {
      const sent = [];
      const notified = await notifyRehearsalConfirmed(
        "b1",
        { status: "collecting" },
        {
          status: "confirmed",
          title: "Full run-through",
          location: "Garage",
          confirmedSlotId: "s1",
          candidateSlots: [
            { id: "s1", startTime: "2026-07-20T19:00:00.000Z" },
          ],
          requiredMemberUids: ["u1"],
        },
        { notify: async (uids, text) => (sent.push({ uids, text }), uids.length) },
      );
      assert.equal(notified, 1);
      assert.match(sent[0].text, /Full run-through/);
      assert.match(sent[0].text, /Garage/);
    });

    it("does not notify when the status did not change to confirmed", async () => {
      const sent = [];
      await notifyRehearsalConfirmed(
        "b1",
        { status: "collecting" },
        { status: "collecting", requiredMemberUids: ["u1"] },
        { notify: async (uids, text) => (sent.push({ uids, text }), uids.length) },
      );
      assert.equal(sent.length, 0);
    });

    it("does not re-notify on an unrelated update once already confirmed", async () => {
      const sent = [];
      await notifyRehearsalConfirmed(
        "b1",
        { status: "confirmed", notes: "old" },
        { status: "confirmed", notes: "new", requiredMemberUids: ["u1"] },
        { notify: async (uids, text) => (sent.push({ uids, text }), uids.length) },
      );
      assert.equal(sent.length, 0);
    });
  });
});
