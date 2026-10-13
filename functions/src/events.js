/**
 * Event participants: attaching a person to ONE event without putting them in
 * the band.
 *
 * A guest pianist, a venue's art director, a sound engineer and a wedding
 * couple all need part of an event and nothing else. Band membership is far too
 * blunt for that — it hands over the whole song pool, every other setlist, and
 * a permanent role describing one night's work.
 *
 * Two rules shape everything here:
 *
 *  1. SCOPING HAPPENS ON THE SERVER. `getEventView` builds the payload from the
 *     caller's grant and never sends an area they cannot see. Filtering in the
 *     app would leave the data on the wire, which is exactly the leak we are
 *     trying to close — a wedding couple must not receive chord charts at all,
 *     not merely have them hidden.
 *
 *  2. SUGGESTING NEEDS NO ACCOUNT, EDITING DOES. A client or a venue will never
 *     complete a signup, so they propose changes from a plain link. Anyone who
 *     actually changes stored data signs in first, so every write carries a uid
 *     and the security rules can gate on it.
 *
 * Grants are owned by this module and live in their own documents, never as
 * fields on the setlist — see writeGrants() for why that distinction is the
 * whole design.
 */

const crypto = require("node:crypto");
const functions = require("firebase-functions");
const functionsV1 = require("firebase-functions/v1");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const AREAS = ["eventInfo", "runningOrder", "songDetail", "stage", "rider"];
const SUGGESTION_TYPES = ["reorder", "add", "remove", "note"];

// A capability URL should not be valid forever — anyone who ever saw the link
// keeps the access it carries, and links leak through screenshots, chat logs
// and browser history. W3C "Good Practices for Capability URLs" §2.4.
const SHARE_TTL_DAYS = 90;

// One anonymous link holder can otherwise fill a band's suggestions
// subcollection. Per token, not per band: revoking the noisy link is then the
// whole remedy and nobody else is affected.
const MAX_SUGGESTIONS_PER_TOKEN = 25;

// getEventView fans out over the event's songs. Firestore's getAll takes them
// in one round trip, but an unbounded list is still an unbounded response.
const MAX_EVENT_SONGS = 100;

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function requireAuth(request) {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Request must be authenticated.",
    );
  }
  return request.auth.uid;
}

/**
 * The shared demo account is read-only and must never gain access to real
 * data. Mirrors isDemoUser in bands.js / account.js — the token claim first so
 * the common case costs no read.
 */
async function isDemoUser(uid, token = {}) {
  if (token && token.demo === true) return true;
  const doc = await db.collection("users").doc(uid).get();
  return doc.exists && doc.data().accessRole === "demo";
}

async function refuseDemo(request, what) {
  const uid = request.auth && request.auth.uid;
  if (!uid) return;
  if (await isDemoUser(uid, (request.auth && request.auth.token) || {})) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      `The demo account cannot ${what}.`,
    );
  }
}

// ---------------------------------------------------------------------------
// Grants
// ---------------------------------------------------------------------------

/** Drop anything that is not a known area/level, so a malformed roster entry
 *  can never widen a grant. Mirrors sanitizeAccess in lib/models/event_access.dart. */
function sanitizeAccess(access) {
  const out = {};
  if (!access || typeof access !== "object") return out;
  for (const [area, level] of Object.entries(access)) {
    if (AREAS.includes(area) && (level === "view" || level === "edit")) {
      out[area] = level;
    }
  }
  return out;
}

/**
 * Everyone on `people` who is linked to an account AND actually granted
 * something. A roster entry that is only a name on a stage plot grants nothing.
 */
function grantedParticipants(people) {
  return (people || [])
    .filter((p) => p && cleanString(p.uid))
    .map((p) => ({ ...p, access: sanitizeAccess(p.access) }))
    .filter((p) => Object.keys(p.access).length > 0);
}

function parseScope(data = {}) {
  const bandId = cleanString((data || {}).bandId);
  const ownerUid = cleanString((data || {}).ownerUid);
  if (!!bandId === !!ownerUid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Exactly one of bandId or ownerUid is required.",
    );
  }
  return bandId ? { bandId } : { ownerUid };
}

