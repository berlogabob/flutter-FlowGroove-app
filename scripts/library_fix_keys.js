#!/usr/bin/env node

/**
 * Stage 5.7.3 — clean up the key data.
 *
 * Three problems, all traced to causes:
 *
 *  1. PHANTOM "C". Commit 2fadced5 (2026-02-18) shipped the key picker with
 *     `_originalKeyBase = 'C'` and no empty option, so an untouched picker
 *     persisted "C" to BOTH key fields. aa3e417f (2026-07-15) fixed it — commit
 *     message: "no phantom key 'C' on add-song (P2-1)". Only the data residue is
 *     left, in two shapes:
 *       - contradictory: ourKey "C" while the original key is E/G/B, or no
 *         original key at all. A band does not transpose everything to C.
 *       - phantom pairs: both keys "C" on a song created before the fix.
 *         Independently wrong for Pinball Wizard (B) and Shape of You (C#m).
 *  2. CASING. The form used to emit lowercase minors ("dm"), which the MCP
 *     schema rejected. Normalised here to the uppercase convention the schema,
 *     the CSV schema and the filter chips all use.
 *  3. TWO MISSING KEYS worth filling, where the original key is unambiguous.
 *
 * Deliberately NOT guessed: Charlie (RHCP), Pink Panther, Tourniquet, and Bulls
 * on Parade (drop-D makes the written key genuinely ambiguous). A wrong key in a
 * canonical propagates to every user who links that song, so the bar is high.
 *
 * ponytail: no commit doc is appended for these edits. The commits subcollection
 * is an append-only history for user edits; this is a one-off repair and the
 * script output plus the backup are the audit trail. Add commits here only if the
 * app ever starts reconciling delta against latestCommitId.
 *
 * Usage (run scripts/library_backup.js first):
 *   NODE_PATH=functions/node_modules node scripts/library_fix_keys.js
 *   NODE_PATH=functions/node_modules node scripts/library_fix_keys.js --commit
 */

const admin = require('firebase-admin');

const DEFAULT_UID = '7RPi5xPJV5XeTm0SIWubea9DVjJ3';
const PROJECT_ID = 'repsync-app-8685c';
const COMMIT = process.argv.includes('--commit');

// The release that removed the phantom default. A both-keys-"C" song created
// before this almost certainly never had its key set by hand.
const PHANTOM_FIX_DATE = '2026-07-15';

// Keys to fill, by canonical title + artist. Only unambiguous, well-documented
// originals. These are model-supplied, not sourced from any API — no metadata
// provider exposes musical key (Spotify's audio-features is 403 for this app).
const FILL_BASE_KEY = [
  { title: 'Hey Joe', artist: 'Jimi Hendrix', baseKey: 'E' },
  { title: 'Back to Black', artist: 'Amy Winehouse', baseKey: 'Dm' },
];

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

const { normalizeKey } = require('../functions/src/mcp/song_schema');

const DELETE = admin.firestore.FieldValue.delete;

function createdAtIso(value) {
  if (!value) return '';
  if (typeof value === 'string') return value;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  return '';
}

function fail(message) {
  console.error(`\nABORTED: ${message}`);
  console.error('Nothing was written.');
  process.exit(1);
}

