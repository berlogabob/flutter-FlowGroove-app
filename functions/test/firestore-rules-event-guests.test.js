const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const projectId = "repsync-app-event-guest-rules-test";
const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8",
);

const BAND = "band-1";
const SETLIST = "sl-1";

const setlistDoc = (extra = {}) => ({
  id: SETLIST,
  bandId: BAND,
  name: "Sputnik Bar",
  songIds: ["song-1"],
  items: [{ id: "i1", songId: "song-1" }],
  eventDateTime: "2026-08-21T19:00:00.000Z",
  eventKit: {
    stage: { "back-left": [{ kind: "equipment", label: "Drum kit" }] },
    rider: [{ label: "XLR cables", done: false }],
    people: [],
  },
  createdAt: "2026-08-01T00:00:00.000Z",
  updatedAt: "2026-08-01T00:00:00.000Z",
  ...extra,
});

const setlistRef = (db) =>
  db.collection("bands").doc(BAND).collection("setlists").doc(SETLIST);

describe("Event guest Firestore rules", function () {
  this.timeout(20000);
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({ projectId, firestore: { rules } });
  });
  after(async () => testEnv && testEnv.cleanup());

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      for (const uid of [
        "member",
        "guest",
        "soundEng",
        "video",
        "manager",
        "stranger",
      ]) {
        await db.collection("users").doc(uid).set({ uid, accessRole: "member" });
      }
      await db.collection("bands").doc(BAND).set({
        id: BAND,
        memberUids: ["member"],
        editorUids: ["member"],
        adminUids: ["member"],
      });
      await setlistRef(db).set(setlistDoc());
      // Grants live in their own documents, out of every client's reach.
      const grants = {
        guest: { eventInfo: "view", runningOrder: "view" },
        soundEng: { eventInfo: "view", stage: "edit" },
        video: { eventInfo: "view", rider: "edit" },
        manager: { eventInfo: "view", runningOrder: "edit" },
      };
      for (const [uid, access] of Object.entries(grants)) {
        await setlistRef(db).collection("grants").doc(uid).set({
          uid, participantId: "p-" + uid, access, canSuggest: false,
        });
        await db.collection("users").doc(uid)
          .collection("eventInvites").doc(SETLIST)
          .set({ bandId: BAND, setlistId: SETLIST, name: "Sputnik Bar" });
      }
      await db
        .collection("bands")
        .doc(BAND)
        .collection("songs")
        .doc("song-1")
        .set({ id: "song-1", title: "visto" });
      // A PERSONAL setlist — the collection-group rule must never reach this.
      await db
        .collection("users")
        .doc("member")
        .collection("setlists")
        .doc("private-1")
        .set({ id: "private-1", bandId: "", name: "My private list" });
    });
  });

  const as = (uid) => testEnv.authenticatedContext(uid).firestore();

  describe("reading the event", () => {
    it("does NOT let even a granted guest read the setlist document", async () => {
      // Firestore reads whole documents. Letting a guest read this one hands
      // them the stage plot, the rider, every roster uid and the assignments
      // regardless of their grant — getEventView's scoping would be decoration.
      // Guests read through getEventView instead.
      await assertFails(setlistRef(as("guest")).get());
      await assertFails(setlistRef(as("soundEng")).get());
      await assertFails(setlistRef(as("manager")).get());
    });

    it("still lets a band member read it", async () => {
      await assertSucceeds(setlistRef(as("member")).get());
    });

    it("denies someone with no grant", async () => {
      await assertFails(setlistRef(as("stranger")).get());
    });

    it("does NOT give a guest the band's song pool", async () => {
      // The whole point of routing song content through getEventView.
      await assertFails(
        as("guest").collection("bands").doc(BAND).collection("songs").get(),
      );
      await assertFails(
        as("guest")
          .collection("bands")
          .doc(BAND)
          .collection("songs")
          .doc("song-1")
          .get(),
      );
    });
  });

  describe("discovery", () => {
    it("lets a guest list their own event invites", async () => {
      const snap = await as("guest")
        .collection("users").doc("guest").collection("eventInvites").get();
      assert.equal(snap.size, 1);
      assert.equal(snap.docs[0].data().bandId, BAND);
    });

    it("does not let anyone read another user's invites", async () => {
      await assertFails(
        as("stranger")
          .collection("users").doc("guest").collection("eventInvites").get(),
      );
    });

    it("does not let a client forge an invite for themselves", async () => {
      // The index is the discovery half of a grant; if a client could write it
      // they could not read the setlist anyway, but it must still be closed.
      await assertFails(
        as("stranger")
          .collection("users").doc("stranger")
          .collection("eventInvites").doc(SETLIST)
          .set({ bandId: BAND, setlistId: SETLIST }),
      );
    });

    it("no longer exposes personal setlists through a collection group", async () => {
      // Discovery used to be collectionGroup('setlists').where('guestUids'...),
      // which needed a match on /{path=**}/setlists/{id} — a path that also
      // matched users/{uid}/setlists/{id}. That rule is gone; this asserts it
      // stays gone.
      await assertFails(
        as("stranger")
          .collection("users").doc("member")
          .collection("setlists").doc("private-1").get(),
      );
      await assertFails(
        as("stranger").collectionGroup("setlists").get(),
      );
    });
  });

  describe("area editing", () => {
    it("an area editor can WRITE without being able to READ", async () => {
      // The assumption the whole design rests on: a Firestore update does not
      // require read permission — the rule may inspect resource.data even when
      // the caller cannot read the document. If this ever stops holding, the
      // sound engineer silently loses the ability to edit the stage plot.
      await assertFails(setlistRef(as("soundEng")).get());
      await assertSucceeds(
        setlistRef(as("soundEng")).update({
          "eventKit.stage": { "mid-center": [{ kind: "equipment", label: "Amp" }] },
        }),
      );
    });

    it("lets the stage editor change the stage plot", async () => {
      await assertSucceeds(
        setlistRef(as("soundEng")).update({
          "eventKit.stage": { "back-left": [], "mid-center": [] },
          updatedAt: "2026-08-21T10:00:00.000Z",
        }),
      );
    });

    it("stops the stage editor touching the rider", async () => {
      await assertFails(
        setlistRef(as("soundEng")).update({
          "eventKit.rider": [{ label: "Smoke machine", done: false }],
        }),
      );
    });

    it("stops the rider editor touching the stage", async () => {
      await assertFails(
        setlistRef(as("video")).update({ "eventKit.stage": {} }),
      );
    });

    it("lets the rider editor change the rider", async () => {
      await assertSucceeds(
        setlistRef(as("video")).update({
          "eventKit.rider": [{ label: "Camera rig", done: false }],
        }),
      );
    });

    it("stops an area editor changing the running order", async () => {
      await assertFails(
        setlistRef(as("soundEng")).update({ songIds: [], items: [] }),
      );
      await assertFails(setlistRef(as("soundEng")).update({ name: "Hijacked" }));
    });

    it("stops an area editor promoting themselves", async () => {
      // Grants are not fields on this document any more, so there is nothing to
      // smuggle into a setlist write. The grant document itself is closed to
      // every client.
      await assertFails(
        setlistRef(as("soundEng")).collection("grants").doc("soundEng")
          .set({ uid: "soundEng", access: { stage: "edit", rider: "edit" } }),
      );
      await assertFails(
        setlistRef(as("soundEng")).collection("grants").doc("soundEng")
          .update({ "access.rider": "edit" }),
      );
      await assertFails(
        setlistRef(as("soundEng")).collection("grants").doc("stranger")
          .set({ uid: "stranger", access: { stage: "edit" } }),
      );
      await assertFails(
        setlistRef(as("soundEng")).collection("grants").doc("soundEng").delete(),
      );
    });

    it("stops a view-only guest editing anything", async () => {
      await assertFails(setlistRef(as("guest")).update({ "eventKit.stage": {} }));
      await assertFails(setlistRef(as("guest")).update({ "eventKit.rider": [] }));
    });

    it("stops an area editor rewriting the roster", async () => {
      // eventKit.people carries the grants that the arrays are derived from.
      await assertFails(
        setlistRef(as("soundEng")).update({
          "eventKit.people": [
            { id: "p", name: "Me", role: "manager", uid: "soundEng" },
          ],
        }),
      );
    });
  });

  describe("escalated manager (eventEditorUids)", () => {
    it("can change the event's own fields", async () => {
      await assertSucceeds(
        setlistRef(as("manager")).update({
          name: "Sputnik Bar — second set",
          eventLocation: "Sputnik Bar, Lisbon (back room)",
          items: [{ id: "i1", songId: "song-1" }],
          songIds: ["song-1"],
          updatedAt: "2026-08-21T10:00:00.000Z",
        }),
      );
    });

    it("cannot promote anyone, including themselves", async () => {
      // The whole reason the grant arrays are server-owned: an escalated
      // manager who could write them could hand themselves every area forever.
      await assertFails(
        setlistRef(as("manager")).collection("grants").doc("manager")
          .set({ uid: "manager", access: { stage: "edit", rider: "edit" } }),
      );
      await assertFails(
        setlistRef(as("manager")).collection("grants").doc("stranger")
          .set({ uid: "stranger", access: { runningOrder: "edit" } }),
      );
    });

    it("cannot rewrite the roster the grants come from", async () => {
      await assertFails(
        setlistRef(as("manager")).update({
          "eventKit.people": [
            { id: "p", name: "Me", role: "manager", uid: "manager" },
          ],
        }),
      );
    });

    it("does not let a plain guest do the same", async () => {
      await assertFails(setlistRef(as("guest")).update({ name: "Hijacked" }));
    });
  });

  describe("concurrent edits", () => {
    it("an area edit and a running-order save do not erase each other", async () => {
      // stage and rider have their own editors and their own permissions, so
      // the app writes event-kit areas through dotted field paths and excludes
      // eventKit from the setlist save. A whole-document write on either side
      // would silently destroy the other's work.
      await Promise.all([
        setlistRef(as("soundEng")).update({
          "eventKit.stage": { "mid-center": [{ kind: "equipment", label: "Amp" }] },
        }),
        setlistRef(as("member")).update({
          name: "Sputnik Bar — final",
          songIds: ["song-1"],
        }),
      ]);

      const after = (await setlistRef(as("member")).get()).data();
      assert.equal(after.name, "Sputnik Bar — final");
      assert.equal(after.eventKit.stage["mid-center"][0].label, "Amp");
      // The rider belonged to neither writer and must be untouched.
      assert.equal(after.eventKit.rider[0].label, "XLR cables");
    });
  });

  describe("suggestions", () => {
    const suggestionsRef = (db) =>
      setlistRef(db).collection("suggestions").doc("sug-1");
    const suggestion = (uid) => ({
      id: "sug-1",
      type: "note",
      text: "Swap the last song",
      status: "open",
      authorUid: uid,
    });

    it("lets a band member raise one", async () => {
      await assertSucceeds(
        suggestionsRef(as("member")).set(suggestion("member")),
      );
    });

    it("does NOT let any signed-in stranger write into a band's setlist", async () => {
      // Regression: the rule once checked only that authorUid matched the
      // caller, which proves who you are and never that you were invited —
      // leaving every band in the project open to writes from any account.
      await assertFails(
        suggestionsRef(as("stranger")).set(suggestion("stranger")),
      );
    });

    it("does not let an event guest write directly either", async () => {
      // Guests go through the submitSuggestion callable, which checks their
      // canSuggest grant; the direct path stays closed to them.
      await assertFails(suggestionsRef(as("guest")).set(suggestion("guest")));
    });

    it("does not let anyone forge another author", async () => {
      await assertFails(
        suggestionsRef(as("member")).set(suggestion("stranger")),
      );
    });
  });

  describe("an OLD app build cannot destroy a grant", () => {
    it("survives a full replacing set() that knows nothing about grants", async () => {
      // THE regression. On 2026-08-21 a build predating the grant fields saved a
      // setlist normally (adding a break divider) and, because Firestore has no
      // partial writes, its replacing set() deleted every grant on the document.
      // Grants now live in a subcollection, so a document write cannot reach
      // them however old or careless the client is.
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .firestore()
          .doc(`bands/${BAND}/setlists/${SETLIST}`)
          .set({
            // Exactly what an older Setlist.toJson() produced: no grants, and
            // note this is set() WITHOUT merge — a full replace.
            id: SETLIST,
            bandId: BAND,
            name: "Sputnik Bar",
            songIds: ["song-1"],
            items: [
              { id: "i1", songId: "song-1" },
              { id: "i2", type: "break", breakLabel: "Roume" },
            ],
            updatedAt: "2026-08-21T17:54:09.599415",
          });
      });

      // The setlist really was replaced...
      const after = await testEnv
        .authenticatedContext("member")
        .firestore()
        .doc(`bands/${BAND}/setlists/${SETLIST}`)
        .get();
      assert.equal(after.data().items.length, 2);
      assert.equal(after.data().eventKit, undefined);

      // ...and every grant survived it.
      for (const uid of ["guest", "soundEng", "video", "manager"]) {
        const grant = await testEnv
          .authenticatedContext(uid)
          .firestore()
          .doc(`bands/${BAND}/setlists/${SETLIST}/grants/${uid}`)
          .get();
        assert.ok(grant.exists, `grant for ${uid} was destroyed`);
      }
      // The guest still FINDS the event (they read it via getEventView).
      const invites = await as("guest")
        .collection("users").doc("guest").collection("eventInvites").get();
      assert.equal(invites.size, 1);
    });
  });

  describe("a stale event kit cannot revert an area editor", () => {
    it("refuses a member's whole-document save that carries a stale event kit", async () => {
      // The sound engineer moves an amp...
      await assertSucceeds(
        setlistRef(as("soundEng")).update({
          "eventKit.stage": { "mid-center": [{ kind: "equipment", label: "Amp" }] },
        }),
      );
      // ...and an older build, holding the event kit it loaded BEFORE that,
      // saves the setlist normally. Allowing it would silently revert the amp.
      await assertFails(
        setlistRef(as("member")).set({
          ...setlistDoc(),
          name: "Renamed by an old client",
        }),
      );
    });

    it("still allows a save that leaves the event kit alone", async () => {
      await assertSucceeds(
        setlistRef(as("member")).update({ name: "Renamed", songIds: ["song-1"] }),
      );
    });

    it("still allows re-sending an IDENTICAL event kit", async () => {
      // affectedKeys() lists only what actually changed, so an unchanged copy
      // is not a conflict and must not be punished.
      await assertSucceeds(setlistRef(as("member")).set(setlistDoc()));
    });

    it("still allows the dotted-field-path route on its own", async () => {
      await assertSucceeds(
        setlistRef(as("member")).update({ "eventKit.rider": [] }),
      );
    });
  });

  describe("share tokens", () => {
    it("are unreadable by clients", async () => {
      await assertFails(as("member").collection("eventShares").doc("t1").get());
      await assertFails(
        as("member").collection("eventShares").doc("t1").set({ bandId: BAND }),
      );
    });
  });
});