function scopeRef(scope) {
  return scope.bandId
    ? db.collection("bands").doc(scope.bandId)
    : db.collection("users").doc(scope.ownerUid);
}

function setlistRef(scope, setlistId) {
  return scopeRef(scope).collection("setlists").doc(setlistId);
}

function grantRef(scope, setlistId, uid) {
  return setlistRef(scope, setlistId).collection("grants").doc(uid);
}

async function requireScopeWriter(scope, uid) {
  if (scope.bandId) {
    requireBandWriter(await loadBand(scope.bandId), uid);
  } else if (uid !== scope.ownerUid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only the owner can manage personal event sharing.",
    );
  }
}

function inviteRef(uid, setlistId) {
  return db.collection("users").doc(uid).collection("eventInvites").doc(setlistId);
}

/**
 * Write the grants for an event, in two places, in one batch.
 *
 * WHY NOT FIELDS ON THE SETLIST: Firestore has no partial writes — a rule either
 * accepts a document write or rejects all of it — so anything stored on a
 * document the client rewrites is only as durable as the oldest client build in
 * the wild. It bit us for real: on 2026-08-21 an app build that predated these
 * fields did an ordinary `.set(setlist.toJson())` while adding a break divider
 * and silently deleted every grant on the setlist. Merge fixes new clients and
 * cannot fix installed ones.
 *
 * Firebase's own guidance is to put such data in a separate document
 * ("Control access to specific fields"), and to keep roles in their own
 * collection rather than on the target document once sharing gets complex
 * ("Secure data access for users and groups"). So:
 *
 *   bands/{b}/setlists/{s}/grants/{uid}   <- what the rules read (client: no write)
 *   users/{uid}/eventInvites/{setlistId}  <- how a guest FINDS the event
 *
 * The second exists because Firebase's RBAC guidance never solves "resources
 * shared with me", and querying it any other way would drag the grant back onto
 * the setlist document. It also lets the rules drop a collection-group rule over
 * `{path=**}/setlists`, which matched every user's personal setlists too.
 */
async function writeGrants(scope, setlistId, people, setlist = {}) {
  const granted = grantedParticipants(people);
  const wanted = new Map(granted.map((p) => [p.uid, p]));

  const existing = await setlistRef(scope, setlistId).collection("grants").get();
  const batch = db.batch();
  const now = new Date().toISOString();

  // Revoke first: anyone dropped from the roster loses both records.
  for (const doc of existing.docs) {
    if (!wanted.has(doc.id)) {
      batch.delete(doc.ref);
      batch.delete(inviteRef(doc.id, setlistId));
    }
  }

  for (const person of granted) {
    batch.set(grantRef(scope, setlistId, person.uid), {
      uid: person.uid,
      participantId: person.id || "",
      access: person.access,
      canSuggest: person.canSuggest === true,
      grantedAt: now,
    });
    // Enough for the guest's "Guest appearances" list without reading a band
    // collection they have no access to.
    batch.set(inviteRef(person.uid, setlistId), {
      ...scope,
      setlistId,
      name: setlist.name || "",
      eventDateTime: setlist.eventDateTime || null,
      eventLocation: setlist.eventLocation || null,
      role: person.role || "",
      updatedAt: now,
    });
  }

  await batch.commit();
  return granted;
}

/** The caller's grant for this event, or null. */
async function loadGrant(scope, setlistId, uid) {
  if (!uid) return null;
  const doc = await grantRef(scope, setlistId, uid).get();
  if (!doc.exists) return null;
  const g = doc.data();
  return { ...g, access: sanitizeAccess(g.access) };
}

async function loadBand(bandId) {
  const doc = await db.collection("bands").doc(bandId).get();
  if (!doc.exists) {
    throw new functions.https.HttpsError("not-found", "Band not found.");
  }
  return doc.data();
}

