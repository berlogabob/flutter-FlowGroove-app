#!/usr/bin/env node

/**
 * Create a band from the command line.
 *
 * There is no createBand callable — band creation is a client-side Firestore
 * write in the app (lib/screens/bands/create_band_screen.dart), so this
 * replicates FirestoreService.saveBandBatch (lib/services/firestore_service.dart)
 * exactly: TWO documents, bands/{id} and users/{uid}/bands/{id}, holding the same
 * full band JSON. Writing only the first leaves the band half-created.
 *
 * TRAP, learned the hard way from reading the model: `createdAt` must be an
 * ISO-8601 STRING. Band._parseDateTime (lib/models/band.dart:191-205) handles
 * DateTime | String | int but has NO Timestamp branch, so a serverTimestamp()
 * silently falls through to `DateTime.now()` and the creation date is wrong
 * forever, with no error. Song and Setlist both DO handle Timestamps — Band is
 * the odd one out.
 *
 * Usage:
 *   NODE_PATH=functions/node_modules node scripts/band_create.js --name "Roumé"
 *   NODE_PATH=functions/node_modules node scripts/band_create.js --name "Roumé" --commit
 */

const crypto = require('crypto');
const admin = require('firebase-admin');

const DEFAULT_UID = '7RPi5xPJV5XeTm0SIWubea9DVjJ3';
const PROJECT_ID = 'repsync-app-8685c';

function parseArgs(argv) {
  const args = { uid: DEFAULT_UID, name: null, description: null, commit: false };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--name') args.name = argv[++i];
    else if (a === '--uid') args.uid = argv[++i];
    else if (a === '--description') args.description = argv[++i];
    else if (a === '--commit') args.commit = true;
    else throw new Error(`Unknown argument: ${a}`);
  }
  if (!args.name) throw new Error('--name is required');
  return args;
}

/** Mirrors Band.generateUniqueInviteCode (lib/models/band.dart:180-188). */
function generateInviteCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 6; i += 1) {
    code += chars[crypto.randomInt(chars.length)];
  }
  return code;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });
  const db = admin.firestore();

  console.log(`Create band "${args.name}" for ${args.uid} — ${args.commit ? 'COMMIT' : 'DRY RUN'}\n`);

  const existing = await db.collection('bands').get();
  const clash = existing.docs.find(
    (d) => (d.data().name || '').trim().toLowerCase() === args.name.trim().toLowerCase(),
  );
  if (clash) {
    console.error(`ABORTED: a band named "${clash.data().name}" already exists (${clash.id}).`);
    process.exit(1);
  }

  // displayName/email come from Auth so the members row matches what the app
  // would have written itself.
  const user = await admin.auth().getUser(args.uid);

  const bandId = crypto.randomUUID();
  const band = {
    id: bandId,
    name: args.name.trim(),
    description: args.description,
    photoURL: null,
    createdBy: args.uid,
    members: [{
      uid: args.uid,
      role: 'admin',
      displayName: user.displayName || null,
      email: user.email || null,
      musicRoles: [],
    }],
    memberUids: [args.uid],   // load-bearing: the band list queries array-contains on this
    adminUids: [args.uid],
    editorUids: [],
    tags: [],
    inviteCode: generateInviteCode(),
    // ISO string, NOT a Timestamp — see the header note.
    createdAt: new Date().toISOString(),
  };

  console.log('bands/' + bandId);
  for (const [k, v] of Object.entries(band)) {
    console.log(`  ${k.padEnd(12)} ${JSON.stringify(v)}`.slice(0, 118));
  }
  console.log(`\nusers/${args.uid}/bands/${bandId}  (mirror, same JSON)`);
  console.log(`\ninvite code: ${band.inviteCode}  — share this so guests can join`);

  if (!args.commit) {
    console.log('\nDRY RUN — nothing written. Re-run with --commit to apply.');
    return;
  }

  const batch = db.batch();
  batch.set(db.collection('bands').doc(bandId), band);
  batch.set(db.collection('users').doc(args.uid).collection('bands').doc(bandId), band);
  await batch.commit();

  console.log('\nWritten. Verifying…');
  const check = await db.collection('bands').doc(bandId).get();
  const mirror = await db.collection('users').doc(args.uid).collection('bands').doc(bandId).get();
  console.log(`  bands/${bandId.slice(0, 8)}…      exists=${check.exists}`);
  console.log(`  users/…/bands/${bandId.slice(0, 8)}… exists=${mirror.exists}`);
  console.log(`  createdAt type: ${typeof check.data().createdAt} (must be "string")`);
  console.log(`\nBAND_ID=${bandId}`);
}

main().catch((error) => {
  console.error(`FAILED: ${error.message}`);
  process.exit(1);
});
