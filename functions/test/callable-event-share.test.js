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
  await events.writeGrants(BAND, SETLIST, people, { name: "Sputnik Bar" });
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
        BAND,
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
      await events.writeGrants(BAND, SETLIST, [PEOPLE[0], PEOPLE[1]], {});
      assert.deepEqual(await grantIds(), []);
      const invite = await db.doc(`users/roume/eventInvites/${SETLIST}`).get();
      assert.equal(invite.exists, false);
    });

    it("ignores an invented area or level", async () => {
      await events.writeGrants(
        BAND,
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
      const out = await events.syncEventGrants(BAND, SETLIST, {
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
      const out = await events.syncEventGrants(BAND, SETLIST, { before, after });

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
      const out = await events.syncEventGrants(BAND, SETLIST, {
        before,
        after: { ...before, items: [] },
      });
      assert.deepEqual(out, { deleted: 0, refreshed: 0 });
    });

    it("is a no-op for an event nobody is a guest on", async () => {
      const out = await events.syncEventGrants(BAND, "no-such-setlist", {
        before: null,
        after: null,
      });
      assert.deepEqual(out, { deleted: 0, refreshed: 0 });
    });
  });

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
    it("accepts an anonymous suggestion attributed to the assigned name", async () => {
      const token = await shareFor("p-couple");
      await call(events.submitSuggestion)(
        req({ token, type: "remove", songId: "song-1", text: "Not this one" }),
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
        BAND,
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