async function loadSetlist(scope, setlistId) {
  const doc = await setlistRef(scope, setlistId).get();
  if (!doc.exists) {
    throw new functions.https.HttpsError("not-found", "Event not found.");
  }
  return doc.data();
}

function requireBandWriter(band, uid) {
  const isAdmin = (band.adminUids || []).includes(uid);
  const isEditor = (band.editorUids || []).includes(uid);
  if (!isAdmin && !isEditor) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only band admins and editors can manage event sharing.",
    );
  }
}

/**
 * Rewrite the roster and the grants it implies, never separately.
 *
 * The roster (`eventKit.people`) is display data and lives on the setlist; the
 * grants derived from it live in their own documents, out of every client's
 * reach. Keeping the two in one function is what stops them drifting.
 */
async function writeRoster(scope, setlistId, people) {
  const clean = people.map((p) => ({ ...p, access: sanitizeAccess(p.access) }));
  const setlist = await loadSetlist(scope, setlistId);
  await setlistRef(scope, setlistId).update({
    "eventKit.people": clean,
    updatedAt: new Date().toISOString(),
  });
  await writeGrants(scope, setlistId, clean, setlist);
  return clean;
}

// ---------------------------------------------------------------------------
// Share tokens
// ---------------------------------------------------------------------------
//
// The link is `<tokenId>.<secret>`. Only the secret's hash is stored, so a dump
// of the eventShares collection does not yield working links. The tokenId keeps
// band/setlist ids out of the URL and makes revocation a single delete.

const hash = (secret) =>
  crypto.createHash("sha256").update(secret).digest("hex");

function parseToken(token) {
  const [tokenId, secret] = cleanString(token).split(".");
  if (!tokenId || !secret) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid link.");
  }
  return { tokenId, secret };
}

/** Resolve a raw token to its share, or throw. Never leaks why it failed. */
async function resolveToken(token) {
  const { tokenId, secret } = parseToken(token);
  const doc = await db.collection("eventShares").doc(tokenId).get();
  const share = doc.exists ? doc.data() : null;
  const expected = share && share.secretHash ? share.secretHash : "";
  const actual = hash(secret);
  // Absent expiresAt means a link minted before expiry existed: those keep
  // working rather than dying silently on deploy day. New ones always carry it.
  const expired =
    !!share && !!share.expiresAt && Date.parse(share.expiresAt) <= Date.now();
  const ok =
    share &&
    !share.revoked &&
    !expired &&
    expected.length === actual.length &&
    crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(actual));
  if (!ok) {
    // One message for missing, revoked, expired and wrong-secret alike: a
    // link that distinguishes them is an oracle for guessing valid tokenIds.
    throw new functions.https.HttpsError(
      "permission-denied",
      "This link is no longer valid.",
    );
  }
  return { tokenId, ...share };
}

/**
 * Create a share link for one person already on the event roster.
 * Input:  { bandId OR ownerUid, setlistId, participantId }
 * Output: { token, tokenId } — the raw token is returned ONCE and never stored.
 */
exports.createEventShare = functions.https.onCall(async (request) => {
  const uid = requireAuth(request);
  const scope = parseScope(request.data);
  const { setlistId, participantId } = request.data || {};
  if (!setlistId || !participantId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "setlistId and participantId are required.",
    );
  }

  await refuseDemo(request, "share events");
  await requireScopeWriter(scope, uid);
  const setlist = await loadSetlist(scope, setlistId);
  const people = (setlist.eventKit && setlist.eventKit.people) || [];
  const person = people.find((p) => p && p.id === participantId);
  if (!person) {
    throw new functions.https.HttpsError(
      "not-found",
      "That person is not on this event's roster.",
    );
  }

  const tokenId = crypto.randomUUID();
  const secret = crypto.randomBytes(24).toString("base64url");
  const now = Date.now();
  const expiresAt = new Date(
    now + SHARE_TTL_DAYS * 24 * 60 * 60 * 1000,
  ).toISOString();
  await db.collection("eventShares").doc(tokenId).set({
    tokenId,
    ...scope,
    setlistId,
    participantId,
    secretHash: hash(secret),
    revoked: false,
    expiresAt,
    suggestionCount: 0,
    createdBy: uid,
    createdAt: new Date(now).toISOString(),
  });

  // expiresAt is returned so the band can be told when the link dies. The
  // secret is not stored and is never returned again.
  return { tokenId, token: `${tokenId}.${secret}`, expiresAt };
});

