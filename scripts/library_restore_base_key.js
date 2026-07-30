#!/usr/bin/env node

/**
 * Stage 5.4b — restore originalKey / originalBPM visibility after the v2
 * migration, from the songs' OWN pre-migration values.
 *
 * The bug: SongDelta.applyTo (lib/models/song_delta.dart:180-181) resolves a
 * linked song's originalKey/originalBPM from canonical.baseKey / canonical.baseBpm.
 * computeDelta in the migration does NOT carry originalKey/originalBPM into the
 * delta, and library_canonicals.js deliberately left baseKey/baseBpm null. Net
 * effect: every migrated song silently lost its original key and BPM in the app.
 * The values survive in `materialized`, but that is only read when the canonical
 * is unavailable.
 *
 * The fix is to populate the canonical fields that exist for exactly this — and
 * crucially, to populate them from the user's own data, not from a guess. A
 * song's original key IS a property of the song, so the canonical is the right
 * home for it.
 *
 * Refuses to write when two songs linked to the same canonical disagree, rather
 * than letting one silently win.
 *
 * Usage:
 *   NODE_PATH=functions/node_modules node scripts/library_restore_base_key.js
 *   NODE_PATH=functions/node_modules node scripts/library_restore_base_key.js --commit
 */

const admin = require('firebase-admin');

const DEFAULT_UID = '7RPi5xPJV5XeTm0SIWubea9DVjJ3';
const PROJECT_ID = 'repsync-app-8685c';
const COMMIT = process.argv.includes('--commit');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

const blank = (v) => v === null || v === undefined ||
  (typeof v === 'string' && v.trim().length === 0);

async function main() {
  console.log(`Restore canonical baseKey/baseBpm — ${COMMIT ? 'COMMIT' : 'DRY RUN'}\n`);

  const snap = await db.collection('users').doc(DEFAULT_UID).collection('songs').get();
  const live = snap.docs.filter((d) => !d.data().deletedAt);

  // canonicalSongId -> proposed { baseKey, baseBpm } plus who proposed it
  const proposals = new Map();
  const conflicts = [];
  let noSource = 0;

  for (const doc of live) {
    const data = doc.data();
    const canonicalSongId = data.canonicalSongId;
    if (!canonicalSongId) continue;
    const mat = data.materialized || {};
    const key = blank(mat.originalKey) ? null : String(mat.originalKey).trim();
    const bpm = Number.isFinite(Number(mat.originalBPM)) && Number(mat.originalBPM) > 0
      ? Math.round(Number(mat.originalBPM)) : null;
    if (key === null && bpm === null) { noSource += 1; continue; }

    const title = mat.title || '(untitled)';
    if (!proposals.has(canonicalSongId)) {
      proposals.set(canonicalSongId, { key, bpm, from: title });
      continue;
    }
    const prev = proposals.get(canonicalSongId);
    if ((key !== null && prev.key !== null && key !== prev.key) ||
        (bpm !== null && prev.bpm !== null && bpm !== prev.bpm)) {
      conflicts.push(`${canonicalSongId}: "${prev.from}" says ${prev.key}/${prev.bpm}, "${title}" says ${key}/${bpm}`);
      continue;
    }
    proposals.set(canonicalSongId, {
      key: prev.key ?? key,
      bpm: prev.bpm ?? bpm,
      from: prev.from,
    });
  }

  if (conflicts.length > 0) {
    console.error('CONFLICTS — two songs disagree on the same canonical:');
    conflicts.forEach((c) => console.error(`  ${c}`));
    console.error('\nRefusing to guess. Resolve these first.');
    process.exit(1);
  }

  const writes = [];
  for (const [canonicalSongId, proposal] of proposals) {
    const ref = db.collection('canonical_songs').doc(canonicalSongId);
    const doc = await ref.get();
    if (!doc.exists) continue;
    const data = doc.data();
    const changes = {};
    // Fill-only: never overwrite a baseKey/baseBpm that is already set.
    if (proposal.key !== null && blank(data.baseKey)) changes.baseKey = proposal.key;
    if (proposal.bpm !== null && (data.baseBpm === null || data.baseBpm === undefined)) {
      changes.baseBpm = proposal.bpm;
    }
    if (Object.keys(changes).length === 0) continue;
    writes.push({ ref, canonicalSongId, data, changes, title: proposal.from });
  }

  console.log(`live linked songs: ${live.length}`);
  console.log(`songs with no original key/BPM to restore: ${noSource}`);
  console.log(`\n=== ${writes.length} canonicals to fill ===`);
  for (const w of writes) {
    const parts = Object.entries(w.changes).map(([f, v]) => `${f}=${JSON.stringify(v)}`);
    console.log(`  ${w.title.padEnd(34)} ${parts.join('  ')}`);
  }

  if (!COMMIT) {
    console.log('\nDRY RUN — nothing written. Re-run with --commit to apply.');
    return;
  }

  console.log('\nApplying…');
  for (const w of writes) {
    await w.ref.set({
      ...w.changes,
      canonicalRevision: (w.data.canonicalRevision || 1) + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  console.log(`  updated ${writes.length} canonicals`);
}

main().catch((error) => {
  console.error(`FAILED: ${error.message}`);
  process.exit(1);
});
