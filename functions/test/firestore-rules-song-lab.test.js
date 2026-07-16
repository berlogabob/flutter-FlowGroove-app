const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const projectId = "repsync-app-lab-rules-test";
const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8",
);

const entry = (author) => ({
  id: "e1",
  songId: "song-1",
  type: "note",
  body: "riff idea",
  authorId: author,
  visibility: "band",
  createdAt: "2026-07-16T12:00:00.000",
  updatedAt: "2026-07-16T12:00:00.000",
  tags: [],
  attachmentIds: [],
});

describe("Song Lab Firestore rules (#66)", function () {
  this.timeout(20000);
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: { rules },
    });
  });
  after(async () => testEnv && testEnv.cleanup());

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection("users").doc("member").set({ uid: "member" });
      await db.collection("users").doc("editor").set({ uid: "editor" });
      await db.collection("users").doc("outsider").set({ uid: "outsider" });
      await db.collection("bands").doc("band-1").set({
        id: "band-1",
        memberUids: ["member", "editor"],
        editorUids: ["editor"],
        adminUids: [],
      });
      await db
        .collection("bands")
        .doc("band-1")
        .collection("songs")
        .doc("song-1")
        .set({ id: "song-1", title: "X" });
      await db
        .collection("users")
        .doc("member")
        .collection("songs")
        .doc("song-p")
        .set({ id: "song-p", title: "Y" });
    });
  });

  const labDoc = (db, uid = "band-1") =>
    db
      .collection("bands")
      .doc(uid)
      .collection("songs")
      .doc("song-1")
      .collection("labEntries")
      .doc("e1");

  it("band member reads, editor writes, outsider denied", async () => {
    const editor = testEnv.authenticatedContext("editor").firestore();
    const member = testEnv.authenticatedContext("member").firestore();
    const outsider = testEnv.authenticatedContext("outsider").firestore();

    await assertSucceeds(labDoc(editor).set(entry("editor")));
    await assertSucceeds(labDoc(member).get());
    await assertFails(labDoc(member).set(entry("member"))); // member, not editor
    await assertFails(labDoc(outsider).get());
    await assertFails(labDoc(outsider).set(entry("outsider")));
  });

  it("author can delete own entry; plain member cannot delete others'", async () => {
    const editor = testEnv.authenticatedContext("editor").firestore();
    await assertSucceeds(labDoc(editor).set(entry("editor")));

    const member = testEnv.authenticatedContext("member").firestore();
    await assertFails(labDoc(member).delete());
    await assertSucceeds(labDoc(editor).delete());
  });

  it("commits stay append-only despite the lab wildcard", async () => {
    const editor = testEnv.authenticatedContext("editor").firestore();
    const commit = editor
      .collection("bands")
      .doc("band-1")
      .collection("songs")
      .doc("song-1")
      .collection("commits")
      .doc("c1");
    // update/delete on commits must still be denied for everyone.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection("bands")
        .doc("band-1")
        .collection("songs")
        .doc("song-1")
        .collection("commits")
        .doc("c1")
        .set({ id: "c1" });
    });
    await assertFails(commit.update({ id: "c2" }));
    await assertFails(commit.delete());
  });

  it("personal song lab is owner-only", async () => {
    const owner = testEnv.authenticatedContext("member").firestore();
    const stranger = testEnv.authenticatedContext("editor").firestore();
    const doc = (db) =>
      db
        .collection("users")
        .doc("member")
        .collection("songs")
        .doc("song-p")
        .collection("tasks")
        .doc("t1");

    await assertSucceeds(
      doc(owner).set({ id: "t1", songId: "song-p", title: "practice" }),
    );
    await assertFails(doc(stranger).get());
    await assertFails(
      doc(stranger).set({ id: "t1", songId: "song-p", title: "practice" }),
    );
  });
});