/** Revoke one person's link without touching anyone else's. */
exports.revokeEventShare = functions.https.onCall(async (request) => {
  const uid = requireAuth(request);
  const tokenId = cleanString((request.data || {}).tokenId);
  if (!tokenId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "tokenId is required.",
    );
  }
  await refuseDemo(request, "revoke event links");
  const doc = await db.collection("eventShares").doc(tokenId).get();
  if (!doc.exists) return { revoked: true };
  await requireScopeWriter(parseScope(doc.data()), uid);
  await doc.ref.update({ revoked: true, revokedAt: new Date().toISOString() });
  return { revoked: true };
});

// ---------------------------------------------------------------------------
// Reading an event
// ---------------------------------------------------------------------------

/** The grant for whoever is asking. Band members see everything. */
async function resolveViewer({ token, bandId, ownerUid, setlistId, uid }) {
  if (token) {
    const share = await resolveToken(token);
    const scope = parseScope(share);
    const setlist = await loadSetlist(scope, share.setlistId);
    const people = (setlist.eventKit && setlist.eventKit.people) || [];
    const person = people.find((p) => p && p.id === share.participantId);
    if (!person) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "This link is no longer valid.",
      );
    }
    return {
      scope,
      setlistId: share.setlistId,
      setlist,
      access: sanitizeAccess(person.access),
      canSuggest: person.canSuggest === true,
      name: person.name || "",
      tokenId: share.tokenId,
      // May be set: a signed-in person can open a link. Both identities are
      // then used to find the suggestions they made either side of signing in.
      uid: uid || null,
    };
  }

  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Sign in or use a share link.",
    );
  }
  const scope = parseScope({ bandId, ownerUid });
  if (!setlistId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "setlistId is required.",
    );
  }

  const band = scope.bandId ? await loadBand(scope.bandId) : null;
  const setlist = await loadSetlist(scope, setlistId);

  if (scope.ownerUid === uid || (band && (band.memberUids || []).includes(uid))) {
    return {
      scope,
      setlistId,
      setlist,
      access: Object.fromEntries(AREAS.map((a) => [a, "edit"])),
      canSuggest: false,
      isMember: true,
      uid,
    };
  }

  // The grant document, NOT the roster on the setlist. The roster is display
  // data on a document clients rewrite; the grant is the authority.
  const grant = await loadGrant(scope, setlistId, uid);
  if (!grant || Object.keys(grant.access).length === 0) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "You do not have access to this event.",
    );
  }
  const people = (setlist.eventKit && setlist.eventKit.people) || [];
  const person = people.find((p) => p && p.id === grant.participantId);
  return {
    scope,
    setlistId,
    setlist,
    access: grant.access,
    canSuggest: grant.canSuggest === true,
    name: (person && person.name) || "",
    uid,
  };
}

const canView = (access, area) =>
  access[area] === "view" || access[area] === "edit";

/**
 * The ONE read path for an event, for members, signed-in guests and anonymous
 * link holders alike.
 *
 * Areas the caller cannot see are OMITTED from the response, not flagged —
 * that is the difference between scoping and hiding.
 *
 * Song content comes from here rather than from a direct Firestore read
 * because security rules cannot express "only the songs in this setlist":
 * rules can get() a known path but cannot scan a collection. Granting a guest
 * the band's songs collection would hand them the entire pool.
 */
/**
 * The suggestions this viewer themselves submitted, newest first.
 *
 * Identity is the share token for an anonymous holder and the uid for someone
 * signed in — a claimed link produces both, so a person keeps sight of what
 * they asked for before signing in. A band member sees the whole inbox through
 * the subcollection and gets nothing extra here.
 */
