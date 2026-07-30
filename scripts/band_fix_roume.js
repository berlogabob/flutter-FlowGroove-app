#!/usr/bin/env node

/**
 * Repair the three defects in the first Roumé import run.
 *
 *  1. NO ISRCs. band_import_spotify.js fetched them via the batch
 *     /v1/tracks?ids= endpoint, which returns 403 for this Spotify app (another
 *     Development-mode restriction). The failure was swallowed, so all 34 songs
 *     imported with isrc undefined. Backfilled here one at a time via
 *     /v1/tracks/{id}, which works.
 *  2. DUPLICATE SONG. "Viento Helado" exists as both a single and an album track
 *     with the SAME ISRC (QZTBA2633558) — one recording released twice. The album
 *     version is the one referenced by the setlist and carrying the feat note, so
 *     the single is deleted.
 *  3. BAD TAG. `feat-andr` — stripping non-[a-z] from "andré" ate the accented
 *     letter. Replaced with `feat-andre`.
 *
 * The script itself has been fixed for future runs; this only repairs the data
 * already written.
 *
 * Usage:
 *   NODE_PATH=functions/node_modules node scripts/band_fix_roume.js --band <id>
 *   NODE_PATH=functions/node_modules node scripts/band_fix_roume.js --band <id> --commit
 */

const { execFileSync } = require('child_process');
const admin = require('firebase-admin');

const PROJECT_ID = 'repsync-app-8685c';
const COMMIT = process.argv.includes('--commit');
const bandIdx = process.argv.indexOf('--band');
const BAND_ID = bandIdx >= 0 ? process.argv[bandIdx + 1] : null;
if (!BAND_ID) { console.error('--band <bandId> is required'); process.exit(1); }

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

const slug = (s) => String(s || '')
  .normalize('NFD').replace(/[̀-ͯ]/g, '')
  .toLowerCase().replace(/[^a-z0-9]+/g, '');

function secret(name) {
  try {
    return execFileSync('firebase', ['functions:secrets:access', name, '--project', PROJECT_ID],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch (_) { return ''; }
}

async function spotifyToken() {
  const id = secret('SPOTIFY_CLIENT_ID');
  const sec = secret('SPOTIFY_CLIENT_SECRET');
  if (!id || !sec) throw new Error('Spotify credentials unavailable');
  const res = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(`${id}:${sec}`).toString('base64')}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  return (await res.json()).access_token;
}

async function main() {
  console.log(`Repair Roumé band ${BAND_ID} — ${COMMIT ? 'COMMIT' : 'DRY RUN'}\n`);
  const token = await spotifyToken();
  const H = { Authorization: `Bearer ${token}` };

  const col = db.collection('bands').doc(BAND_ID).collection('songs');
  const snap = await col.get();
  const setlists = await db.collection('bands').doc(BAND_ID).collection('setlists').get();
  const inSetlist = new Set(
    setlists.docs.flatMap((d) => (d.data().items || []).map((i) => i.songId).filter(Boolean)),
  );

  // --- 1. ISRC backfill --------------------------------------------------
  const isrcFixes = [];
  const isrcByDoc = new Map();
  for (const d of snap.docs) {
    const x = d.data();
    if (x.isrc || !x.spotifyId) continue;
    const res = await fetch(`https://api.spotify.com/v1/tracks/${x.spotifyId}`, { headers: H });
    if (!res.ok) { console.log(`   ! ${x.title}: HTTP ${res.status}`); continue; }
    const full = await res.json();
    const isrc = (full.external_ids || {}).isrc;
    if (!isrc) continue;
    isrcFixes.push({ ref: d.ref, title: x.title, isrc });
    isrcByDoc.set(d.id, isrc);
  }
  console.log(`1. ISRC backfill: ${isrcFixes.length} songs`);
  isrcFixes.slice(0, 5).forEach((f) => console.log(`     ${f.title.slice(0, 40).padEnd(42)} ${f.isrc}`));
  if (isrcFixes.length > 5) console.log(`     … and ${isrcFixes.length - 5} more`);

  // --- 2. duplicate recordings ------------------------------------------
  const byIsrc = new Map();
  for (const d of snap.docs) {
    const isrc = d.data().isrc || isrcByDoc.get(d.id);
    if (!isrc) continue;
    byIsrc.set(isrc, [...(byIsrc.get(isrc) || []), d]);
  }
  const deletions = [];
  for (const [isrc, docs] of byIsrc) {
    if (docs.length < 2) continue;
    // Keep whichever the setlist references; if neither, keep the first.
    const keep = docs.find((d) => inSetlist.has(d.id)) || docs[0];
    for (const d of docs) {
      if (d.id === keep.id) continue;
      deletions.push({ ref: d.ref, title: d.data().title, album: d.data().album, isrc,
                       keptAlbum: keep.data().album });
    }
  }
  console.log(`\n2. Duplicate recordings (same ISRC): ${deletions.length} to delete`);
  deletions.forEach((x) => console.log(`     delete "${x.title}" from "${x.album}" (ISRC ${x.isrc}); keeping the "${x.keptAlbum}" copy`));

  // --- 3. tag slugs -----------------------------------------------------
  const tagFixes = [];
  for (const d of snap.docs) {
    const tags = d.data().tags || [];
    const fixed = tags.map((t) => {
      if (!t.startsWith('feat-')) return t;
      const name = t.slice(5);
      // Repair only truncated-by-accent names; leave correct ones alone.
      return name === 'andr' ? `feat-${slug('André')}` : t;
    });
    if (JSON.stringify(fixed) !== JSON.stringify(tags)) {
      tagFixes.push({ ref: d.ref, title: d.data().title, from: tags, to: fixed });
    }
  }
  console.log(`\n3. Tag slug fixes: ${tagFixes.length} songs`);
  tagFixes.forEach((f) => console.log(`     ${f.title.slice(0, 34).padEnd(36)} ${JSON.stringify(f.from)} -> ${JSON.stringify(f.to)}`));

  if (!COMMIT) {
    console.log('\nDRY RUN — nothing written. Re-run with --commit to apply.');
    return;
  }

  console.log('\nApplying…');
  for (const f of isrcFixes) {
    await f.ref.set({ isrc: f.isrc, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  }
  console.log(`   backfilled ${isrcFixes.length} ISRCs`);
  for (const x of deletions) {
    await db.recursiveDelete(x.ref);
    console.log(`   deleted duplicate "${x.title}" (${x.album})`);
  }
  for (const f of tagFixes) {
    await f.ref.set({ tags: f.to, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  }
  console.log(`   fixed ${tagFixes.length} tag lists`);
  console.log('\nDone.');
}

main().catch((error) => {
  console.error(`FAILED: ${error.message}`);
  process.exit(1);
});
