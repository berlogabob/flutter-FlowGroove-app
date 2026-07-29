#!/usr/bin/env node

/**
 * Orphan check: bands whose doc was deleted but whose subcollections
 * (songs/setlists/commits) still exist. Solo-band dissolution in
 * functions/src/bands.js deletes the band doc + personal ref but does NOT
 * cascade subcollections (the documented ponytail ceiling at bands.js:252).
 *
 * A deleted-but-not-empty band shows up via listDocuments({showMissing:true})
 * as a doc reference with no createTime. Re-run this periodically; if it ever
 * reports orphans, that's the signal to add a recursiveDelete to the leave path.
 *
 * Usage (firebase-admin lives in functions/node_modules; creds via gcloud ADC
 * or GOOGLE_APPLICATION_CREDENTIALS):
 *   NODE_PATH=functions/node_modules node scripts/check_orphaned_bands.js
 */

const admin = require('firebase-admin');

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();

async function main() {
  const refs = await db.collection('bands').listDocuments();
  const orphans = [];
  for (const ref of refs) {
    const snap = await ref.get();
    if (snap.exists) continue; // live band, fine
    const subs = await ref.listCollections();
    if (subs.length) orphans.push({ id: ref.id, subs: subs.map((c) => c.id) });
  }

  if (!orphans.length) {
    console.log('✅ No orphaned band subcollections.');
    return;
  }
  console.log(`⚠️  ${orphans.length} orphaned band(s) — deleted doc, surviving subcollections:`);
  for (const o of orphans) console.log(`  bands/${o.id} → ${o.subs.join(', ')}`);
  process.exitCode = 1;
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
