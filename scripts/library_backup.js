#!/usr/bin/env node

/**
 * Snapshot a user's song library plus the whole shared canonical catalog to one
 * JSON file, so the Stage 5 enrichment scripts have something to restore from.
 *
 * Unlike the other library scripts this one has no --commit flag: it only reads
 * Firestore and only writes a local file. Run it before anything that mutates.
 *
 * Captures song docs AND their commits subcollection — a linked (schemaVersion 2)
 * song's history lives there, and the migration write-run appends to it, so a
 * backup without commits could not reconstruct one.
 *
 * Output is written to backups/ (gitignored: real lyrics and notes).
 *
 * Usage (firebase-admin lives in functions/node_modules; creds via gcloud ADC
 * or GOOGLE_APPLICATION_CREDENTIALS):
 *   NODE_PATH=functions/node_modules node scripts/library_backup.js
 *   NODE_PATH=functions/node_modules node scripts/library_backup.js --uid <uid> --out <path>
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DEFAULT_UID = '7RPi5xPJV5XeTm0SIWubea9DVjJ3'; // berloga.bob@gmail.com
const PROJECT_ID = 'repsync-app-8685c';

function parseArgs(argv) {
  const args = { uid: DEFAULT_UID, out: null, project: PROJECT_ID };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--uid') args.uid = argv[++i];
    else if (arg === '--out') args.out = argv[++i];
    else if (arg === '--project') args.project = argv[++i];
    else if (arg === '--help' || arg === '-h') args.help = true;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  if (!args.uid) throw new Error('--uid requires a value');
  return args;
}

// Firestore Timestamps and DocumentReferences are not JSON-serialisable, and
// silently becoming {} would make a backup that looks fine and restores nothing.
function serialise(value) {
  if (value === null || value === undefined) return null;
  if (Array.isArray(value)) return value.map(serialise);
  if (value instanceof Date) return { __type: 'date', iso: value.toISOString() };
  if (typeof value.toDate === 'function') {
    return { __type: 'timestamp', iso: value.toDate().toISOString() };
  }
  if (value && typeof value === 'object' && typeof value.path === 'string' &&
      typeof value.id === 'string' && typeof value.collection === 'function') {
    return { __type: 'reference', path: value.path };
  }
  if (typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => [k, serialise(v)]),
    );
  }
  return value;
}

async function dumpDocWithSubcollections(doc) {
  const entry = { id: doc.id, path: doc.ref.path, data: serialise(doc.data()) };
  const subs = await doc.ref.listCollections();
  if (subs.length > 0) {
    entry.subcollections = {};
    for (const sub of subs) {
      const snap = await sub.get();
      entry.subcollections[sub.id] = snap.docs.map((d) => ({
        id: d.id,
        data: serialise(d.data()),
      }));
    }
  }
  return entry;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log('Usage: node scripts/library_backup.js [--uid <uid>] [--out <path>] [--project <id>]');
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: args.project,
  });
  const db = admin.firestore();

  console.log(`Backing up library for ${args.uid} from project ${args.project}\n`);

  const songsSnap = await db.collection('users').doc(args.uid).collection('songs').get();
  const songs = [];
  let commitCount = 0;
  for (const doc of songsSnap.docs) {
    const entry = await dumpDocWithSubcollections(doc);
    commitCount += ((entry.subcollections || {}).commits || []).length;
    songs.push(entry);
  }
  console.log(`  songs:      ${songs.length} (${commitCount} commit docs)`);

  const canonicalSnap = await db.collection('canonical_songs').get();
  const canonicalSongs = canonicalSnap.docs.map((d) => ({
    id: d.id,
    path: d.ref.path,
    data: serialise(d.data()),
  }));
  console.log(`  canonicals: ${canonicalSongs.length}`);

  const setlistsSnap = await db.collection('users').doc(args.uid).collection('setlists').get();
  const setlists = setlistsSnap.docs.map((d) => ({
    id: d.id,
    path: d.ref.path,
    data: serialise(d.data()),
  }));
  console.log(`  setlists:   ${setlists.length}`);

  const payload = {
    generatedAt: new Date().toISOString(),
    project: args.project,
    uid: args.uid,
    counts: {
      songs: songs.length,
      commits: commitCount,
      canonicalSongs: canonicalSongs.length,
      setlists: setlists.length,
    },
    songs,
    canonicalSongs,
    setlists,
  };

  const stamp = payload.generatedAt.replace(/[:.]/g, '-');
  const outPath = args.out || path.join('backups', `library-${stamp}.json`);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(payload, null, 2));

  const kb = Math.round(fs.statSync(outPath).size / 1024);
  console.log(`\nWrote ${outPath} (${kb} KB)`);
}

main().catch((error) => {
  console.error(`FAILED: ${error.message}`);
  process.exit(1);
});