async function ownSuggestions(viewer) {
  if (viewer.isMember) return [];
  const col = setlistRef(viewer.scope, viewer.setlistId).collection(
    "suggestions",
  );
  const queries = [];
  if (viewer.tokenId) {
    queries.push(col.where("shareTokenId", "==", viewer.tokenId).get());
  }
  if (viewer.uid) {
    queries.push(col.where("authorUid", "==", viewer.uid).get());
  }
  if (!queries.length) return [];
  const snaps = await Promise.all(queries);
  const byId = new Map();
  for (const snap of snaps) {
    for (const doc of snap.docs) {
      const d = doc.data();
      // Deliberately no authorUid and no shareTokenId: the caller already knows
      // who they are, and echoing a token back widens where it can leak.
      byId.set(doc.id, {
        id: doc.id,
        type: d.type || "note",
        songId: d.songId || null,
        text: d.text || "",
        status: d.status || "open",
        createdAt: d.createdAt || null,
        resolvedAt: d.resolvedAt || null,
      });
    }
  }
  return [...byId.values()].sort((a, b) =>
    String(b.createdAt).localeCompare(String(a.createdAt)),
  );
}

exports.getEventView = functions.https.onCall(async (request) => {
  const { token, bandId, ownerUid, setlistId } = request.data || {};
  const viewer = await resolveViewer({
    token: cleanString(token),
    bandId: cleanString(bandId),
    ownerUid: cleanString(ownerUid),
    setlistId: cleanString(setlistId),
    uid: request.auth ? request.auth.uid : null,
  });

  const { setlist, access } = viewer;
  const kit = setlist.eventKit || {};
  const view = {
    setlistId: viewer.setlistId,
    name: setlist.name || "",
    viewer: {
      name: viewer.name || "",
      canSuggest: viewer.canSuggest,
      access,
    },
  };

  if (canView(access, "eventInfo")) {
    view.eventDateTime = setlist.eventDateTime || null;
    view.eventLocation = setlist.eventLocation || null;
    view.description = setlist.description || null;
  }

  // Keep break dividers: they are part of the running order a venue reads.
  const items = (setlist.items || []).filter(Boolean);
  let songs = [];
  if (canView(access, "runningOrder")) {
    const all = items
      .filter((i) => i.type !== "break" && i.songId)
      .map((i) => i.songId);
    // Capped and SAID so: a silently short list reads as "the band only has
    // nine songs" to whoever is holding the running order at the venue.
    const wanted = all.slice(0, MAX_EVENT_SONGS);
    view.songsTruncated = all.length > wanted.length;
    // One round trip for the whole event instead of one per song. getAll
    // rejects an empty argument list, so guard it.
    const songsCollection = scopeRef(viewer.scope).collection("songs");
    const docs = wanted.length
      ? await db.getAll(...wanted.map((id) => songsCollection.doc(id)))
      : [];
    const full = canView(access, "songDetail");
    songs = docs
      .filter((d) => d.exists)
      .map((d) => {
        const s = d.data();
        const mat = s.materialized || s;
        // Titles always; the chart only for someone who plays it. A wedding
        // couple asked for their first dance, not a transposition.
        const base = {
          id: d.id,
          title: mat.title || "",
          artist: mat.artist || "",
        };
        if (!full) return base;
        return {
          ...base,
          ourKey: mat.ourKey || null,
          ourBPM: mat.ourBPM || null,
          notes: mat.notes || null,
          sections: mat.sections || [],
        };
      });
    view.items = items.map((i) => ({
      id: i.id,
      songId: i.songId || null,
      type: i.type || "song",
      breakType: i.breakType || null,
      breakLabel: i.breakLabel || null,
    }));
    view.songs = songs;
  }

  // The person's OWN suggestions and what the band decided about them.
  //
  // The suggestions subcollection is readable only by band members, so without
  // this "the band decides" is invisible to the person who asked — and an
  // anonymous link holder has no uid for a security rule to match on at all.
  // Returning them here is the only path that works for both.
  view.mySuggestions = await ownSuggestions(viewer);

  if (canView(access, "stage")) view.stage = kit.stage || {};
  if (canView(access, "rider")) view.rider = kit.rider || [];
  // The roster is part of event info: who else is on the gig, names and roles
  // only — never anyone's uid or their grant.
  if (canView(access, "eventInfo")) {
    view.people = (kit.people || []).map((p) => ({
      id: p.id,
      name: p.name || "",
      role: p.role || "",
    }));
  }

  return view;
});

