#!/usr/bin/env node

/**
 * Stage 5.4 — enrich every live song through the MCP enrich_song tool.
 *
 * Deliberately drives runTool() rather than writing Firestore directly: this is
 * the exact code path an agent takes, so the fill-only rule, the sections
 * append-guard and the flat-vs-linked routing are all exercised for real instead
 * of being reimplemented (and drifting) in a script.
 *
 * Writes ONLY source-backed data. Model-supplied key and chords are a separate
 * script (library_keys.js) so the two provenances never blur together.
 *
 * Fill-only means a value already present is never overwritten. That is what
 * protects the hand-set BPMs (98 for Sweet Home Alabama, 109 for I Want to Break
 * Free) from Deezer, which reports 196 for the former.
 *
 * Run AFTER library_canonicals.js: the flat songs need the ids written here to
 * match canonicals that already exist, and the migration re-checks
 * canonicalRevision against a report generated after the canonical repair.
 *
 * Usage:
 *   NODE_PATH=functions/node_modules node scripts/library_enrich.js
 *   NODE_PATH=functions/node_modules node scripts/library_enrich.js --commit
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

const { runTool } = require('../functions/src/mcp/tools');
const { resolveTrack } = require('../functions/src/metadata/resolver');
const { spotifyCredentials, isSpotifyConfigured } = require('../functions/src/metadata/credentials');

const SOURCED_FIELDS = [
  'musicbrainzId', 'isrc', 'album', 'durationMs', 'originalBPM', 'links', 'sections',
];

// A linked (schemaVersion 2) song can only carry the delta fields; everything
// else belongs to its canonical. Mirrored from DELTA_FIELDS in
// functions/src/mcp/tools.js so the dry run predicts what enrich_song will
// actually do instead of over-promising.
const DELTA_FIELDS = ['ourKey', 'ourBPM', 'notes', 'tags', 'links', 'sections'];

async function main() {
  if (!isSpotifyConfigured()) {
    console.error('Spotify is not configured — album/ISRC/duration would be blank.');
    process.exit(1);
  }

  console.log(`Song enrichment for ${DEFAULT_UID} — ${COMMIT ? 'COMMIT' : 'DRY RUN'}\n`);

  const snap = await db.collection('users').doc(DEFAULT_UID).collection('songs').get();
  const live = snap.docs
    .map((d) => ({ id: d.id, data: d.data() }))
    .filter((s) => !s.data.deletedAt);

  // In dry-run the resolver still runs (so coverage is real) but enrich_song is
  // never called, so nothing is written.
  const resolveOnce = (query) =>
    resolveTrack(query, { spotifyCredentials: spotifyCredentials() });

  const rows = [];
  for (const song of live) {
    const fields = song.data.schemaVersion === 2 ? (song.data.materialized || {}) : song.data;
    const title = fields.title || '';
    const artist = fields.artist || '';
    const linked = song.data.schemaVersion === 2 && !!song.data.canonicalSongId;
    if (!title) {
      rows.push({ id: song.id, title, artist, linked, error: 'no title' });
      continue;
    }

    if (!COMMIT) {
      const resolved = await resolveOnce({ title, artist });
      const wouldFill = SOURCED_FIELDS.filter((f) => {
        // Canonical-owned on a linked song — enrich_song reports these under
        // `skipped`, not `applied`.
        if (linked && !DELTA_FIELDS.includes(f)) return false;
        const current = fields[f];
        const blank = current === null || current === undefined ||
          (typeof current === 'string' && !current.trim()) ||
          (Array.isArray(current) && current.length === 0);
        if (!blank) return false;
        if (f === 'links') return resolved.found;
        if (f === 'sections') return Array.isArray(resolved.sections) && resolved.sections.length > 0;
        if (f === 'originalBPM') return resolved.bpm != null;
        if (f === 'musicbrainzId') return !!resolved.musicBrainzId;
        return resolved[f] != null;
      });
      rows.push({
        id: song.id, title, artist, linked,
        found: resolved.found, wouldFill,
        sources: Object.keys(resolved.sources || {}).length,
      });
      continue;
    }

    const out = await runTool(db, DEFAULT_UID, 'write', 'enrich_song', { id: song.id });
    if (out.error) {
      rows.push({ id: song.id, title, artist, linked, error: out.error });
      continue;
    }
    rows.push({
      id: song.id, title, artist, linked,
      found: out.result.found,
      applied: out.result.applied,
      skipped: out.result.skipped,
      canonicalFields: out.result.canonicalFields,
      sources: Object.keys(out.result.sources || {}).length,
    });
  }

  // --- report ---------------------------------------------------------------
  const label = COMMIT ? 'applied' : 'wouldFill';
  console.log(`${'song'.padEnd(42)} ${'lnk'} ${'found'} ${label}`);
  console.log('-'.repeat(100));
  for (const r of rows) {
    const name = `${r.title} / ${r.artist}`.slice(0, 41);
    if (r.error) {
      console.log(`${name.padEnd(42)}  -   ERROR  ${r.error}`);
      continue;
    }
    const fields = (COMMIT ? r.applied : r.wouldFill) || [];
    console.log(`${name.padEnd(42)} ${r.linked ? 'v2 ' : ' - '} ${r.found ? ' yes ' : ' NO  '} ${fields.join(', ') || '(nothing)'}`);
  }

  const notFound = rows.filter((r) => !r.error && !r.found);
  if (notFound.length > 0) {
    console.log(`\nNO METADATA MATCH (${notFound.length}) — left untouched:`);
    notFound.forEach((r) => console.log(`  ${r.title} / ${r.artist}`));
  }

  if (COMMIT) {
    console.log('\n=== per-field coverage ===');
    for (const field of SOURCED_FIELDS) {
      const applied = rows.filter((r) => (r.applied || []).includes(field)).length;
      const skipped = rows.filter((r) => r.skipped && r.skipped[field]).length;
      console.log(`  ${field.padEnd(14)} written ${String(applied).padStart(2)}   skipped ${String(skipped).padStart(2)}`);
    }
    const reasons = {};
    rows.forEach((r) => {
      Object.values(r.skipped || {}).forEach((why) => { reasons[why] = (reasons[why] || 0) + 1; });
    });
    console.log('\n  skip reasons:');
    Object.entries(reasons).sort((a, b) => b[1] - a[1])
      .forEach(([why, n]) => console.log(`    ${String(n).padStart(3)}  ${why}`));

    const pending = rows.filter((r) => r.canonicalFields && Object.keys(r.canonicalFields).length > 0);
    if (pending.length > 0) {
      console.log(`\n  ${pending.length} songs reported canonicalFields (already applied in 5.3)`);
    }
  } else {
    console.log('\nDRY RUN — nothing written. Re-run with --commit to apply.');
  }
}

main().catch((error) => {
  console.error(`FAILED: ${error.message}`);
  process.exit(1);
});
