const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const gateway = require("../src/mcp/gateway");
const keys = require("../src/mcp/keys");
const db = admin.firestore();

function mockRes() {
  return {
    _s: 200,
    _j: null,
    status(c) {
      this._s = c;
      return this;
    },
    json(p) {
      this._j = p;
      return this;
    },
  };
}
function mockReq(token, tool, args) {
  return {
    method: "POST",
    body: tool ? { tool, args: args || {} } : {},
    get(h) {
      return h.toLowerCase() === "authorization" && token
        ? `Bearer ${token}`
        : undefined;
    },
  };
}
async function seedKey(uid, scope) {
  const token = `fg_test_${uid}_${scope}`;
  await db.collection("apiKeys").doc(keys._hashToken(token)).set({ uid, scope });
  return token;
}
async function clear() {
  const ak = await db.collection("apiKeys").get();
  await Promise.all(ak.docs.map((d) => d.ref.delete()));
  const us = await db.collection("users").get();
  await Promise.all(us.docs.map((d) => db.recursiveDelete(d.ref)));
}

describe("MCP gateway", function () {
  this.timeout(20000);
  beforeEach(clear);
  after(async () => {
    await clear();
    functionsTest.cleanup();
  });

  it("401 without a valid key", async () => {
    const res = mockRes();
    await gateway.handle(mockReq(null, "list_songs"), res);
    assert.equal(res._s, 401);
  });

  it("read key: list is empty, create is forbidden", async () => {
    const token = await seedKey("u1", "read");
    let res = mockRes();
    await gateway.handle(mockReq(token, "list_songs"), res);
    assert.equal(res._s, 200);
    assert.deepEqual(res._j.songs, []);

    res = mockRes();
    await gateway.handle(mockReq(token, "create_song", { song: { title: "X" } }), res);
    assert.equal(res._s, 403);
  });

  it("write key: create validates + writes; list/get reflect it", async () => {
    const token = await seedKey("u2", "write");

    // invalid BPM rejected
    let res = mockRes();
    await gateway.handle(
      mockReq(token, "create_song", { song: { title: "Bad", ourBPM: 5 } }),
      res,
    );
    assert.equal(res._j.error, "invalid");

    // valid create
    res = mockRes();
    await gateway.handle(
      mockReq(token, "create_song", {
        song: {
          title: "Zombie",
          ourKey: "Em",
          sections: [{ name: "Verse", chordChart: "[Em]hi" }],
        },
      }),
      res,
    );
    assert.equal(res._s, 200);
    const id = res._j.id;
    assert.ok(id);

    // list reflects it
    res = mockRes();
    await gateway.handle(mockReq(token, "list_songs"), res);
    assert.equal(res._j.songs.length, 1);
    assert.equal(res._j.songs[0].title, "Zombie");

    // get returns the chord chart
    res = mockRes();
    await gateway.handle(mockReq(token, "get_song", { id }), res);
    assert.equal(res._j.song.sections[0].chordChart, "[Em]hi");

    // stored section carries an id (Flutter Section model requires it)
    const doc = await db.collection("users").doc("u2").collection("songs").doc(id).get();
    assert.ok(doc.data().sections[0].id);
  });

  it("unknown tool → 400", async () => {
    const token = await seedKey("u1", "read");
    const res = mockRes();
    await gateway.handle(mockReq(token, "nuke_everything"), res);
    assert.equal(res._s, 400);
  });
});
