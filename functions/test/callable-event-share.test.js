// Event participants: scoped access to ONE event for people who are not in the
// band. The property under test throughout is that an area the caller cannot
// see is ABSENT from the payload — not merely flagged. Filtering in the client
// would leave the data on the wire, which is the leak this exists to close.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-event-share-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const events = require("../src/events");
const db = admin.firestore();

const req = (data, uid) => (uid ? { data, auth: { uid } } : { data });
const call = (fn) => functionsTest.wrap(fn);

const BAND = "band-1";
const SETLIST = "sl-1";

const PEOPLE = [
  {
    id: "p-couple",
    name: "Ana & Rui",
    role: "client",
    access: { eventInfo: "view", runningOrder: "view" },
    canSuggest: true,
  },
  {
    id: "p-eng",
    name: "Sputnik sound",
    role: "sound_engineer",
    access: {
      eventInfo: "view",
      runningOrder: "view",
      stage: "edit",
      rider: "view",
    },
  },
  {
    id: "p-roume",
    name: "Roumé",
    role: "performing_guest",
    uid: "roume",
    access: { eventInfo: "view", runningOrder: "view", songDetail: "view" },
  },
];

async function seed(people = PEOPLE) {
  await db.collection("bands").doc(BAND).set({
    id: BAND,
    memberUids: ["member"],
    editorUids: ["member"],
    adminUids: ["member"],
  });
  await db
    .collection("bands")
    .doc(BAND)
    .collection("songs")
    .doc("song-1")
    .set({
      id: "song-1",
      title: "visto",
      artist: "Flor Damico",
      ourKey: "Bm",
      ourBPM: 96,
      sections: [{ name: "Verse 1", chordChart: "[Am]Ya no necesito" }],
    });
  await db
    .collection("bands")
    .doc(BAND)
    .collection("setlists")
    .doc(SETLIST)
    .set({
      id: SETLIST,
      bandId: BAND,
      name: "Sputnik Bar",
      eventDateTime: "2026-08-21T19:00:00.000Z",
      eventLocation: "Sputnik Bar, Lisbon",
      items: [{ id: "i1", songId: "song-1", type: "song" }],
      songIds: ["song-1"],
      eventKit: {
        stage: { "back-left": [{ kind: "equipment", label: "Drum kit" }] },
        rider: [{ label: "XLR cables", done: false }],
        people,
      },
    });
  // Grants live in their own documents; writeGrants is the only thing that
  // writes them, so seeding through it also exercises it.
  await events.writeGrants({ bandId: BAND }, SETLIST, people, { name: "Sputnik Bar" });
}

async function shareFor(participantId) {
  const out = await call(events.createEventShare)(
    req({ bandId: BAND, setlistId: SETLIST, participantId }, "member"),
  );
  return out.token;
}

