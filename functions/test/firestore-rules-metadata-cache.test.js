// metadata_cache holds raw third-party responses (MusicBrainz / Spotify /
// Deezer / lyrics.ovh) for the resolver. It is written only by Cloud Functions
// through the admin SDK, which bypasses rules entirely — so no client needs any
// access, and granting any would both leak provider payloads and let a client
// poison what every other user then reads.
//
// This asserts the collection is fully closed, including to the signed-in owner
// of the library that triggered the lookup.

const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const projectId = "repsync-app-rules-test";
const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8",
);

describe("metadata_cache Firestore rules", function () {
  this.timeout(20000);

  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({ projectId, firestore: { rules } });
  });

  after(async () => {
    if (testEnv) await testEnv.cleanup();
  });

  beforeEach(async () => {
    if (testEnv) await testEnv.clearFirestore();
  });

  const entry = "musicbrainz.org__deadbeefdeadbeefdeadbeefdeadbeefdeadbeef";

  it("denies reads to an authenticated user", async () => {
    const db = testEnv.authenticatedContext("user-1").firestore();
    await assertFails(db.collection("metadata_cache").doc(entry).get());
  });

  it("denies reads to an unauthenticated client", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection("metadata_cache").doc(entry).get());
  });

  it("denies writes, so a client cannot poison the shared cache", async () => {
    const db = testEnv.authenticatedContext("user-1").firestore();
    await assertFails(
      db.collection("metadata_cache").doc(entry).set({
        url: "https://musicbrainz.org/ws/2/recording/?query=x",
        body: JSON.stringify({ recordings: [{ id: "attacker-controlled" }] }),
        expiresAt: new Date(Date.now() + 86400000),
      }),
    );
  });

  it("denies updates and deletes", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("metadata_cache").doc(entry).set({
        url: "https://x.test/a",
        body: "{}",
        expiresAt: new Date(Date.now() + 86400000),
      });
    });
    const db = testEnv.authenticatedContext("user-1").firestore();
    await assertFails(db.collection("metadata_cache").doc(entry).update({ body: "{}" }));
    await assertFails(db.collection("metadata_cache").doc(entry).delete());
  });

  it("denies listing the collection", async () => {
    const db = testEnv.authenticatedContext("user-1").firestore();
    await assertFails(db.collection("metadata_cache").limit(5).get());
  });
});
