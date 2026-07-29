// getBandInviteInfo resolves an invite code -> a PUBLIC-safe band subset for the
// pre-login Welcome screen. Critical property: it must never leak members,
// emails, or any non-public field. Pure handler + fake db, so no emulator.

const assert = require("node:assert/strict");
const { bandInviteInfo } = require("../src/bands");

// Minimal Firestore stand-in: collection("bands").where(...).limit(...).get()
// returns the seeded band whose inviteCode matches (case-insensitive).
function fakeDb(bands) {
  return {
    collection() {
      let match = null;
      const api = {
        where(field, _op, value) {
          if (field === "inviteCode") {
            const doc = bands.find((b) => b.inviteCode === value);
            match = doc ? { id: doc.id, data: () => doc } : null;
          }
          return api;
        },
        limit() { return api; },
        async get() {
          return { empty: !match, docs: match ? [match] : [] };
        },
      };
      return api;
    },
  };
}

const BAND = {
  id: "band-1",
  name: "super AG2700",
  inviteCode: "PUQ690",
  members: [
    { uid: "u1", role: "admin", displayName: "Andrey", email: "a@example.com" },
    { uid: "u2", role: "editor", displayName: "Roman", email: "r@example.com" },
  ],
};

describe("bandInviteInfo", () => {
  it("returns only a public subset for a valid code (uppercased)", async () => {
    const db = fakeDb([BAND]);
    const out = await bandInviteInfo(db, "puq690"); // lower-case input
    assert.deepEqual(out, {
      bandId: "band-1",
      name: "super AG2700",
      memberCount: 2,
      adminName: "Andrey",
    });
    // Must NOT leak members, emails, or anything else.
    assert.deepEqual(Object.keys(out).sort(), [
      "adminName", "bandId", "memberCount", "name",
    ]);
    assert.equal(JSON.stringify(out).includes("@example.com"), false);
  });

  it("throws not-found for an unknown code", async () => {
    const db = fakeDb([BAND]);
    await assert.rejects(() => bandInviteInfo(db, "NOPE99"), /Invalid invite code/);
  });

  it("throws invalid-argument for an empty code", async () => {
    const db = fakeDb([BAND]);
    await assert.rejects(() => bandInviteInfo(db, ""), /invite code is required/);
  });

  it("omits adminName when the admin has no display name", async () => {
    const db = fakeDb([{ ...BAND, members: [{ uid: "u1", role: "admin", email: "a@x.com" }] }]);
    const out = await bandInviteInfo(db, "PUQ690");
    assert.equal(out.adminName, null);
  });
});
