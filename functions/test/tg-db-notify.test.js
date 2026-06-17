const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const { notifyBandMembers } = require("../src/telegram/services/notifications");
const db = admin.firestore();

async function clearCollection(name) {
  const snap = await db.collection(name).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}
async function clearAll() {
  await clearCollection("bands");
  await clearCollection("users");
}

describe("notifyBandMembers", function () {
  this.timeout(20000);
  beforeEach(clearAll);
  after(clearAll);

  it("notifies only consented + linked members and skips exceptUid", async () => {
    await db.collection("bands").doc("b1").set({
      memberUids: ["a", "b", "c", "d"],
    });
    await db.collection("users").doc("a").set({
      telegramId: "100",
      telegramConsent: true,
    });
    await db.collection("users").doc("b").set({
      telegramId: "200",
      telegramConsent: false, // not consented -> skipped
    });
    await db.collection("users").doc("c").set({
      displayName: "no telegram", // not linked -> skipped
    });
    await db.collection("users").doc("d").set({
      telegramId: "400",
      telegramConsent: true, // excepted below -> skipped
    });

    const sent = [];
    const count = await notifyBandMembers("b1", "hi", {
      exceptUid: "d",
      send: async (telegramId) => sent.push(telegramId),
    });

    assert.equal(count, 1);
    assert.deepEqual(sent, ["100"]);
  });

  it("returns 0 for a band that does not exist", async () => {
    const count = await notifyBandMembers("missing", "x", {
      send: async () => {},
    });
    assert.equal(count, 0);
  });
});
