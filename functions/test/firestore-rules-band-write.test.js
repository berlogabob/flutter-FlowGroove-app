const fs = require("node:fs");
const path = require("node:path");
const { assertFails, assertSucceeds, initializeTestEnvironment } =
  require("@firebase/rules-unit-testing");

const rules = fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8");
const base = (over = {}) => ({
  id: "b1", name: "B", createdBy: "admin",
  members: [{ uid: "admin", role: "admin" }],
  memberUids: ["admin"], adminUids: ["admin"], editorUids: [], ...over,
});

describe("band write rules (audit)", function () {
  this.timeout(20000);
  let env;
  before(async () => {
    env = await initializeTestEnvironment({ projectId: "repsync-app-band-write-test", firestore: { rules } });
  });
  after(async () => env && env.cleanup());
  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (c) => {
      await c.firestore().doc("users/admin").set({ accessRole: "member" });
      await c.firestore().doc("bands/b1").set(base());
    });
  });
  const as = (uid) => env.authenticatedContext(uid).firestore();

  it("creator can create a band with only themself as admin", async () => {
    await assertSucceeds(as("admin").doc("bands/new").set(base({ id: "new" })));
  });
  it("creating a band with extra members is denied", async () => {
    await assertFails(as("admin").doc("bands/new").set(base({ id: "new", memberUids: ["admin", "x"] })));
    await assertFails(as("admin").doc("bands/new").set(base({ id: "new", adminUids: ["admin", "x"] })));
  });
  it("admin can rename but not rewrite uid arrays", async () => {
    await assertSucceeds(as("admin").doc("bands/b1").set(base({ name: "Renamed" })));
    await assertFails(as("admin").doc("bands/b1").set(base({ memberUids: ["admin", "x"] })));
    await assertFails(as("admin").doc("bands/b1").update({ editorUids: ["x"] }));
  });
});