async function main() {
  console.log(`Key cleanup for ${DEFAULT_UID} — ${COMMIT ? 'COMMIT' : 'DRY RUN'}\n`);

  const snap = await db.collection('users').doc(DEFAULT_UID).collection('songs').get();
  const live = snap.docs.filter((d) => !d.data().deletedAt);

  const canonCache = new Map();
  const canonicalFor = async (id) => {
    if (!id) return null;
    if (!canonCache.has(id)) {
      const doc = await db.collection('canonical_songs').doc(id).get();
      canonCache.set(id, doc.exists ? { ref: doc.ref, data: doc.data() } : null);
    }
    return canonCache.get(id);
  };

  const clearOurKey = [];        // contradictory
  const clearBoth = [];          // phantom pairs
  const normalise = [];          // casing
  const fills = [];

  for (const doc of live) {
    const data = doc.data();
    const canonical = await canonicalFor(data.canonicalSongId);
    if (!canonical) continue;
    const delta = data.delta || {};
    const title = canonical.data.title;
    const artist = canonical.data.artist;
    const ourKey = delta.ourKey ?? null;
    const baseKey = canonical.data.baseKey ?? null;
    const created = createdAtIso(data.createdAt).slice(0, 10);

    const label = `${title} / ${artist}`;

    if (ourKey === 'C' && baseKey === 'C' && created && created < PHANTOM_FIX_DATE) {
      clearBoth.push({ doc, canonical, label, created, baseKey, ourKey });
      continue;
    }
    if (ourKey === 'C' && baseKey !== 'C') {
      clearOurKey.push({ doc, canonical, label, baseKey, created });
      continue;
    }

    // Casing, for anything not being cleared.
    const normOur = ourKey === null ? null : normalizeKey(ourKey);
    const normBase = baseKey === null ? null : normalizeKey(baseKey);
    if ((normOur !== null && normOur !== ourKey) || (normBase !== null && normBase !== baseKey)) {
      normalise.push({
        doc, canonical, label,
        ourKey, normOur: normOur !== ourKey ? normOur : null,
        baseKey, normBase: normBase !== baseKey ? normBase : null,
      });
    }
  }

  for (const target of FILL_BASE_KEY) {
    const entry = [...canonCache.values()].find((c) =>
      c && c.data.title === target.title && c.data.artist === target.artist);
    if (!entry) fail(`cannot find canonical for ${target.title} / ${target.artist}`);
    if (entry.data.baseKey) {
      console.log(`  note: ${target.title} already has baseKey "${entry.data.baseKey}" — leaving it`);
      continue;
    }
    fills.push({ canonical: entry, ...target });
  }

  // --- report -------------------------------------------------------------
  console.log(`live songs: ${live.length}\n`);

  console.log(`1. CLEAR ourKey — contradictory "C" (${clearOurKey.length})`);
  clearOurKey.forEach((r) =>
    console.log(`   ${r.label.slice(0, 44).padEnd(46)} original=${String(r.baseKey).padEnd(5)} ourKey "C" -> unset`));

  console.log(`\n2. CLEAR both keys — phantom pair, pre-${PHANTOM_FIX_DATE} (${clearBoth.length})`);
  clearBoth.forEach((r) =>
    console.log(`   ${r.label.slice(0, 44).padEnd(46)} created ${r.created}  "C"/"C" -> unset`));

  console.log(`\n3. NORMALISE casing (${normalise.length})`);
  normalise.forEach((r) => {
    const parts = [];
    if (r.normBase) parts.push(`baseKey "${r.baseKey}" -> "${r.normBase}"`);
    if (r.normOur) parts.push(`ourKey "${r.ourKey}" -> "${r.normOur}"`);
    console.log(`   ${r.label.slice(0, 44).padEnd(46)} ${parts.join('  ')}`);
  });

  console.log(`\n4. FILL baseKey — model-supplied, unverified (${fills.length})`);
  fills.forEach((r) => console.log(`   ${`${r.title} / ${r.artist}`.slice(0, 44).padEnd(46)} baseKey -> "${r.baseKey}"`));
  console.log('   NOT filled (deliberately): Charlie, Pink Panther, Tourniquet, Bulls on Parade');

  if (!COMMIT) {
    console.log('\nDRY RUN — nothing written. Re-run with --commit to apply.');
    return;
  }

  // --- apply --------------------------------------------------------------
  console.log('\nApplying…');
  const now = admin.firestore.FieldValue.serverTimestamp();
  const bump = (c) => ({
    canonicalRevision: (c.data.canonicalRevision || 1) + 1,
    updatedAt: now,
  });

  for (const r of clearOurKey) {
    await r.doc.ref.set({
      delta: { ourKey: DELETE() },
      materialized: { ourKey: DELETE() },
      updatedAt: new Date().toISOString(),
    }, { merge: true });
    console.log(`  cleared ourKey  ${r.label}`);
  }

  for (const r of clearBoth) {
    await r.doc.ref.set({
      delta: { ourKey: DELETE() },
      materialized: { ourKey: DELETE(), originalKey: DELETE() },
      updatedAt: new Date().toISOString(),
    }, { merge: true });
    await r.canonical.ref.set({ baseKey: null, ...bump(r.canonical) }, { merge: true });
    console.log(`  cleared both    ${r.label}`);
  }

  for (const r of normalise) {
    if (r.normOur) {
      await r.doc.ref.set({
        delta: { ourKey: r.normOur },
        materialized: { ourKey: r.normOur },
        updatedAt: new Date().toISOString(),
      }, { merge: true });
    }
    if (r.normBase) {
      await r.canonical.ref.set({ baseKey: r.normBase, ...bump(r.canonical) }, { merge: true });
    }
    console.log(`  normalised      ${r.label}`);
  }

  for (const r of fills) {
    await r.canonical.ref.set({ baseKey: r.baseKey, ...bump(r.canonical) }, { merge: true });
    console.log(`  filled baseKey  ${r.title} -> ${r.baseKey}`);
  }

  console.log('\nDone.');
}

main().catch((error) => {
  console.error(`FAILED: ${error.message}`);
  process.exit(1);
});
