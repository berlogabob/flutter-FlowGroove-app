#!/usr/bin/env node

/**
 * Stage 5.2 — remove junk from a personal library before enrichment runs, so no
 * API budget is spent on rows that are about to disappear.
 *
 * Three jobs:
 *   1. Delete 10 junk songs — a Feb-2026 batch of 7 with title/artist REVERSED
 *      (each a duplicate of a correct June twin), plus 3 test placeholders.
 *   2. Truncate "Wrecking Ball" to its 10 real chord-chart sections, dropping 10
 *      fabricated ones an earlier AI fill run appended (instructional prose in
 *      place of lyrics: "[Dm]First phrase [F]opens, [C]second phrase [Gm]answers").
 *   3. Retire the orphaned canonical artifact normalized_01ba4719… — literally
 *      sha256("\n"), the doc every Cyrillic song collapsed into before the
 *      Unicode-aware normalize fix. It shares MBID edf8d9b5 with the real
 *      "День рождения" canonical, which makes ensureCanonicalSong throw for that
 *      recording today.
 *
 * SAFETY: every deletion asserts the doc id AND its title+artist before acting;
 * a single mismatch aborts the whole run before any write. Preview by default.
 *
 * Usage (run scripts/library_backup.js FIRST):
 *   NODE_PATH=functions/node_modules node scripts/library_cleanup.js
 *   NODE_PATH=functions/node_modules node scripts/library_cleanup.js --commit
 */

const admin = require('firebase-admin');

const DEFAULT_UID = '7RPi5xPJV5XeTm0SIWubea9DVjJ3';
const PROJECT_ID = 'repsync-app-8685c';
const COMMIT = process.argv.includes('--commit');

const WRECKING_BALL_ID = '3692d6cd-67fc-4110-b88b-665f72f46428';
const ARTIFACT_CANONICAL_ID = 'normalized_01ba4719c80b6fe911b091a7c05124b6';

// id -> [expected title, expected artist]. The reversal is the point: these rows
// have the artist in the title field, which is how they were spotted.
const JUNK = {
  '0e45b948-8238-406f-b25f-1fb77a365224': ['The Rolling Stones', 'Sympathy for the Devil'],
  '196a9652-9677-4ec5-8562-c350fc87b12c': ['Status Quo', 'Whatever You Want'],
  '4e5381cd-8dbd-4940-b455-67b00cbcf4f2': ['The Doobie Brothers', "Long Train Runnin'"],
  '87adafbf-b6d6-4562-b17a-006ba986a0d0': ['The Police', 'Message in a Bottle'],
  '8b49b6d7-3903-4357-8cd0-f2f21c49bf3a': ['Supertramp', 'The Logical Song'],
  'a7036d89-8653-4a3b-b183-fbdf78560dcf': ['The Police', 'Roxanne'],
  'e31b49a7-371c-4155-a1c1-b9888910ab45': ['The Eagles', 'Hotel California'],
  '35a6af94-3886-4abc-8f5c-dd4422e24e92': ['song title', 'artists name'],
  'ac946013-4e26-48ef-888c-81277c8da36b': ['my New song', 'berloga bob'],
  '02fc97bd-468b-4fca-bace-705758c94daf': ['Надежда На', ''],
};

