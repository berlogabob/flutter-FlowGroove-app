const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const { makeRemindRehearsalVoters } = require("../src/rehearsals");
const db = admin.firestore();

// Build a gen-2 CallableRequest ({ data, auth }); omit auth for unauthenticated.
const req = (data, uid) => (uid ? { data, auth: { uid } } : { data });

function build() {
  const sent = [];
  return {
    fn: functionsTest.wrap(
      makeRemindRehearsalVoters({
        notify: async (uids, text) => (sent.push({ uids, text }), uids.length),
      }),
    ),
    sent,
  };
}

async function clearBands() {
  const snap = await db.collection("bands").get();
  for (const d of snap.docs) {
    const rehearsals = await d.ref.collection("rehearsals").get();
    for (const r of rehearsals.docs) {
      const votes = await r.ref.collection("votes").get();
      await Promise.all(votes.docs.map((v) => v.ref.delete()));
      await r.ref.delete();
    }
    await d.ref.delete();
  }
}

describe("remindRehearsalVoters callable", function () {
  this.timeout(20000);
  beforeEach(clearBands);
  after(async () => {
    await clearBands();
    functionsTest.cleanup();
  });

  it("rejects unauthenticated callers", async () => {
    const { fn } = build();
    await assert.rejects(
      () => fn(req({ bandId: "b1", rehearsalId: "r1" })),
      (e) => e.code === "unauthenticated",
    );
  });

  it("rejects a member who is not an editor/admin", async () => {
    await db.collection("bands").doc("b1").set({ adminUids: ["admin1"], editorUids: [] });
    const { fn } = build();
    await assert.rejects(
      () => fn(req({ bandId: "b1", rehearsalId: "r1" }, "viewer1")),
      (e) => e.code === "permission-denied",
    );
  });

  it("requires bandId and rehearsalId", async () => {
    const { fn } = build();
    await assert.rejects(
      () => fn(req({ bandId: "b1" }, "admin1")),
      (e) => e.code === "invalid-argument",
    );
  });

  it("notifies only invitees who haven't voted yet", async () => {
    await db.collection("bands").doc("b1").set({ adminUids: ["admin1"] });
    const rehearsalRef = db
      .collection("bands")
      .doc("b1")
      .collection("rehearsals")
      .doc("r1");
    await rehearsalRef.set({
      title: "Friday jam",
      requiredMemberUids: ["u1", "u2"],
    });
    await rehearsalRef
      .collection("votes")
      .doc("u1")
      .set({ uid: "u1", answers: { s1: "can" } });

    const { fn, sent } = build();
    const result = await fn(
      req({ bandId: "b1", rehearsalId: "r1" }, "admin1"),
    );

    assert.equal(result.notified, 1);
    assert.deepEqual(sent[0].uids, ["u2"]);
    assert.match(sent[0].text, /Friday jam/);
  });

  it("still reminds a member who only left a comment without voting", async () => {
    await db.collection("bands").doc("b1").set({ adminUids: ["admin1"] });
    const rehearsalRef = db
      .collection("bands")
      .doc("b1")
      .collection("rehearsals")
      .doc("r1");
    await rehearsalRef.set({
      title: "Friday jam",
      requiredMemberUids: ["u1", "u2"],
    });
    await rehearsalRef.collection("votes").doc("u1").set({
      uid: "u1",
      answers: { s1: "can" },
    });
    await rehearsalRef.collection("votes").doc("u2").set({
      uid: "u2",
      answers: {},
      comment: "None of these work, how about Sunday?",
    });

    const { fn, sent } = build();
    const result = await fn(
      req({ bandId: "b1", rehearsalId: "r1" }, "admin1"),
    );

    assert.equal(result.notified, 1);
    assert.deepEqual(sent[0].uids, ["u2"]);
  });
});