describe("event sharing callables", function () {
  this.timeout(20000);

  beforeEach(async () => {
    for (const path of [
      `bands/${BAND}/setlists/${SETLIST}`,
      `bands/${BAND}/songs/song-1`,
      `bands/${BAND}`,
    ]) {
      await db.doc(path).delete();
    }
    // Grants and the per-user invite index are separate documents now, so the
    // per-test reset has to reach them too or state leaks between tests.
    for (const col of [
      db.collection("eventShares"),
      db.collection(`bands/${BAND}/setlists/${SETLIST}/grants`),
      db.collection(`bands/${BAND}/setlists/${SETLIST}/suggestions`),
      db.collection(`bands/${BAND}/setlists/${SETLIST}/eventPublication`),
    ]) {
      const snap = await col.get();
      await Promise.all(snap.docs.map((d) => d.ref.delete()));
    }
    for (const uid of ["roume", "eng", "sneaky"]) {
      await db.doc(`users/${uid}/eventInvites/${SETLIST}`).delete();
    }
    await seed();
  });

  after(() => functionsTest.cleanup());

  for (const scope of [{ bandId: BAND }, { ownerUid: "candidate-owner" }]) {
    describe(`suggestion publication (${scope.bandId ? "band" : "personal"})`, () => {
      const root = scope.bandId ? `bands/${BAND}` : `users/${scope.ownerUid}`;
      const path = `${root}/setlists/${SETLIST}`;
      const args = { ...scope, setlistId: SETLIST, songId: "song-1", published: true };
      const writer = scope.ownerUid || "member";
      const publish = (extra = {}, uid = writer) => call(events.setEventSuggestionCandidate)(req({ ...args, ...extra }, uid));
      const view = (data = { ...scope, setlistId: SETLIST }, uid = writer) => call(events.getEventView)(req(data, uid));
      const candidates = () => db.doc(`${path}/eventPublication/candidates`).get();
      beforeEach(async () => {
        if (scope.ownerUid) {
          await db.recursiveDelete(db.doc(root));
          const event = (await db.doc(`bands/${BAND}/setlists/${SETLIST}`).get()).data();
          await db.doc(path).set(event);
          await events.writeGrants(scope, SETLIST, PEOPLE);
        }
        await db.doc(`${path}/eventPublication/candidates`).delete();
        await db.doc(`${root}/songs/song-1`).set({ title: "Fallback", materialized: {
          title: "Published title", artist: "Published artist", notes: "PRIVATE", sections: ["PRIVATE"],
        } });
      });

      it("publishes server metadata once and unpublishes idempotently", async () => {
        await publish({ title: "Forged", artist: "Forged" });
        await publish();
        const expected = [{ id: "song-1", title: "Published title", artist: "Published artist" }];
        assert.deepEqual((await candidates()).data().candidates, expected);
        assert.deepEqual((await view()).suggestionCandidates, expected);
        await publish({ published: false });
        await publish({ published: false });
        assert.deepEqual((await view()).suggestionCandidates, []);
      });

      it("uses plain song metadata when materialized data is absent", async () => {
        await db.doc(`${root}/songs/song-1`).set({ title: "Plain title", artist: "Plain artist", notes: "PRIVATE" });
        await publish();
        assert.deepEqual((await view()).suggestionCandidates,
          [{ id: "song-1", title: "Plain title", artist: "Plain artist" }]);
      });

      if (scope.bandId) {
        it("allows band editors and admins to publish and see candidates", async () => {
          await db.doc(`bands/${BAND}`).update({ adminUids: ["admin"], editorUids: ["editor"] });
          await publish({}, "editor");
          assert.equal((await view(undefined, "editor")).suggestionCandidates.length, 1);
          await publish({ published: false }, "admin");
          assert.deepEqual((await view(undefined, "admin")).suggestionCandidates, []);
        });
      }

      it("allows 50 unique candidates, duplicates at capacity, and rejects the 51st", async () => {
        for (let i = 0; i < 51; i++) {
          await db.doc(`${root}/songs/cap-${i}`).set({ title: `Title ${i}`, artist: "Artist" });
        }
        for (let i = 0; i < 50; i++) await publish({ songId: `cap-${i}` });
        await publish({ songId: "cap-0" });
        await assert.rejects(publish({ songId: "cap-50" }), (e) => e.code === "failed-precondition");
        assert.equal((await candidates()).data().candidates.length, 50);
        await publish({ songId: "cap-0", published: false });
        await publish({ songId: "cap-50" });
      });

      it("rejects foreign or missing songs, malformed input and missing events", async () => {
        await db.doc("bands/foreign/songs/foreign-song").set({ title: "Private" });
        for (const songId of ["foreign-song", "nonexistent"]) {
          await assert.rejects(publish({ songId }), (e) => e.code === "not-found");
        }
        for (const extra of [{ songId: "a/b" }, { setlistId: "a/b" }, { published: "true" },
          { bandId: BAND, ownerUid: "candidate-owner" }, { ...scope, [scope.bandId ? "bandId" : "ownerUid"]: "a/b" }]) {
          await assert.rejects(publish(extra), (e) => e.code === "invalid-argument");
        }
        await assert.rejects(publish({ setlistId: "missing" }), (e) => e.code === "not-found");
      });

      it("denies ordinary members, area editors, guests, demos and anonymous callers", async () => {
        await db.doc(`bands/${BAND}`).update({ memberUids: ["member", "ordinary"] });
        await db.doc(`${path}/grants/area-editor`).set({ access: { runningOrder: "edit" }, canSuggest: true });
        for (const uid of ["ordinary", "area-editor", "roume"]) {
          await assert.rejects(publish({}, uid), (e) => e.code === "permission-denied");
        }
        await assert.rejects(publish({}, null), (e) => e.code === "unauthenticated");
        await assert.rejects(call(events.setEventSuggestionCandidate)({ data: args,
          auth: { uid: writer, token: { demo: true } } }), (e) => e.code === "failed-precondition");
      });

      it("projects candidates only to eligible guests and writers, dropping deleted songs", async () => {
        assert.deepEqual((await view()).suggestionCandidates, []);
        await publish();
        const tokenFor = async (participantId) => (await call(events.createEventShare)(req({ ...scope,
          setlistId: SETLIST, participantId }, writer))).token;
        const token = await tokenFor("p-couple");
        assert.deepEqual((await view({ token }, null)).suggestionCandidates,
          [{ id: "song-1", title: "Published title", artist: "Published artist" }]);
        assert.equal(Object.hasOwn(await view({ token: await tokenFor("p-eng") }, null), "suggestionCandidates"), false);
        await db.doc(`${path}/grants/limited`).set({ access: { stage: "edit" }, canSuggest: true });
        assert.equal(Object.hasOwn(await view(undefined, "limited"), "suggestionCandidates"), false);
        if (scope.bandId) {
          await db.doc(`bands/${BAND}`).update({ memberUids: ["member", "ordinary"] });
          assert.equal(Object.hasOwn(await view(undefined, "ordinary"), "suggestionCandidates"), false);
        }
        await db.doc(path).update({ items: [] });
        assert.equal(Object.hasOwn(await view({ token }, null), "suggestionCandidates"), false);
        assert.equal((await view()).suggestionCandidates.length, 1);
        await db.doc(`${root}/songs/song-1`).delete();
        assert.deepEqual((await view()).suggestionCandidates, []);
      });

      it("charges only published adds and rejects adds after unpublishing for token and uid guests", async () => {
        const { token, tokenId } = await call(events.createEventShare)(req({ ...scope,
          setlistId: SETLIST, participantId: "p-couple" }, writer));
        const { baseFingerprint } = (await view({ token }, null)).runningOrder;
        const proposal = { version: 1, kind: "add", baseFingerprint, songId: "song-1" };
        const submit = () => call(events.submitSuggestion)(req({ token, type: "add", proposal }));
        const rejected = async () => {
          await assert.rejects(submit(), (e) => e.code === "failed-precondition" && e.message === "Proposed song is unavailable.");
        };
        await rejected();
        assert.equal((await db.doc(`eventShares/${tokenId}`).get()).data().suggestionCount, 0);
        assert.equal((await db.collection(`${path}/suggestions`).get()).size, 0);
        await publish();
        await submit();
        await db.doc(`${path}/grants/suggester`).set({ access: { runningOrder: "view" }, canSuggest: true });
        await call(events.submitSuggestion)(req({ ...scope, setlistId: SETLIST, type: "add", proposal }, "suggester"));
        await publish({ published: false });
        await rejected();
        await assert.rejects(call(events.submitSuggestion)(req({ ...scope, setlistId: SETLIST, type: "add", proposal }, "suggester")), /Proposed song is unavailable/);
        assert.equal((await db.doc(`eventShares/${tokenId}`).get()).data().suggestionCount, 1);
        assert.equal((await db.collection(`${path}/suggestions`).get()).size, 2);
      });
    });
  }

  describe("personal event sharing", () => {
    const ownerUid = "personal-owner";
    const setlistId = "personal-event";
    const scope = { ownerUid };
    const path = `users/${ownerUid}/setlists/${setlistId}`;
    const data = { ...scope, setlistId };
    const create = () => call(events.createEventShare)(
      req({ ...data, participantId: "p-couple" }, ownerUid),
    );
    const denied = (promise, code) => assert.rejects(promise, (e) => e.code === code);

    beforeEach(async () => {
      await db.recursiveDelete(db.doc(`users/${ownerUid}`));
      for (const uid of ["personal-guest", "roume"]) {
        await db.doc(`users/${uid}/eventInvites/${setlistId}`).delete();
      }
      const bandSetlist = (await db.doc(`bands/${BAND}/setlists/${SETLIST}`).get()).data();
      await db.doc(path).set({ ...bandSetlist, name: "Personal event" });
      await db.doc(`users/${ownerUid}/songs/song-1`).set({
        title: "Personal song", artist: "Owner", ourKey: "PRIVATE KEY",
        ourBPM: 123, sections: [{ chordChart: "PRIVATE CHART" }],
      });
      await events.writeGrants(scope, setlistId, PEOPLE, { name: "Personal event" });
    });

    it("creates, claims, views and revokes a personal share with exclusive scope fields", async () => {
      const { token, tokenId } = await create();
      const share = (await db.doc(`eventShares/${tokenId}`).get()).data();
      assert.equal(share.ownerUid, ownerUid);
      assert.equal(share.bandId, undefined);
      const anonymous = await call(events.getEventView)(req({ token, bandId: BAND }));
      assert.equal(anonymous.ownerUid, ownerUid);
      assert.equal(anonymous.bandId, undefined);
      assert.equal(anonymous.songs[0].title, "Personal song");
      assert.equal(anonymous.runningOrder.ready, true);
      assert.equal(anonymous.runningOrder.baseFingerprint.length, 64);
      assert.deepEqual(anonymous.runningOrder.items.map((item) => item.id), ["i1"]);
      assert.equal(anonymous.stage, undefined);
      assert.equal(anonymous.rider, undefined);
      assert.ok(!JSON.stringify(anonymous).includes("PRIVATE"));
      const claimed = await call(events.claimEventShare)(req({ token }, "personal-guest"));
      assert.deepEqual(claimed, { ...data, access: PEOPLE[0].access });
      const grant = await db.doc(`${path}/grants/personal-guest`).get();
      assert.equal(grant.exists, true);
      const invite = (await db.doc(`users/personal-guest/eventInvites/${setlistId}`).get()).data();
      assert.equal(invite.ownerUid, ownerUid);
      assert.equal(invite.bandId, undefined);
      assert.equal(invite.name, "Personal event");
      const guest = await call(events.getEventView)(req(data, "personal-guest"));
      assert.deepEqual(guest, anonymous);
      const owner = await call(events.getEventView)(req(data, ownerUid));
      assert.equal(owner.songs[0].ourKey, "PRIVATE KEY");
      assert.ok(owner.stage);
      await call(events.revokeEventShare)(req({ ...data, tokenId }, ownerUid));
      await denied(call(events.getEventView)(req({ token })), "permission-denied");
    });

    it("uses personal suggestions for token and uid callers and resolves them as owner", async () => {
      const { token } = await create();
      await call(events.claimEventShare)(req({ token }, "personal-guest"));
      const { id } = await call(events.submitSuggestion)(req({ token, text: "Anonymous request" }));
      await call(events.submitSuggestion)(req({ ...data, text: "Signed in request" }, "personal-guest"));
      await call(events.resolveSuggestion)(req({ ...data, suggestionId: id, accept: true }, ownerUid));
      const view = await call(events.getEventView)(req({ token }, "personal-guest"));
      assert.equal(view.mySuggestions.length, 2);
      assert.equal(view.mySuggestions.find((s) => s.id === id).status, "accepted");
      assert.equal((await db.collection(`${path}/suggestions`).get()).size, 2);
      assert.equal((await db.collection(`bands/${BAND}/setlists/${SETLIST}/suggestions`).get()).size, 0);
    });

    it("denies non-owners management and strangers access", async () => {
      const { tokenId } = await create();
      await denied(call(events.createEventShare)(req({ ...data, participantId: "p-couple" }, "member")), "permission-denied");
      await denied(call(events.revokeEventShare)(req({ tokenId }, "member")), "permission-denied");
      await denied(call(events.resolveSuggestion)(req({ ...data, suggestionId: "x", accept: true }, "member")), "permission-denied");
      await denied(call(events.getEventView)(req(data, "member")), "permission-denied");
      await denied(call(events.submitSuggestion)(req({ ...data, text: "x" }, "member")), "permission-denied");
    });

    it("denies demo accounts on every personal write path", async () => {
      const { token, tokenId } = await create();
      const demo = (data, uid = ownerUid) => ({ data, auth: { uid, token: { demo: true } } });
      for (const [fn, args] of [
        [events.createEventShare, { ...data, participantId: "p-couple" }],
        [events.revokeEventShare, { tokenId }],
        [events.resolveSuggestion, { ...data, suggestionId: "x", accept: true }],
        [events.submitSuggestion, { ...data, text: "x" }],
        [events.claimEventShare, { token }],
      ]) {
        await denied(call(fn)(demo(args)), "failed-precondition");
      }
      await db.doc(`users/${ownerUid}`).set({ accessRole: "demo" });
      await denied(create(), "failed-precondition");
    });

    it("rejects both and neither scopes, including blank and non-string ids", async () => {
      for (const scope of [{ bandId: BAND, ownerUid }, {}, { bandId: " ", ownerUid: 12 }]) {
        for (const fn of [events.createEventShare, events.resolveSuggestion, events.getEventView, events.submitSuggestion]) {
          await denied(call(fn)(req({ ...scope, setlistId, participantId: "p-couple", suggestionId: "x", accept: true, text: "x" }, ownerUid)), "invalid-argument");
        }
      }
      const { token } = await call(events.createEventShare)(req({ ownerUid: ` ${ownerUid} `, setlistId, participantId: "p-couple" }, ownerUid));
      assert.equal((await call(events.getEventView)(req({ token }))).name, "Personal event");
    });

    it("cascades grants and invites through the personal setlist delete trigger", async () => {
      const before = await db.doc(path).get();
      await db.doc(path).delete();
      const after = await db.doc(path).get();
      await call(events.onUserSetlistWritten)({ before, after }, { params: { ownerUid, setlistId } });
      assert.equal((await db.collection(`${path}/grants`).get()).size, 0);
      assert.equal((await db.doc(`users/roume/eventInvites/${setlistId}`).get()).exists, false);
      assert.equal((await db.doc(`bands/${BAND}/setlists/${SETLIST}/grants/roume`).get()).exists, true);
    });

    it("refreshes personal invite snapshots and releases a guest's personal grant", async () => {
      await events.syncEventGrants(scope, setlistId, { before: { name: "Old" }, after: { name: "Moved" } });
      const invite = (await db.doc(`users/roume/eventInvites/${setlistId}`).get()).data();
      assert.equal(invite.name, "Moved");
      assert.equal(invite.ownerUid, ownerUid);
      await events.purgeUserGrants("roume");
      assert.equal((await db.doc(`${path}/grants/roume`).get()).exists, false);
    });
  });

  describe("listEventShares", () => {
    it("lists metadata for an authorized band writer", async () => {
      const { tokenId } = await call(events.createEventShare)(req({ bandId: BAND, setlistId: SETLIST, participantId: "p-couple" }, "member"));
      const result = await call(events.listEventShares)(req({ bandId: BAND, setlistId: SETLIST }, "member"));
      assert.equal(result.shares[0].tokenId, tokenId);
    });

    it("authorizes before lookup and validates scope ids and cursors", async () => {
      const list = (data, uid = "member") => call(events.listEventShares)(req(data, uid));
      for (const [data, uid, code] of [
        [{ bandId: BAND, setlistId: SETLIST }, "ordinary", "permission-denied"],
        [{ bandId: BAND, setlistId: SETLIST }, "stranger", "permission-denied"],
        [{ bandId: BAND, setlistId: SETLIST }, null, "unauthenticated"],
        [{ bandId: BAND, ownerUid: "x", setlistId: SETLIST }, "member", "invalid-argument"],
        [{ bandId: "bad/id", setlistId: SETLIST }, "member", "invalid-argument"],
        [{ bandId: BAND, setlistId: "bad/id" }, "member", "invalid-argument"],
        [{ bandId: BAND, setlistId: SETLIST, cursor: "bad/id" }, "member", "invalid-argument"],
        [{ bandId: BAND, setlistId: SETLIST }, "demo-user", "failed-precondition"],
      ]) {
        if (uid === "ordinary") await db.doc(`bands/${BAND}`).update({ memberUids: ["member", "ordinary"], adminUids: [], editorUids: [] });
        if (uid === "demo-user") await db.doc("users/demo-user").set({ accessRole: "demo" });
        await assert.rejects(list(data, uid), (error) => error.code === code);
        if (uid === "ordinary") await db.doc(`bands/${BAND}`).update({ adminUids: ["member"], editorUids: ["member"] });
      }
    });
    it("projects current roster metadata and walks bounded pages without writes", async () => {
      await db.doc(`bands/${BAND}/setlists/${SETLIST}`).update({ "eventKit.people": [
        { id: "listed", name: "Current name", role: "Current role", access: { stage: "edit", secretArea: "edit" } },
      ] });
      const col = db.collection("eventShares");
      const now = new Date().toISOString();
      const ids = Array.from({ length: 52 }, (_, i) => `list-${String(i).padStart(2, "0")}`);
      await Promise.all(ids.map((id, i) => col.doc(id).set({ tokenId: id, bandId: BAND, setlistId: SETLIST,
        participantId: i === 51 ? "missing" : "listed", createdBy: "private-uid", secretHash: "PRIVATE_HASH",
        arbitrary: "PRIVATE_FIELD", createdAt: now, expiresAt: i === 0 ? new Date(0).toISOString() : null,
        revoked: i === 1 })));
      const before = await col.get();
      const collected = [];
      let cursor;
      let page;
      do {
        page = await call(events.listEventShares)(req({ bandId: BAND, setlistId: SETLIST, ...(cursor ? { cursor } : {}) }, "member"));
        collected.push(...page.shares);
        cursor = page.nextCursor;
      } while (page.hasMore);
      assert.equal(collected.length, 52);
      assert.equal(new Set(collected.map((s) => s.tokenId)).size, 52);
      assert.equal(collected[0].state, "expired");
      assert.equal(collected[1].state, "revoked");
      assert.equal(collected[2].state, "active");
      assert.deepEqual(collected[2].access, { stage: "edit" });
      assert.equal(collected[51].state, "unavailable");
      assert.deepEqual(collected[51].access, {});
      assert.deepEqual(Object.keys(collected[2]).sort(), ["access", "createdAt", "expiresAt", "name", "participantId", "role", "state", "tokenId"]);
      assert.ok(!JSON.stringify(collected).includes("PRIVATE"));
      assert.equal(page.nextCursor, null);
      assert.equal((await col.get()).size, before.size);
      assert.ok((await col.doc(ids[0]).get()).updateTime.isEqual(before.docs.find((d) => d.id === ids[0]).updateTime));
    });

    it("lists personal owner scope and isolates other scope and event records", async () => {
      const ownerUid = "list-owner";
      const setlistId = "list-event";
      await db.doc(`users/${ownerUid}/setlists/${setlistId}`).set({ eventKit: { people: PEOPLE }, name: "personal" });
      await db.doc("eventShares/personal-listed").set({ tokenId: "personal-listed", ownerUid, setlistId, participantId: "p-couple" });
      await db.doc("eventShares/other-event").set({ bandId: BAND, setlistId: "elsewhere", participantId: "p-couple" });
      await db.doc("eventShares/other-scope").set({ ownerUid: "other-owner", setlistId: "not-this-event", participantId: "p-couple" });
      const result = await call(events.listEventShares)(req({ ownerUid, setlistId }, ownerUid));
      assert.deepEqual(result.shares.map((s) => s.tokenId), ["personal-listed"]);
      assert.equal(result.shares[0].name, "Ana & Rui");
    });
    it("revoking one listed link leaves another live and reports only its state change", async () => {
      const first = await call(events.createEventShare)(req({ bandId: BAND, setlistId: SETLIST, participantId: "p-couple" }, "member"));
      const second = await call(events.createEventShare)(req({ bandId: BAND, setlistId: SETLIST, participantId: "p-eng" }, "member"));
      await call(events.revokeEventShare)(req({ tokenId: first.tokenId }, "member"));
      await assert.rejects(call(events.getEventView)(req({ token: first.token })), (error) => error.code === "permission-denied");
      assert.equal((await call(events.getEventView)(req({ token: second.token }))).name, "Sputnik Bar");
      const listed = await call(events.listEventShares)(req({ bandId: BAND, setlistId: SETLIST }, "member"));
      assert.equal(listed.shares.find((share) => share.tokenId === first.tokenId).state, "revoked");
      assert.equal(listed.shares.find((share) => share.tokenId === second.tokenId).state, "active");
    });
  });

  describe("writeGrants", () => {
    const grantIds = async () => {
      const snap = await db
        .collection(`bands/${BAND}/setlists/${SETLIST}/grants`)
        .get();
      return snap.docs.map((d) => d.id).sort();
    };

    it("only grants people who are linked to an account", async () => {
      // The couple and the engineer have no uid yet — nothing to grant.
      assert.deepEqual(await grantIds(), ["roume"]);
    });

    it("writes the discovery index alongside the grant", async () => {
      const invite = await db
        .doc(`users/roume/eventInvites/${SETLIST}`)
        .get();
      assert.ok(invite.exists);
      assert.equal(invite.data().bandId, BAND);
    });

    it("grants an edit area once a person is linked", async () => {
      await events.writeGrants(
        { bandId: BAND },
        SETLIST,
        [{ ...PEOPLE[1], uid: "eng" }, PEOPLE[2]],
        {},
      );
      assert.deepEqual(await grantIds(), ["eng", "roume"]);
      const eng = await db
        .doc(`bands/${BAND}/setlists/${SETLIST}/grants/eng`)
        .get();
      assert.equal(eng.data().access.stage, "edit");
      assert.equal(eng.data().access.rider, "view");
    });

    it("revokes both records when someone leaves the roster", async () => {
      await events.writeGrants({ bandId: BAND }, SETLIST, [PEOPLE[0], PEOPLE[1]], {});
      assert.deepEqual(await grantIds(), []);
      const invite = await db.doc(`users/roume/eventInvites/${SETLIST}`).get();
      assert.equal(invite.exists, false);
    });

    it("ignores an invented area or level", async () => {
      await events.writeGrants(
        { bandId: BAND },
        SETLIST,
        [{ id: "x", uid: "sneaky", access: { wholeBand: "edit", stage: "owner" } }],
        {},
      );
      assert.deepEqual(await grantIds(), []);
    });
  });

  describe("syncEventGrants (the setlist trigger)", () => {
    const grantIds = async () => {
      const snap = await db
        .collection(`bands/${BAND}/setlists/${SETLIST}/grants`)
        .get();
      return snap.docs.map((d) => d.id).sort();
    };

    it("cascade-deletes grants and invites when the setlist goes", async () => {
      // Firestore does NOT cascade. Without this, a deleted event leaves its
      // grants subcollection and every user's invite behind: the guest keeps
      // seeing a phantom event, and an orphaned grant would silently authorise
      // anyone if the setlist id were ever reused.
      assert.deepEqual(await grantIds(), ["roume"]);
      const before = await db.doc(`bands/${BAND}/setlists/${SETLIST}`).get();

      await db.doc(`bands/${BAND}/setlists/${SETLIST}`).delete();
      const out = await events.syncEventGrants({ bandId: BAND }, SETLIST, {
        before: before.data(),
        after: null,
      });

      assert.equal(out.deleted, 1);
      assert.deepEqual(await grantIds(), []);
      const invite = await db.doc(`users/roume/eventInvites/${SETLIST}`).get();
      assert.equal(invite.exists, false);
    });

    it("refreshes the invite snapshot when the gig moves", async () => {
      // The invite carries name/date/venue so a guest's list needs no access to
      // the band's collection — which means it goes stale the moment the band
      // moves the gig, and a guest reading yesterday's call time is the worst
      // kind of stale.
      const before = (await db.doc(`bands/${BAND}/setlists/${SETLIST}`).get()).data();
      const after = {
        ...before,
        name: "Sputnik Bar — moved",
        eventDateTime: "2026-09-01T20:00:00.000Z",
        eventLocation: "Another venue",
      };
      const out = await events.syncEventGrants({ bandId: BAND }, SETLIST, { before, after });

      assert.equal(out.refreshed, 1);
      const invite = await db.doc(`users/roume/eventInvites/${SETLIST}`).get();
      assert.equal(invite.data().name, "Sputnik Bar — moved");
      assert.equal(invite.data().eventDateTime, "2026-09-01T20:00:00.000Z");
      assert.equal(invite.data().eventLocation, "Another venue");
      // The grant itself is untouched — only the display snapshot moved.
      assert.deepEqual(await grantIds(), ["roume"]);
    });

    it("does nothing when the event details did not change", async () => {
      const before = (await db.doc(`bands/${BAND}/setlists/${SETLIST}`).get()).data();
      const out = await events.syncEventGrants({ bandId: BAND }, SETLIST, {
        before,
        after: { ...before, items: [] },
      });
      assert.deepEqual(out, { deleted: 0, refreshed: 0 });
    });

    it("is a no-op for an event nobody is a guest on", async () => {
      const out = await events.syncEventGrants({ bandId: BAND }, "no-such-setlist", {
        before: null,
        after: null,
      });
      assert.deepEqual(out, { deleted: 0, refreshed: 0 });
    });
  });

  for (const scope of [{ bandId: BAND }, { ownerUid: "roster-owner" }]) {
    describe(`roster reconciliation (${scope.bandId ? "band" : "personal"})`, () => {
      const path = scope.bandId
        ? `bands/${BAND}/setlists/${SETLIST}`
        : `users/${scope.ownerUid}/setlists/${SETLIST}`;
      const guest = { id: "p-eng", uid: "eng", access: { stage: "edit", rider: "view" } };
      let before;
      beforeEach(async () => {
        await db.recursiveDelete(db.doc(path));
        before = { name: "Gig", eventKit: { people: [guest], stage: {}, rider: [] } };
        await db.doc(path).set(before);
        await events.writeGrants(scope, SETLIST, [guest], before);
      });
      const trigger = async (after) => {
        const old = await db.doc(path).get();
        await db.doc(path).set(after);
        const next = await db.doc(path).get();
        await call(scope.bandId ? events.onBandSetlistWritten : events.onUserSetlistWritten)(
          { before: old, after: next }, { params: { ...scope, setlistId: SETLIST } },
        );
      };

      it("removes both grant and invite when the guest is removed", async () => {
        await trigger({ ...before, eventKit: { ...before.eventKit, people: [] } });
        assert.equal((await db.doc(`${path}/grants/eng`).get()).exists, false);
        assert.equal((await db.doc(`users/eng/eventInvites/${SETLIST}`).get()).exists, false);
      });

      it("drops an area from getEventView when access is lowered, and is repeatable", async () => {
        assert.ok((await call(events.getEventView)(req({ ...scope, setlistId: SETLIST }, "eng"))).rider);
        const after = { ...before, eventKit: { ...before.eventKit,
          people: [{ ...guest, access: { stage: "view" } }],
        } };
        await trigger(after);
        // A claim writes grants before this same trigger runs: replay is safe.
        await events.syncEventGrants(scope, SETLIST, { before, after });
        const view = await call(events.getEventView)(req({ ...scope, setlistId: SETLIST }, "eng"));
        assert.equal(view.rider, undefined);
        assert.equal(view.viewer.access.stage, "view");
        assert.deepEqual((await db.doc(path).get()).data(), after);
      });

      it("does not write when sanitized uid/access are unchanged", async () => {
        const grant = await db.doc(`${path}/grants/eng`).get();
        const invite = await db.doc(`users/eng/eventInvites/${SETLIST}`).get();
        const after = { ...before, eventKit: { ...before.eventKit, people: [{
          ...guest, name: "New display name", access: { rider: "view", stage: "edit", unknown: "edit" },
        }] } };
        await trigger(after);
        assert.ok((await db.doc(`${path}/grants/eng`).get()).updateTime.isEqual(grant.updateTime));
        assert.ok((await db.doc(`users/eng/eventInvites/${SETLIST}`).get()).updateTime.isEqual(invite.updateTime));
      });

      it("preserves grants when an old app omits the event kit", async () => {
        await trigger({ name: "Gig", items: [] });
        assert.equal((await db.doc(`${path}/grants/eng`).get()).exists, true);
        assert.equal((await db.doc(`users/eng/eventInvites/${SETLIST}`).get()).exists, true);
      });

      it("creates a grant when the first guest is added", async () => {
        await db.doc(`${path}/grants/eng`).delete();
        await events.syncEventGrants(scope, SETLIST, {
          before: { ...before, eventKit: { people: [] } }, after: before,
        });
        assert.equal((await db.doc(`${path}/grants/eng`).get()).exists, true);
      });
    });
  }

  describe("lifecycle cleanup", () => {
    it("purges every grant in a band when the band is deleted", async () => {
      // Firestore cascades at no level: deleting a band leaves its setlists,
      // which leave their grants, which leave everyone's invites pointing at a
      // band that no longer exists.
      const removed = await events.purgeBandGrants(BAND);
      assert.equal(removed, 1);
      const grants = await db
        .collection(`bands/${BAND}/setlists/${SETLIST}/grants`)
        .get();
      assert.equal(grants.size, 0);
      const invite = await db.doc(`users/roume/eventInvites/${SETLIST}`).get();
      assert.equal(invite.exists, false);
    });

    it("releases grants held in OTHER people's bands on account deletion", async () => {
      // These live outside the user's own document tree, so deleteAccount's
      // recursiveDelete(users/{uid}) never reaches them.
      const purged = await events.purgeUserGrants("roume");
      assert.equal(purged, 1);
      const grant = await db
        .doc(`bands/${BAND}/setlists/${SETLIST}/grants/roume`)
        .get();
      assert.equal(grant.exists, false);
      const invite = await db.doc(`users/roume/eventInvites/${SETLIST}`).get();
      assert.equal(invite.exists, false);
    });

    it("is a no-op for someone holding no grants", async () => {
      assert.equal(await events.purgeUserGrants("nobody"), 0);
    });
  });

  describe("the demo account", () => {
    const demoReq = (data) => ({ data, auth: { uid: "demo", token: { demo: true } } });

    it("cannot claim a share", async () => {
      const token = await shareFor("p-eng");
      await assert.rejects(
        call(events.claimEventShare)(demoReq({ token })),
        /demo account cannot/,
      );
    });

    it("cannot suggest changes", async () => {
      const token = await shareFor("p-couple");
      await assert.rejects(
        call(events.submitSuggestion)(demoReq({ token, type: "note", text: "x" })),
        /demo account cannot/,
      );
    });

    it("cannot mint share links", async () => {
      await assert.rejects(
        call(events.createEventShare)(
          demoReq({ bandId: BAND, setlistId: SETLIST, participantId: "p-eng" }),
        ),
        /demo account cannot/,
      );
    });

    it("still lets an anonymous token holder suggest", async () => {
      // The demo guard keys on the caller's uid, so it must not catch the
      // no-account path the whole feature depends on.
      const token = await shareFor("p-couple");
      await call(events.submitSuggestion)(
        req({ token, type: "note", text: "from a link" }),
      );
      const snap = await db
        .collection(`bands/${BAND}/setlists/${SETLIST}/suggestions`)
        .get();
      assert.equal(snap.size, 1);
    });
  });

  describe("getEventView scoping", () => {
    it("exposes authorized running-order identities and v1 fingerprint only", async () => {
      const items = [
        { id: "same-song-a", songId: "song-1", type: "song", performerIds: ["p-couple"], opaque: "private" },
        { id: "pause", type: "break", breakType: "intermission", breakLabel: "Pause" },
        { id: "same-song-b", songId: "song-1", type: "song" },
      ];
      await db.doc(`bands/${BAND}/setlists/${SETLIST}`).update({ items });
      const fingerprint = require("node:crypto").createHash("sha256").update(JSON.stringify([
        ["same-song-a", "song", "song-1", null, null, null, ["p-couple"]],
        ["pause", "break", "", null, "intermission", "Pause", []],
        ["same-song-b", "song", "song-1", null, null, null, []],
      ])).digest("hex");
      const token = await shareFor("p-couple");
      const view = await call(events.getEventView)(req({ token }));
      assert.deepEqual(view.runningOrder, { ready: true, items: items.map((item) => ({
        id: item.id, songId: item.songId || null, type: item.type,
        tuningPresetId: null, breakType: item.breakType || null,
        breakLabel: item.breakLabel || null, performerIds: item.performerIds || [],
      })), baseFingerprint: fingerprint });
      assert.deepEqual(view.items.map((item) => item.id), items.map((item) => item.id));
      assert.deepEqual(view.items.map((item) => item.songId), ["song-1", null, "song-1"]);
      assert.ok(!JSON.stringify(view).includes("opaque"));
      assert.ok(!JSON.stringify(view).includes(token));
      const memberView = await call(events.getEventView)(req({ bandId: BAND, setlistId: SETLIST }, "member"));
      assert.deepEqual(memberView.runningOrder, view.runningOrder);
      await call(events.claimEventShare)(req({ token }, "eng"));
      const guestView = await call(events.getEventView)(req({ bandId: BAND, setlistId: SETLIST }, "eng"));
      assert.deepEqual(guestView.runningOrder, view.runningOrder);
      await seed(PEOPLE.map((p) => p.id === "p-eng" ? { ...p, access: { stage: "view" } } : p));
      const denied = await call(events.getEventView)(req({ token: await shareFor("p-eng") }));
      for (const key of ["runningOrder", "items", "songs"]) assert.equal(denied[key], undefined);
    });

    it("marks legacy and ambiguous running orders unready without inventing identities", async () => {
      const token = await shareFor("p-couple");
      for (const items of [[], [{ songId: "song-1" }], [{ id: "dup", songId: "song-1" }, { id: "dup", songId: "song-1" }], [null]]) {
        await db.doc(`bands/${BAND}/setlists/${SETLIST}`).update({ items });
        const view = await call(events.getEventView)(req({ token }));
        assert.deepEqual(view.runningOrder, { ready: false, items: null, baseFingerprint: null });
        assert.deepEqual((await db.doc(`bands/${BAND}/setlists/${SETLIST}`).get()).data().items, items);
      }
      await db.doc(`bands/${BAND}/setlists/${SETLIST}`).update({ items: admin.firestore.FieldValue.delete() });
      const legacy = await call(events.getEventView)(req({ token }));
      assert.deepEqual(legacy.runningOrder, { ready: false, items: null, baseFingerprint: null });
    });

    it("gives a client titles but NO chart data at all", async () => {
      const view = await call(events.getEventView)(
        req({ token: await shareFor("p-couple") }),
      );
      assert.equal(view.songs.length, 1);
      assert.equal(view.songs[0].title, "visto");
      // The assertions that matter: absent, not hidden.
      assert.ok(!("ourKey" in view.songs[0]));
      assert.ok(!("ourBPM" in view.songs[0]));
      assert.ok(!("sections" in view.songs[0]));
      assert.ok(!("stage" in view));
      assert.ok(!("rider" in view));
      // Nothing chart-shaped anywhere in the serialized payload.
      const wire = JSON.stringify(view);
      assert.ok(!wire.includes("Ya no necesito"));
      assert.ok(!wire.includes("Bm"));
    });

    it("gives a performing guest the charts", async () => {
      const view = await call(events.getEventView)(
        req({ token: await shareFor("p-roume") }),
      );
      assert.equal(view.songs[0].ourKey, "Bm");
      assert.equal(view.songs[0].sections.length, 1);
      // …but still not the stage plot, which is not their business.
      assert.ok(!("stage" in view));
    });

    it("gives a sound engineer the stage and rider but no lyrics", async () => {
      const view = await call(events.getEventView)(
        req({ token: await shareFor("p-eng") }),
      );
      assert.deepEqual(Object.keys(view.stage), ["back-left"]);
      assert.equal(view.rider.length, 1);
      assert.ok(!("sections" in view.songs[0]));
      assert.equal(view.viewer.access.stage, "edit");
    });

    it("never exposes another participant's uid or grant", async () => {
      const view = await call(events.getEventView)(
        req({ token: await shareFor("p-couple") }),
      );
      // Names and roles are the point of the roster — "who else is on this
      // gig". Account ids and grants are nobody else's business.
      for (const person of view.people) {
        assert.deepEqual(
          Object.keys(person).sort(),
          ["id", "name", "role"],
          JSON.stringify(person),
        );
      }
      const roume = view.people.find((p) => p.id === "p-roume");
      assert.equal(roume.name, "Roumé");
      assert.equal(roume.uid, undefined);
    });

    it("gives a band member everything", async () => {
      const view = await call(events.getEventView)(
        req({ bandId: BAND, setlistId: SETLIST }, "member"),
      );
      assert.ok(view.stage);
      assert.ok(view.rider);
      assert.equal(view.songs[0].ourBPM, 96);
    });

    it("refuses a signed-in stranger", async () => {
      await assert.rejects(
        call(events.getEventView)(
          req({ bandId: BAND, setlistId: SETLIST }, "stranger"),
        ),
        /do not have access/,
      );
    });

    it("refuses an anonymous caller with no token", async () => {
      await assert.rejects(
        call(events.getEventView)(req({ bandId: BAND, setlistId: SETLIST })),
        /Sign in or use a share link/,
      );
    });
  });

  // E5: the song fan-out used to be one get() per song. Parallel, but uncapped
  // and N round trips — a 40-song event was 40 reads where one getAll does it.
  describe("getEventView song fan-out", () => {
    const manySongs = async (n) => {
      const items = [];
      for (let i = 0; i < n; i += 1) {
        const id = `bulk-${i}`;
        await db
          .doc(`bands/${BAND}/songs/${id}`)
          .set({ id, title: `song ${i}`, artist: "Flor Damico" });
        items.push({ id: `bi-${i}`, songId: id, type: "song" });
      }
      await db.doc(`bands/${BAND}/setlists/${SETLIST}`).update({ items });
      return items;
    };

    it("reads a ten-song event in ONE fan-out call", async () => {
      await manySongs(10);
      // The SDK routes every DocumentReference.get() through db.getAll, so
      // counting getAll alone also counts the setlist and band reads. Count
      // only the calls that carry song refs, and how many refs each carried:
      // one call with ten refs is the fix, ten calls with one ref is the bug.
      const realGetAll = db.getAll.bind(db);
      const songBatches = [];
      db.getAll = (...refs) => {
        const songRefs = refs.filter((r) => r.path.includes("/songs/"));
        if (songRefs.length) songBatches.push(songRefs.length);
        return realGetAll(...refs);
      };
      try {
        const token = await shareFor("p-roume");
        const view = await call(events.getEventView)(req({ token }));
        assert.equal(view.songs.length, 10);
        assert.deepEqual(
          songBatches,
          [10],
          `expected one batch of 10, got ${JSON.stringify(songBatches)}`,
        );
      } finally {
        db.getAll = realGetAll;
      }
    });

    it("keeps the running order's song order", async () => {
      // getAll returns snapshots in the order the refs were passed, and the
      // running order is the whole point of the payload — a set played out of
      // order is worse than no set at all.
      await manySongs(5);
      const token = await shareFor("p-roume");
      const view = await call(events.getEventView)(req({ token }));
      assert.deepEqual(
        view.songs.map((s) => s.title),
        ["song 0", "song 1", "song 2", "song 3", "song 4"],
      );
    });

    it("says so when it truncates, instead of silently shortening the set", async () => {
      // A silently short running order reads as "the band only has N songs" to
      // whoever is holding it at the venue, so the payload has to admit it.
      const cap = events.MAX_EVENT_SONGS;
      const items = [];
      for (let i = 0; i < cap + 2; i += 1) {
        items.push({ id: `i-${i}`, songId: "song-1", type: "song" });
      }
      await db.doc(`bands/${BAND}/setlists/${SETLIST}`).update({ items });

      const token = await shareFor("p-roume");
      const view = await call(events.getEventView)(req({ token }));
      assert.equal(view.songsTruncated, true);
      assert.equal(view.items.length, cap + 2, "the running order is complete");
    });

    it("does not claim truncation when the whole event fits", async () => {
      await manySongs(3);
      const token = await shareFor("p-roume");
      const view = await call(events.getEventView)(req({ token }));
      assert.equal(view.songsTruncated, false);
      assert.equal(view.songs.length, 3);
    });

    it("survives an item pointing at a song that no longer exists", async () => {
      await db.doc(`bands/${BAND}/setlists/${SETLIST}`).update({
        items: [
          { id: "i1", songId: "song-1", type: "song" },
          { id: "i2", songId: "deleted-song", type: "song" },
        ],
      });
      const token = await shareFor("p-roume");
      const view = await call(events.getEventView)(req({ token }));
      assert.equal(view.songs.length, 1);
      assert.equal(view.songs[0].id, "song-1");
    });

    it("makes no fan-out call at all for an event with no songs", async () => {
      await db
        .doc(`bands/${BAND}/setlists/${SETLIST}`)
        .update({ items: [{ id: "b1", type: "break", breakLabel: "Set 2" }] });
      const token = await shareFor("p-roume");
      const view = await call(events.getEventView)(req({ token }));
      assert.deepEqual(view.songs, []);
      assert.equal(view.items.length, 1);
    });
  });

  describe("tokens", () => {
    it("rejects a garbled or unknown token", async () => {
      for (const token of ["nonsense", "a.b", `${"x".repeat(36)}.deadbeef`]) {
        await assert.rejects(
          call(events.getEventView)(req({ token })),
          /Invalid link|no longer valid/,
        );
      }
    });

    it("rejects the right tokenId with the wrong secret", async () => {
      const token = await shareFor("p-couple");
      const [tokenId] = token.split(".");
      await assert.rejects(
        call(events.getEventView)(req({ token: `${tokenId}.wrongsecret` })),
        /no longer valid/,
      );
    });

    it("stores only a hash, never the secret", async () => {
      const token = await shareFor("p-couple");
      const [tokenId, secret] = token.split(".");
      const doc = await db.collection("eventShares").doc(tokenId).get();
      const wire = JSON.stringify(doc.data());
      assert.ok(!wire.includes(secret), "raw secret was persisted");
      assert.ok(doc.data().secretHash);
    });

    it("stops working once revoked", async () => {
      const token = await shareFor("p-couple");
      const [tokenId] = token.split(".");
      await call(events.revokeEventShare)(req({ tokenId }, "member"));
      await assert.rejects(
        call(events.getEventView)(req({ token })),
        /no longer valid/,
      );
    });

    // E2: a capability URL that never expires keeps working for anyone who
    // ever saw the link — a screenshot, a chat log, a browser history.
    it("stamps an expiry on every new link", async () => {
      const token = await shareFor("p-couple");
      const [tokenId] = token.split(".");
      const doc = await db.collection("eventShares").doc(tokenId).get();
      const expiresAt = Date.parse(doc.data().expiresAt);
      assert.ok(expiresAt > Date.now(), "expiresAt is not in the future");
      const days = (expiresAt - Date.now()) / 86400000;
      assert.ok(days > 89 && days < 91, `expected ~90 days, got ${days}`);
    });

    it("stops working once expired", async () => {
      const token = await shareFor("p-couple");
      const [tokenId] = token.split(".");
      await db
        .collection("eventShares")
        .doc(tokenId)
        .update({ expiresAt: new Date(Date.now() - 1000).toISOString() });
      await assert.rejects(
        call(events.getEventView)(req({ token })),
        /no longer valid/,
      );
    });

    // The endpoint must not become an oracle: if an expired token failed
    // differently from a made-up one, the difference tells an attacker which
    // tokenIds are real.
    it("fails an expired link and a garbage link identically", async () => {
      const token = await shareFor("p-couple");
      const [tokenId] = token.split(".");
      await db
        .collection("eventShares")
        .doc(tokenId)
        .update({ expiresAt: new Date(Date.now() - 1000).toISOString() });

      const shape = async (t) => {
        try {
          await call(events.getEventView)(req({ token: t }));
          return "resolved";
        } catch (e) {
          return `${e.code}|${e.message}`;
        }
      };
      const expired = await shape(token);
      const garbage = await shape(`${"x".repeat(36)}.deadbeef`);
      assert.notEqual(expired, "resolved");
      assert.equal(expired, garbage);
    });

    // A link minted before expiry existed must not die on deploy day.
    it("keeps working when the document predates expiry", async () => {
      const token = await shareFor("p-couple");
      const [tokenId] = token.split(".");
      await db
        .collection("eventShares")
        .doc(tokenId)
        .update({ expiresAt: admin.firestore.FieldValue.delete() });
      const view = await call(events.getEventView)(req({ token }));
      assert.equal(view.name, "Sputnik Bar");
    });

    it("cannot be created by a non-member", async () => {
      await assert.rejects(
        call(events.createEventShare)(
          req(
            { bandId: BAND, setlistId: SETLIST, participantId: "p-couple" },
            "stranger",
          ),
        ),
        /Only band admins and editors/,
      );
    });
  });

  describe("claiming a link", () => {
    it("links the account and writes the grant + invite", async () => {
      const token = await shareFor("p-eng");
      const out = await call(events.claimEventShare)(req({ token }, "eng"));
      assert.equal(out.access.stage, "edit");

      const grant = await db
        .doc(`bands/${BAND}/setlists/${SETLIST}/grants/eng`)
        .get();
      assert.ok(grant.exists);
      assert.equal(grant.data().access.stage, "edit");
      assert.equal(grant.data().access.rider, "view");
      assert.equal(grant.data().participantId, "p-eng");

      // Discoverable from the guest's own side.
      const invite = await db.doc(`users/eng/eventInvites/${SETLIST}`).get();
      assert.ok(invite.exists);
      assert.equal(invite.data().bandId, BAND);

      // Claiming the engineer's link must not grant anyone else anything.
      const all = await db
        .collection(`bands/${BAND}/setlists/${SETLIST}/grants`)
        .get();
      assert.deepEqual(all.docs.map((d) => d.id).sort(), ["eng", "roume"]);
    });

    it("refuses a second person claiming the same link", async () => {
      const token = await shareFor("p-eng");
      await call(events.claimEventShare)(req({ token }, "eng"));
      await assert.rejects(
        call(events.claimEventShare)(req({ token }, "impostor")),
        /already been claimed/,
      );
    });

    it("lets exactly one of two simultaneous claimers win", async () => {
      const token = await shareFor("p-eng");
      const results = await Promise.allSettled([
        call(events.claimEventShare)(req({ token }, "a")),
        call(events.claimEventShare)(req({ token }, "b")),
      ]);
      assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
    });

    it("is idempotent for the same person", async () => {
      const token = await shareFor("p-eng");
      await call(events.claimEventShare)(req({ token }, "eng"));
      await call(events.claimEventShare)(req({ token }, "eng"));
      const all = await db
        .collection(`bands/${BAND}/setlists/${SETLIST}/grants`)
        .get();
      assert.deepEqual(all.docs.map((d) => d.id).sort(), ["eng", "roume"]);
    });

    it("requires an account", async () => {
      const token = await shareFor("p-eng");
      await assert.rejects(
        call(events.claimEventShare)(req({ token })),
        /authenticated/,
      );
    });
  });

  describe("suggestions", () => {
    it("persists validated typed proposals without charging rejected submissions", async () => {
      const path = `bands/${BAND}/setlists/${SETLIST}`;
      const items = [{ id: "one", songId: "song-1", type: "song" }];
      await db.doc(path).set({ items }, { merge: true });
      const baseFingerprint = require("node:crypto").createHash("sha256")
        .update(JSON.stringify([["one", "song", "song-1", null, null, null, []]])).digest("hex");
      const token = await shareFor("p-couple");
      const tokenId = token.split(".")[0];
      const proposal = { version: 1, kind: "remove", baseFingerprint, itemId: "one" };
      const submit = (extra) => call(events.submitSuggestion)(req({ token, type: "remove", proposal, ...extra }));
      for (const extra of [
        { proposal: { ...proposal, extra: true } },
        { proposal: { ...proposal, kind: "add" } },
        { proposal: { ...proposal, itemId: "../one" } },
        { proposal: { ...proposal, baseFingerprint: "0".repeat(64) } },
        { proposal: null },
        { proposal: { ...proposal, itemId: "missing" } },
        { type: "add", proposal: { version: 1, kind: "add", baseFingerprint, songId: "missing" } },
        { type: "add", proposal: { version: 1, kind: "add", baseFingerprint, songId: "song-1", beforeItemId: "missing" } },
        { type: "reorder", proposal: { version: 1, kind: "reorder", baseFingerprint, itemIds: [] } },
        { type: "reorder", proposal: { version: 1, kind: "reorder", baseFingerprint, itemIds: ["one", "one"] } },
      ]) {
        await assert.rejects(submit(extra));
        assert.equal((await db.doc(`eventShares/${tokenId}`).get()).data().suggestionCount, 0);
        assert.equal((await db.collection(`${path}/suggestions`).get()).size, 0);
      }
      await assert.rejects(call(events.submitSuggestion)(req({ token, type: "note", text: "note", proposal })));
      const { id } = await submit({});
      assert.deepEqual((await db.doc(`${path}/suggestions/${id}`).get()).data().proposal, proposal);
      assert.equal((await db.doc(`eventShares/${tokenId}`).get()).data().suggestionCount, 1);
      await call(events.setEventSuggestionCandidate)(req({ bandId: BAND, setlistId: SETLIST, songId: "song-1", published: true }, "member"));
      for (const typed of [
        { version: 1, kind: "add", baseFingerprint, songId: "song-1", beforeItemId: "one" },
        { version: 1, kind: "add", baseFingerprint, songId: "song-1" },
        { version: 1, kind: "reorder", baseFingerprint, itemIds: ["one"] },
      ]) {
        const saved = await submit({ type: typed.kind, proposal: typed });
        assert.deepEqual((await db.doc(`${path}/suggestions/${saved.id}`).get()).data().proposal, typed);
      }
      assert.deepEqual((await db.doc(path).get()).data().items, items, "submission must not execute proposals");

      const ownerUid = "personal-owner";
      const personalPath = `users/${ownerUid}/setlists/personal-event`;
      await db.doc(personalPath).set({ items }, { merge: true });
      const personalToken = await call(events.createEventShare)(req({ ownerUid, setlistId: "personal-event", participantId: "p-couple" }, ownerUid));
      const personalProposal = { ...proposal, baseFingerprint };
      const personalResult = await call(events.submitSuggestion)(req({ token: personalToken.token, type: "remove", proposal: personalProposal }));
      assert.deepEqual((await db.doc(`${personalPath}/suggestions/${personalResult.id}`).get()).data().proposal, personalProposal);
    });

    it("typed remove deletes exactly one duplicate song reference and preserves break metadata", async () => {
      const path = `bands/${BAND}/setlists/${SETLIST}`;
      const items = [
        { id: "song-a", type: "song", songId: "song-1", performerIds: ["p"], opaque: { keep: true } },
        { id: "break", type: "break", breakType: "intermission", breakLabel: "Keep this" },
        { id: "song-b", type: "song", songId: "song-1" },
      ];
      await db.doc(path).update({ items, songIds: ["song-1", "song-1"] });
      const fingerprint = require("node:crypto").createHash("sha256").update(JSON.stringify([
        ["song-a", "song", "song-1", null, null, null, ["p"]],
        ["break", "break", "", null, "intermission", "Keep this", []],
        ["song-b", "song", "song-1", null, null, null, []],
      ])).digest("hex");
      const suggestionId = "typed-remove";
      await db.doc(`${path}/suggestions/${suggestionId}`).set({
        id: suggestionId, type: "remove", proposal: { version: 1, kind: "remove", baseFingerprint: fingerprint, itemId: "song-a" }, status: "open",
      });
      await call(events.resolveSuggestion)(req({ bandId: BAND, setlistId: SETLIST, suggestionId, accept: true }, "member"));
      const saved = (await db.doc(path).get()).data();
      assert.deepEqual(saved.items, [items[1], items[2]]);
      assert.deepEqual(saved.songIds, ["song-1"]);
      const resolved = (await db.doc(`${path}/suggestions/${suggestionId}`).get()).data();
      assert.equal(resolved.status, "accepted");
      assert.equal(Object.hasOwn(resolved, "items"), false, "suggestions must not duplicate private running-order items");
      assert.equal(Object.hasOwn(resolved, "songIds"), false);
    });

    it("adds a scoped existing song and reorders exact item identities", async () => {
      const path = `bands/${BAND}/setlists/${SETLIST}`;
      const items = [
        { id: "first", songId: "song-1", type: "song", extra: "kept" },
        { id: "pause", type: "break", breakLabel: "Pause" },
      ];
      await db.doc(path).update({ items, songIds: ["song-1"] });
      const fingerprint = require("node:crypto").createHash("sha256").update(JSON.stringify([
        ["first", "song", "song-1", null, null, null, []], ["pause", "break", "", null, null, "Pause", []],
      ])).digest("hex");
      const col = db.collection(`${path}/suggestions`);
      await col.doc("add").set({ type: "add", status: "open", proposal: { version: 1, kind: "add", baseFingerprint: fingerprint, songId: "song-1", beforeItemId: "pause" } });
      await call(events.resolveSuggestion)(req({ bandId: BAND, setlistId: SETLIST, suggestionId: "add", accept: true }, "member"));
      let saved = (await db.doc(path).get()).data();
      assert.equal(saved.items.length, 3);
      assert.deepEqual(saved.items[0], items[0]);
      assert.deepEqual(saved.items[2], items[1]);
      assert.deepEqual(saved.songIds, ["song-1", "song-1"]);
      const ordered = [saved.items[2].id, saved.items[1].id, saved.items[0].id];
      const reorderFingerprint = require("node:crypto").createHash("sha256").update(JSON.stringify([
        [saved.items[0].id, "song", "song-1", null, null, null, []],
        [saved.items[1].id, "song", "song-1", null, null, null, []],
        [saved.items[2].id, "break", "", null, null, "Pause", []],
      ])).digest("hex");
      await col.doc("reorder").set({ type: "reorder", status: "open", proposal: { version: 1, kind: "reorder", baseFingerprint: reorderFingerprint, itemIds: ordered } });
      await call(events.resolveSuggestion)(req({ bandId: BAND, setlistId: SETLIST, suggestionId: "reorder", accept: true }, "member"));
      saved = (await db.doc(path).get()).data();
      assert.deepEqual(saved.items.map((item) => item.id), ordered);
      assert.equal(saved.items.find((item) => item.id === "first").extra, "kept");
    });

    it("fails closed on stale, malformed, legacy, replayed, and unauthorized resolutions", async () => {
      const path = `bands/${BAND}/setlists/${SETLIST}`;
      const items = [{ id: "one", songId: "song-1", type: "song" }];
      await db.doc(path).update({ items, songIds: ["song-1"] });
      const fingerprint = require("node:crypto").createHash("sha256").update(JSON.stringify([
        ["one", "song", "song-1", null, null, null, []],
      ])).digest("hex");
      const col = db.collection(`${path}/suggestions`);
      const seedTyped = (id, proposal) => col.doc(id).set({ type: "remove", status: "open", proposal });
      await seedTyped("stale", { version: 1, kind: "remove", baseFingerprint: "0".repeat(64), itemId: "one" });
      await seedTyped("bad", { version: 1, kind: "remove", baseFingerprint: fingerprint, itemId: "../one" });
      await col.doc("legacy").set({ type: "note", status: "open" });
      await seedTyped("valid", { version: 1, kind: "remove", baseFingerprint: fingerprint, itemId: "one" });
      const resolve = (id, accept = true, uid = "member") => call(events.resolveSuggestion)(req({ bandId: BAND, setlistId: SETLIST, suggestionId: id, accept }, uid));
      for (const [id, code, uid] of [["stale", "failed-precondition", "member"], ["bad", "failed-precondition", "member"], ["missing", "not-found", "member"], ["valid", "permission-denied", "stranger"]]) {
        await assert.rejects(resolve(id, true, uid), (error) => error.code === code);
      }
      await resolve("legacy", true);
      assert.equal((await col.doc("legacy").get()).data().status, "accepted");
      await resolve("valid", false);
      await assert.rejects(resolve("valid"), (error) => error.code === "failed-precondition");
      const saved = (await db.doc(path).get()).data();
      assert.deepEqual(saved.items, items);
      assert.deepEqual(saved.songIds, ["song-1"]);
      assert.equal((await col.doc("valid").get()).data().status, "declined");
      assert.equal((await col.doc("stale").get()).data().status, "open");
    });

    it("rejects missing item identities and songIds-only legacy data without writes", async () => {
      const path = `bands/${BAND}/setlists/${SETLIST}`;
      const col = db.collection(`${path}/suggestions`);
      const proposal = { version: 1, kind: "remove", baseFingerprint: "0".repeat(64), itemId: "one" };
      await col.doc("missing-id").set({ type: "remove", status: "open", proposal });
      await db.doc(path).update({ items: [{ songId: "song-1", type: "song" }], songIds: ["song-1"] });
      await assert.rejects(call(events.resolveSuggestion)(req({ bandId: BAND, setlistId: SETLIST, suggestionId: "missing-id", accept: true }, "member")), (error) => error.code === "failed-precondition");
      await col.doc("legacy-items").set({ type: "remove", status: "open", proposal });
      await db.doc(path).update({ items: admin.firestore.FieldValue.delete(), songIds: ["song-1"] });
      await assert.rejects(call(events.resolveSuggestion)(req({ bandId: BAND, setlistId: SETLIST, suggestionId: "legacy-items", accept: true }, "member")), (error) => error.code === "failed-precondition");
      assert.deepEqual((await db.doc(path).get()).data().songIds, ["song-1"]);
      assert.equal((await col.doc("legacy-items").get()).data().status, "open");
    });

    it("rejects invalid typed targets without changing either document", async () => {
      const path = `bands/${BAND}/setlists/${SETLIST}`;
      const items = [{ id: "one", songId: "song-1", type: "song" }];
      const baseFingerprint = require("node:crypto").createHash("sha256")
        .update(JSON.stringify([["one", "song", "song-1", null, null, null, []]])).digest("hex");
      await db.doc(path).update({ items, songIds: ["song-1"] });
      const before = (await db.doc(path).get()).data();
      for (const [kind, fields] of [
        ["add", { songId: "missing" }],
        ["add", { songId: "song-1", beforeItemId: "missing" }],
        ["remove", { itemId: "missing" }],
        ["reorder", { itemIds: [] }],
        ["reorder", { itemIds: ["one", "one"] }],
        ["remove", { itemId: "one", unexpected: true }],
        ["note", {}],
      ]) {
        const ref = db.doc(`${path}/suggestions/invalid`);
        const record = { type: kind, status: "open", proposal: { version: 1, kind, baseFingerprint, ...fields } };
        await ref.set(record);
        await assert.rejects(call(events.resolveSuggestion)(req({ bandId: BAND, setlistId: SETLIST,
          suggestionId: "invalid", accept: true }, "member")), (error) => error.code === "failed-precondition");
        assert.deepEqual((await db.doc(path).get()).data(), before);
        assert.deepEqual((await ref.get()).data(), record);
      }
    });

    it("applies a personal owner's typed change only in the personal scope", async () => {
      const path = "users/personal-owner/setlists/personal-typed";
      const items = [{ id: "one", songId: "song-1", type: "song" }];
      await db.doc(path).set({ items, songIds: ["song-1"], privateField: "preserved" });
      const ref = db.doc(`${path}/suggestions/typed`);
      const baseFingerprint = require("node:crypto").createHash("sha256")
        .update(JSON.stringify([["one", "song", "song-1", null, null, null, []]])).digest("hex");
      await ref.set({ type: "remove", status: "open", proposal: { version: 1, kind: "remove", baseFingerprint, itemId: "one" } });
      const args = { ownerUid: "personal-owner", setlistId: "personal-typed", suggestionId: "typed", accept: true };
      await assert.rejects(call(events.resolveSuggestion)(req(args, "member")), (error) => error.code === "permission-denied");
      assert.deepEqual((await db.doc(path).get()).data().items, items);
      await call(events.resolveSuggestion)(req(args, "personal-owner"));
      const saved = (await db.doc(path).get()).data();
      assert.deepEqual(saved.items, []);
      assert.deepEqual(saved.songIds, []);
      assert.equal(saved.privateField, "preserved");
      assert.equal((await ref.get()).data().resolvedBy, "personal-owner");
      assert.equal((await db.doc(`bands/${BAND}/setlists/${SETLIST}`).get()).exists, true);
    });

    it("allows one winner in concurrent typed resolutions", async () => {
      const path = `bands/${BAND}/setlists/${SETLIST}`;
      await db.doc(path).update({ items: [{ id: "one", songId: "song-1", type: "song" }], songIds: ["song-1"] });
      const fingerprint = require("node:crypto").createHash("sha256").update(JSON.stringify([["one", "song", "song-1", null, null, null, []]])).digest("hex");
      await db.doc(`${path}/suggestions/concurrent`).set({ type: "remove", status: "open", proposal: { version: 1, kind: "remove", baseFingerprint: fingerprint, itemId: "one" } });
      const results = await Promise.allSettled([
        call(events.resolveSuggestion)(req({ bandId: BAND, setlistId: SETLIST, suggestionId: "concurrent", accept: true }, "member")),
        call(events.resolveSuggestion)(req({ bandId: BAND, setlistId: SETLIST, suggestionId: "concurrent", accept: true }, "member")),
      ]);
      assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
      assert.equal((await db.doc(`${path}/suggestions/concurrent`).get()).data().status, "accepted");
      assert.deepEqual((await db.doc(path).get()).data().items, []);
    });

    it("accepts an anonymous suggestion attributed to the assigned name", async () => {
      const token = await shareFor("p-couple");
      const baseFingerprint = require("node:crypto").createHash("sha256")
        .update(JSON.stringify([["i1", "song", "song-1", null, null, null, []]])).digest("hex");
      await call(events.submitSuggestion)(
        req({ token, type: "remove", proposal: { version: 1, kind: "remove", baseFingerprint, itemId: "i1" }, text: "Not this one" }),
      );
      const snap = await db
        .collection(`bands/${BAND}/setlists/${SETLIST}/suggestions`)
        .get();
      assert.equal(snap.size, 1);
      const s = snap.docs[0].data();
      assert.equal(s.authorName, "Ana & Rui");
      assert.equal(s.status, "open");
      assert.equal(s.authorUid, null);
    });

    it("refuses someone whose role cannot suggest", async () => {
      const token = await shareFor("p-eng"); // canSuggest is not set
      await assert.rejects(
        call(events.submitSuggestion)(req({ token, type: "note", text: "hi" })),
        /cannot suggest/,
      );
    });

    it("rejects an unknown suggestion type", async () => {
      const token = await shareFor("p-couple");
      await assert.rejects(
        call(events.submitSuggestion)(
          req({ token, type: "delete_band", text: "x" }),
        ),
        /Unknown suggestion type/,
      );
    });

    it("lets the band resolve one", async () => {
      const token = await shareFor("p-couple");
      const { id } = await call(events.submitSuggestion)(
        req({ token, type: "note", text: "Swap the last song please" }),
      );
      await call(events.resolveSuggestion)(
        req(
          { bandId: BAND, setlistId: SETLIST, suggestionId: id, accept: true },
          "member",
        ),
      );
      const doc = await db
        .doc(`bands/${BAND}/setlists/${SETLIST}/suggestions/${id}`)
        .get();
      assert.equal(doc.data().status, "accepted");
    });

    // E3: without a cap, one anonymous link holder can fill the band's
    // subcollection. Per token, so revoking the noisy link is the whole remedy.
    it("caps how many suggestions one link can make", async () => {
      const token = await shareFor("p-couple");
      const [tokenId] = token.split(".");
      // Start one below the cap so the test does not make 25 round trips.
      await db
        .collection("eventShares")
        .doc(tokenId)
        .update({ suggestionCount: 24 });

      await call(events.submitSuggestion)(
        req({ token, type: "note", text: "the last one that fits" }),
      );
      await assert.rejects(
        call(events.submitSuggestion)(
          req({ token, type: "note", text: "one too many" }),
        ),
        /suggestion limit/,
      );
      const snap = await db
        .collection(`bands/${BAND}/setlists/${SETLIST}/suggestions`)
        .get();
      assert.equal(snap.size, 1, "the rejected suggestion was still written");
    });

    it("counts a link's suggestions on its own share document", async () => {
      const token = await shareFor("p-couple");
      const [tokenId] = token.split(".");
      await call(events.submitSuggestion)(req({ token, type: "note", text: "a" }));
      await call(events.submitSuggestion)(req({ token, type: "note", text: "b" }));
      const doc = await db.collection("eventShares").doc(tokenId).get();
      assert.equal(doc.data().suggestionCount, 2);
    });

    it("does not cap a band member", async () => {
      // Members write the setlist directly; a limit on them would be theatre.
      for (let i = 0; i < 3; i += 1) {
        await call(events.submitSuggestion)(
          req({ bandId: BAND, setlistId: SETLIST, type: "note", text: `m${i}` }, "member"),
        );
      }
      const snap = await db
        .collection(`bands/${BAND}/setlists/${SETLIST}/suggestions`)
        .get();
      assert.equal(snap.size, 3);
    });

    // E4: the suggestions subcollection is members-only, so without this the
    // person who asked never learns what the band decided — and an anonymous
    // holder has no uid for a rule to match on at all.
    it("shows an anonymous holder their own suggestion and its status", async () => {
      const token = await shareFor("p-couple");
      const { id } = await call(events.submitSuggestion)(
        req({ token, type: "note", text: "Swap the last song please" }),
      );

      let view = await call(events.getEventView)(req({ token }));
      assert.equal(view.mySuggestions.length, 1);
      assert.equal(view.mySuggestions[0].text, "Swap the last song please");
      assert.equal(view.mySuggestions[0].status, "open");

      await call(events.resolveSuggestion)(
        req(
          { bandId: BAND, setlistId: SETLIST, suggestionId: id, accept: true },
          "member",
        ),
      );
      view = await call(events.getEventView)(req({ token }));
      assert.equal(view.mySuggestions[0].status, "accepted");
    });

    it("never shows one link holder another link's suggestions", async () => {
      const couple = await shareFor("p-couple");
      await call(events.submitSuggestion)(
        req({ token: couple, type: "note", text: "from the couple" }),
      );
      // Roumé can suggest once given the flag; share separately.
      await events.writeGrants(
        { bandId: BAND },
        SETLIST,
        [PEOPLE[0], PEOPLE[1], { ...PEOPLE[2], canSuggest: true }],
        {},
      );
      await db
        .doc(`bands/${BAND}/setlists/${SETLIST}`)
        .update({
          "eventKit.people": [
            PEOPLE[0],
            PEOPLE[1],
            { ...PEOPLE[2], canSuggest: true },
          ],
        });
      const guest = await shareFor("p-roume");
      await call(events.submitSuggestion)(
        req({ token: guest, type: "note", text: "from the guest" }),
      );

      const coupleView = await call(events.getEventView)(req({ token: couple }));
      const texts = coupleView.mySuggestions.map((x) => x.text);
      assert.deepEqual(texts, ["from the couple"]);
      const wire = JSON.stringify(coupleView);
      assert.ok(!wire.includes("from the guest"), "leaked another's suggestion");
    });

    it("never echoes the share token back in a suggestion", async () => {
      const token = await shareFor("p-couple");
      const [tokenId] = token.split(".");
      await call(events.submitSuggestion)(
        req({ token, type: "note", text: "hello" }),
      );
      const view = await call(events.getEventView)(req({ token }));
      const wire = JSON.stringify(view.mySuggestions);
      assert.ok(!wire.includes(tokenId), "tokenId echoed back to the caller");
    });

    it("gives a band member nothing extra — they read the inbox directly", async () => {
      const token = await shareFor("p-couple");
      await call(events.submitSuggestion)(req({ token, type: "note", text: "x" }));
      const view = await call(events.getEventView)(
        req({ bandId: BAND, setlistId: SETLIST }, "member"),
      );
      assert.deepEqual(view.mySuggestions, []);
    });

    it("does not let a stranger resolve one", async () => {
      const token = await shareFor("p-couple");
      const { id } = await call(events.submitSuggestion)(
        req({ token, type: "note", text: "x" }),
      );
      await assert.rejects(
        call(events.resolveSuggestion)(
          req(
            { bandId: BAND, setlistId: SETLIST, suggestionId: id, accept: true },
            "stranger",
          ),
        ),
        /Only band admins and editors/,
      );
    });
  });
});
