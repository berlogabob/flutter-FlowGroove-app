// The band document is the join secret plus everyone's email address.
//
// `allow read: if isAuthenticated()` looked harmless and was not: `read` covers
// `list`, and a condition that never touches `resource` makes the entire
// collection listable. Any signed-in account could enumerate every band in the
// project, read each one's member emails, and lift its inviteCode — the shared
// secret for joining. These tests state that as the leak it was.

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const projectId = "repsync-app-band-read-rules-test";
const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8",
);

const band = (id, memberUids) => ({
  id,
  name: `Band ${id}`,
  inviteCode: `CODE${id}`,
  memberUids,
  adminUids: memberUids.slice(0, 1),
  editorUids: [],
  members: memberUids.map((uid) => ({
    uid,
    role: "admin",
    displayName: uid,
    email: `${uid}@example.com`,
  })),
});

describe("Band document read rules", function () {
  this.timeout(20000);
  let testEnv;

  // Deliberately more than the 10-document-access ceiling for a query: if the
  // rule ever goes back to calling isGlobalBandMember() (a get() per doc), this
  // many bands makes the member's own list fail.
  const MINE = 12;

  before(async () => {
    testEnv = await initializeTestEnvironment({ projectId, firestore: { rules } });
  });
  after(async () => testEnv && testEnv.cleanup());

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      for (let i = 0; i < MINE; i++) {
        await db.collection("bands").doc(`mine-${i}`).set(band(`mine-${i}`, ["member"]));
      }
      await db.collection("bands").doc("theirs").set(band("theirs", ["someone-else"]));
      // A band doc written before memberUids existed — get(...,[]) must treat it
      // as "nobody", not raise, and not grant.
      await db.collection("bands").doc("legacy").set({ id: "legacy", name: "Legacy" });
    });
  });

  const as = (uid) => testEnv.authenticatedContext(uid).firestore();

  it("lets a member read their own band", async () => {
    await assertSucceeds(as("member").collection("bands").doc("mine-0").get());
  });

  it("lets a member list their own bands — within the 10-access budget", async () => {
    const snap = await as("member")
      .collection("bands")
      .where("memberUids", "array-contains", "member")
      .get();
    assert.equal(snap.size, MINE);
  });

  it("does NOT let a signed-in stranger read someone else's band", async () => {
    await assertFails(as("stranger").collection("bands").doc("mine-0").get());
  });

  it("does NOT let anyone list the whole bands collection", async () => {
    // The actual leak: emails and invite codes for every band in the project.
    await assertFails(as("stranger").collection("bands").get());
    await assertFails(as("member").collection("bands").get());
  });

  it("does NOT let a stranger query their way to another band's invite code", async () => {
    await assertFails(
      as("stranger").collection("bands").where("id", "==", "mine-0").get(),
    );
    await assertFails(
      as("stranger")
        .collection("bands")
        .where("inviteCode", "==", "CODEmine-0")
        .get(),
    );
    // Nor by claiming membership they do not have.
    await assertFails(
      as("stranger")
        .collection("bands")
        .where("memberUids", "array-contains", "member")
        .get(),
    );
  });

  it("denies a band document that has no memberUids at all", async () => {
    // get(field, []) must yield [] rather than raising — and grant nobody.
    await assertFails(as("member").collection("bands").doc("legacy").get());
    await assertFails(as("stranger").collection("bands").doc("legacy").get());
  });

  it("denies an unauthenticated reader outright", async () => {
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(anon.collection("bands").doc("mine-0").get());
  });
});
