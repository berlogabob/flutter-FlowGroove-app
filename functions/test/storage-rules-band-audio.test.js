const fs = require("node:fs");
const path = require("node:path");
const { assertFails, assertSucceeds, initializeTestEnvironment } =
  require("@firebase/rules-unit-testing");

describe("Storage rules: band lab audio", function () {
  this.timeout(30000);
  let env;
  before(async () => {
    env = await initializeTestEnvironment({
      projectId: process.env.GCLOUD_PROJECT || "repsync-app-storage-rules-test",
      firestore: { rules: fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8") },
      storage: { rules: fs.readFileSync(path.resolve(__dirname, "../../storage.rules"), "utf8") },
    });
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("bands/b1").set({ memberUids: ["member"] });
    });
  });
  after(async () => env && env.cleanup());

  const ref = (uid) => env.authenticatedContext(uid).storage().ref("lab_audio/band/b1/s1/a.m4a");
  const bytes = new Uint8Array([1, 2, 3]);

  it("member can write and delete", async () => {
    await assertSucceeds(ref("member").put(bytes));
    await assertSucceeds(ref("member").delete());
  });
  it("non-member cannot write or delete", async () => {
    await assertFails(ref("outsider").put(bytes));
    await env.withSecurityRulesDisabled(async (ctx) => { await ctx.storage().ref("lab_audio/band/b1/s1/a.m4a").put(bytes); });
    await assertFails(ref("outsider").delete());
  });
});