// ---------------------------------------------------------------------------
// Claiming a link
// ---------------------------------------------------------------------------

/**
 * Bind a share link to the signed-in account: the link → sign in → edit path.
 *
 * After this the person appears in the grant arrays, so the security rules let
 * them read the live setlist and write their own area directly, without going
 * through a callable for every keystroke.
 */
exports.claimEventShare = functions.https.onCall(async (request) => {
  const uid = requireAuth(request);
  await refuseDemo(request, "join an event");
  const share = await resolveToken(cleanString((request.data || {}).token));
  const scope = parseScope(share);
  const ref = setlistRef(scope, share.setlistId);

  // Read-check-write in one transaction so two people opening the same link
  // cannot both pass the "unclaimed" check (last write used to win).
  const { next, index, setlist } = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Event not found.");
    }
    const data = snap.data();
    const people = (data.eventKit && data.eventKit.people) || [];
    const i = people.findIndex((p) => p && p.id === share.participantId);
    if (i < 0) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "This link is no longer valid.",
      );
    }
    const claimedBy = cleanString(people[i].uid);
    if (claimedBy && claimedBy !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "This link has already been claimed by someone else.",
      );
    }
    const n = people.slice();
    n[i] = { ...people[i], uid };
    const clean = n.map((p) => ({ ...p, access: sanitizeAccess(p.access) }));
    tx.update(ref, {
      "eventKit.people": clean,
      updatedAt: new Date().toISOString(),
    });
    return { next: clean, index: i, setlist: data };
  });
  await writeGrants(scope, share.setlistId, next, setlist);

  return {
    ...scope,
    setlistId: share.setlistId,
    access: sanitizeAccess(next[index].access),
  };
});

// ---------------------------------------------------------------------------
// Suggestions
// ---------------------------------------------------------------------------

/**
 * A proposed change from someone who cannot make it.
 *
 * Deliberately one mechanism for every case: a wedding couple reordering or
 * asking for a song, and a venue asking to swap a track or a word for the
 * censor, are all "a note about the event or one song, optionally proposing an
 * action". The band accepts or declines.
 */