// Classifying by STRUCTURE, not by prose phrases. A first attempt listed
// signature phrases and missed "[Dm]Intro [F]continues" because the chord token
// splits the words — the contiguous-tail assertion below is what caught it.
//
// In this song the ten real sections are pure bar notation ("| Dm | F | C | Gm |")
// and the ten fabricated ones are inline-chord prose ("[Dm]First phrase [F]opens").
// So: strip every chord token and separator; if letters remain, it is prose.
//
// NOTE this heuristic is only valid for THIS song, whose genuine content happens
// to be bar notation — real ChordPro lyrics are legitimately inline-bracketed.
// The script touches no other song, and the tail assertion aborts if the shape
// is not what was analysed.
const CHORD_TOKEN =
  /[A-G][#b]?(?:maj|min|sus|dim|aug|add|m|M)?\d*(?:\/[A-G][#b]?)?/g;

function isBarNotationOnly(chart) {
  const remainder = String(chart || '')
    .replace(CHORD_TOKEN, '')
    .replace(/[|\s\-,.()[\]]/g, '');
  return remainder.length === 0;
}

function isFabricated(section) {
  const chart = section.chordChart || '';
  if (chart.trim().length === 0) return false;
  return !isBarNotationOnly(chart);
}

function fail(message) {
  console.error(`\nABORTED: ${message}`);
  console.error('Nothing was written.');
  process.exit(1);
}

async function planDeletions(db, uid) {
  const col = db.collection('users').doc(uid).collection('songs');
  const plan = [];
  for (const [id, [title, artist]] of Object.entries(JUNK)) {
    const doc = await col.doc(id).get();
    if (!doc.exists) fail(`song ${id} does not exist — library has changed since the survey`);
    const data = doc.data();
    const actual = [data.title || '', data.artist || ''];
    if (actual[0] !== title || actual[1] !== artist) {
      fail(`song ${id} is not what we expect.\n  expected: ${JSON.stringify([title, artist])}\n  actual:   ${JSON.stringify(actual)}`);
    }
    // A plain doc delete leaves subcollections behind as orphans — the same
    // failure scripts/check_orphaned_bands.js exists to detect.
    const subs = await doc.ref.listCollections();
    const subCounts = {};
    for (const sub of subs) subCounts[sub.id] = (await sub.get()).size;
    plan.push({ id, title, artist, ref: doc.ref, subCounts });
  }
  return plan;
}

async function planWreckingBall(db, uid) {
  const ref = db.collection('users').doc(uid).collection('songs').doc(WRECKING_BALL_ID);
  const doc = await ref.get();
  if (!doc.exists) fail(`Wrecking Ball ${WRECKING_BALL_ID} not found`);
  const sections = doc.data().sections || [];

  const fabricated = [];
  sections.forEach((section, index) => {
    if (isFabricated(section)) fabricated.push(index);
  });

  if (fabricated.length === 0) {
    return { ref, alreadyClean: true, sections };
  }
  // Must be exactly the tail, or the shape is not what we analysed.
  const expectedTail = Array.from(
    { length: fabricated.length },
    (_, i) => sections.length - fabricated.length + i,
  );
  if (JSON.stringify(fabricated) !== JSON.stringify(expectedTail)) {
    fail(`fabricated Wrecking Ball sections are not a contiguous tail: indices ${fabricated.join(',')} of ${sections.length}`);
  }
  const keep = sections.slice(0, sections.length - fabricated.length);
  if (keep.length === 0) fail('refusing to delete every section of Wrecking Ball');
  return { ref, alreadyClean: false, sections, keep, removeCount: fabricated.length };
}

async function planArtifact(db) {
  const ref = db.collection('canonical_songs').doc(ARTIFACT_CANONICAL_ID);
  const doc = await ref.get();
  if (!doc.exists) return { ref, missing: true };
  const data = doc.data();
  if (data.normalizedTitle || data.normalizedArtist) {
    fail(`${ARTIFACT_CANONICAL_ID} has non-empty normalized fields (${JSON.stringify([data.normalizedTitle, data.normalizedArtist])}) — this is not the empty-normalization artifact`);
  }
  return { ref, missing: false, data };
}

async function main() {
  const uid = DEFAULT_UID;
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });
  const db = admin.firestore();

  console.log(`Library cleanup for ${uid} — ${COMMIT ? 'COMMIT' : 'DRY RUN'}\n`);

  const deletions = await planDeletions(db, uid);
  const wb = await planWreckingBall(db, uid);
  const artifact = await planArtifact(db);

  console.log(`1. DELETE ${deletions.length} junk songs (id + title/artist verified)`);
  for (const d of deletions) {
    const subs = Object.keys(d.subCounts).length
      ? `  [+ subcollections ${JSON.stringify(d.subCounts)} — recursive delete]`
      : '';
    console.log(`   ${d.id.slice(0, 8)}  ${JSON.stringify([d.title, d.artist])}${subs}`);
  }

  console.log('\n2. TRUNCATE Wrecking Ball sections');
  if (wb.alreadyClean) {
    console.log(`   already clean (${wb.sections.length} sections, none fabricated)`);
  } else {
    console.log(`   ${wb.sections.length} -> ${wb.keep.length} sections (removing ${wb.removeCount} fabricated)`);
    console.log(`   keeping:  ${wb.keep.map((s) => s.name).join(', ')}`);
  }

  console.log('\n3. RETIRE canonical artifact');
  if (artifact.missing) {
    console.log(`   ${ARTIFACT_CANONICAL_ID} already gone`);
  } else {
    console.log(`   ${ARTIFACT_CANONICAL_ID}`);
    console.log(`   "${artifact.data.title}" / "${artifact.data.artist}" — normalized fields empty, 0 songs reference it`);
    console.log('   status active -> merged; musicBrainzId/isrc/spotifyId -> null');
    console.log('   (the migration scripts do not filter on status, so the ids must go too)');
  }

  if (!COMMIT) {
    console.log('\nDRY RUN — nothing written. Re-run with --commit to apply.');
    return;
  }

  console.log('\nApplying…');
  for (const d of deletions) {
    if (Object.keys(d.subCounts).length > 0) {
      await db.recursiveDelete(d.ref);
      console.log(`   deleted (recursive) ${d.id.slice(0, 8)}`);
    } else {
      await d.ref.delete();
      console.log(`   deleted ${d.id.slice(0, 8)}`);
    }
  }

  if (!wb.alreadyClean) {
    await wb.ref.set({
      sections: wb.keep,
      updatedAt: new Date().toISOString(),
    }, { merge: true });
    console.log(`   truncated Wrecking Ball to ${wb.keep.length} sections`);
  }

  if (!artifact.missing) {
    await artifact.ref.set({
      status: 'merged',
      musicBrainzId: null,
      isrc: null,
      spotifyId: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log('   retired the canonical artifact');
  }

  console.log('\nDone.');
}

main().catch((error) => {
  console.error(`FAILED: ${error.message}`);
  process.exit(1);
});