exports.submitSuggestion = functions.https.onCall(async (request) => {
  await refuseDemo(request, "suggest changes");
  const { token, bandId, ownerUid, setlistId, type, songId, text } = request.data || {};
  const viewer = await resolveViewer({
    token: cleanString(token),
    bandId: cleanString(bandId),
    ownerUid: cleanString(ownerUid),
    setlistId: cleanString(setlistId),
    uid: request.auth ? request.auth.uid : null,
  });

  if (!viewer.isMember && !viewer.canSuggest) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "You cannot suggest changes to this event.",
    );
  }
  const kind = cleanString(type) || "note";
  if (!SUGGESTION_TYPES.includes(kind)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Unknown suggestion type "${kind}".`,
    );
  }
  const body = cleanString(text);
  if (!body && kind === "note") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "A note needs some text.",
    );
  }

  // Per-token cap. Members are not counted: they are already trusted to write
  // the setlist directly, so a limit on them would only be theatre. The counter
  // lives on the share document and is bumped in the same transaction that
  // checks it, so two concurrent submissions cannot both slip past the cap.
  if (viewer.tokenId) {
    const shareRef = db.collection("eventShares").doc(viewer.tokenId);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(shareRef);
      const used = (snap.exists && snap.data().suggestionCount) || 0;
      if (used >= MAX_SUGGESTIONS_PER_TOKEN) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "This link has reached its suggestion limit.",
        );
      }
      tx.update(shareRef, { suggestionCount: used + 1 });
    });
  }

  const id = crypto.randomUUID();
  await setlistRef(viewer.scope, viewer.setlistId)
    .collection("suggestions")
    .doc(id)
    .set({
      id,
      type: kind,
      songId: cleanString(songId) || null,
      text: body.slice(0, 2000),
      // Attributed to the name the band assigned when sharing, so an anonymous
      // link still produces "Sputnik — Ana asked to…" rather than a bare token.
      authorName: viewer.name || "Guest",
      authorUid: request.auth ? request.auth.uid : null,
      shareTokenId: viewer.tokenId || null,
      status: "open",
      createdAt: new Date().toISOString(),
    });

  return { id };
});

/** Band-side accept/decline. Applying the change itself stays in the app. */
exports.resolveSuggestion = functions.https.onCall(async (request) => {
  const uid = requireAuth(request);
  const scope = parseScope(request.data);
  const { setlistId, suggestionId, accept } = request.data || {};
  if (!setlistId || !suggestionId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "setlistId and suggestionId are required.",
    );
  }
  await refuseDemo(request, "resolve suggestions");
  await requireScopeWriter(scope, uid);
  await setlistRef(scope, cleanString(setlistId))
    .collection("suggestions")
    .doc(cleanString(suggestionId))
    .update({
      status: accept === true ? "accepted" : "declined",
      resolvedBy: uid,
      resolvedAt: new Date().toISOString(),
    });
  return { status: accept === true ? "accepted" : "declined" };
});

// ---------------------------------------------------------------------------
// Keeping the two derived records honest
// ---------------------------------------------------------------------------

/**
 * Core of the setlist trigger, injectable for tests.
 *
 * Two jobs, both invisible until they bite:
 *
 *  DELETE — Firestore does not cascade. Deleting a setlist leaves its `grants`
 *  subcollection and every `users/{uid}/eventInvites/{setlistId}` behind. The
 *  guest keeps seeing a phantom event, and an orphaned grant would silently
 *  authorise anyone if that setlist id were ever reused.
 *
 *  UPDATE — the invite index carries a snapshot of the event's name, date and
 *  venue so a guest's list needs no access to the band's collection. Written
 *  only when the roster changed, it goes stale the moment the band moves the
 *  gig — and a guest reading yesterday's call time is the worst kind of stale.
 */
async function syncEventGrants(scope, setlistId, { before, after }) {
  const grantsCol = setlistRef(scope, setlistId).collection("grants");
  const grants = await grantsCol.get();
  if (grants.empty) return { deleted: 0, refreshed: 0 };

  const batch = db.batch();

  if (!after) {
    for (const doc of grants.docs) {
      batch.delete(doc.ref);
      batch.delete(inviteRef(doc.id, setlistId));
    }
    await batch.commit();
    return { deleted: grants.size, refreshed: 0 };
  }

  const changed = ["name", "eventDateTime", "eventLocation"].some(
    (field) => (before || {})[field] !== after[field],
  );
  if (!changed) return { deleted: 0, refreshed: 0 };

  for (const doc of grants.docs) {
    batch.set(
      inviteRef(doc.id, setlistId),
      {
        name: after.name || "",
        eventDateTime: after.eventDateTime || null,
        eventLocation: after.eventLocation || null,
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
  }
  await batch.commit();
  return { deleted: 0, refreshed: grants.size };
}

/**
 * Cascade-clean and refresh the derived grant records whenever a band setlist
 * changes. A trigger rather than code in the delete paths because there are
 * several writers — two Dart save paths, the MCP tools, and the admin SDK — and
 * only a trigger catches all of them.
 */
exports.onBandSetlistWritten = functionsV1.firestore
  .document("bands/{bandId}/setlists/{setlistId}")
  .onWrite(async (change, context) => {
    const { bandId, setlistId } = context.params;
    const out = await syncEventGrants({ bandId }, setlistId, {
      before: change.before.exists ? change.before.data() : null,
      after: change.after.exists ? change.after.data() : null,
    });
    if (out.deleted || out.refreshed) {
      console.log(
        `onBandSetlistWritten ${bandId}/${setlistId}: ` +
          `deleted ${out.deleted}, refreshed ${out.refreshed}`,
      );
    }
  });

exports.onUserSetlistWritten = functionsV1.firestore
  .document("users/{ownerUid}/setlists/{setlistId}")
  .onWrite(async (change, context) => {
    const { ownerUid, setlistId } = context.params;
    const out = await syncEventGrants({ ownerUid }, setlistId, {
      before: change.before.exists ? change.before.data() : null,
      after: change.after.exists ? change.after.data() : null,
    });
    if (out.deleted || out.refreshed) {
      console.log(
        `onUserSetlistWritten ${ownerUid}/${setlistId}: ` +
          `deleted ${out.deleted}, refreshed ${out.refreshed}`,
      );
    }
  });

/**
 * Every grant in a scope, cleared before deleting its band or personal owner.
 * Firestore does not cascade, so each guest's invite must be removed too.
 */
async function purgeScopeGrants(scope) {
  const setlists = await scopeRef(scope).collection("setlists").get();
  let removed = 0;
  for (const setlist of setlists.docs) {
    const grants = await setlist.ref.collection("grants").get();
    if (grants.empty) continue;
    const batch = db.batch();
    for (const grant of grants.docs) {
      batch.delete(grant.ref);
      batch.delete(inviteRef(grant.id, setlist.id));
      removed += 1;
    }
    await batch.commit();
  }
  return removed;
}

async function purgeBandGrants(bandId) {
  return purgeScopeGrants({ bandId });
}

async function purgePersonalEventGrants(ownerUid) {
  await purgeScopeGrants({ ownerUid });
  const shares = await db
    .collection("eventShares")
    .where("ownerUid", "==", ownerUid)
    .get();
  await Promise.all(shares.docs.map((doc) => doc.ref.delete()));
}

/**
 * Every grant HELD BY one person, cleared. Used on account deletion.
 *
 * Driven from the user's own invite index rather than a collection-group query,
 * so it needs no extra index and cannot miss a band the query would not reach.
 * Must run BEFORE the user document is recursively deleted, or the index that
 * says where their grants live is already gone.
 */
async function purgeUserGrants(uid) {
  const invites = await db
    .collection("users")
    .doc(uid)
    .collection("eventInvites")
    .get();
  if (invites.empty) return 0;
  const batch = db.batch();
  for (const invite of invites.docs) {
    const { bandId, ownerUid, setlistId } = invite.data();
    if ((bandId || ownerUid) && setlistId) {
      batch.delete(grantRef(parseScope({ bandId, ownerUid }), setlistId, uid));
    }
    batch.delete(invite.ref);
  }
  await batch.commit();
  return invites.size;
}

/** Cascade every grant in a band when the band itself is deleted. */
exports.onBandDeleted = functionsV1.firestore
  .document("bands/{bandId}")
  .onDelete(async (snap, context) => {
    const removed = await purgeBandGrants(context.params.bandId);
    if (removed) {
      console.log(`onBandDeleted ${context.params.bandId}: purged ${removed} grant(s)`);
    }
  });

// Exported for tests.
exports.purgeBandGrants = purgeBandGrants;
exports.purgeUserGrants = purgeUserGrants;
exports.purgePersonalEventGrants = purgePersonalEventGrants;
exports.grantedParticipants = grantedParticipants;
exports.writeGrants = writeGrants;
exports.loadGrant = loadGrant;
exports.syncEventGrants = syncEventGrants;
exports.sanitizeAccess = sanitizeAccess;
exports.AREAS = AREAS;
exports.MAX_EVENT_SONGS = MAX_EVENT_SONGS;
exports.MAX_SUGGESTIONS_PER_TOKEN = MAX_SUGGESTIONS_PER_TOKEN;
exports.SHARE_TTL_DAYS = SHARE_TTL_DAYS;
