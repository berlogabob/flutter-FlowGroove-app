#!/usr/bin/env node

/**
 * Stage 5.3 — repair every active canonical song and create the ones the
 * library is missing, so the flat songs have something to link to in 5.5.
 *
 * Why this is a script and not the updateCanonicalSong callable: the callable
 * limits overwriting to the canonical's creator, deliberately, because one
 * canonical is shared by every band that links to it. Three of the wrong entries
 * were created by other accounts (two by the demo user). This runs admin-side to
 * repair them, using the SAME validator the callable uses (canonicalUpdatePatch)
 * so the field whitelist and range checks cannot drift apart.
 *
 * What gets filled: album, releaseYear, durationMs, isrc, musicBrainzId,
 * musicBrainzWorkId, iswc.
 *
 * What deliberately does NOT: baseKey and baseBpm stay null. Deezer reports
 * double-time BPM for some tracks (196 against a true ~98 for Sweet Home
 * Alabama); baking that into a shared canonical would propagate a wrong tempo to
 * every future import of the song. Songs keep their own BPM.
 *
 * Ordering matters — this bumps canonicalRevision, and the migration write-run
 * re-verifies it per candidate. Run this BEFORE the 5.5 dry-run, or every
 * candidate is skipped as canonicalRevisionMismatch.
 *
 * Usage:
 *   NODE_PATH=functions/node_modules node scripts/library_canonicals.js
 *   NODE_PATH=functions/node_modules node scripts/library_canonicals.js --commit
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

// Required AFTER initializeApp: canonical.js builds its own firestore handle at
// module load and guards on admin.apps.length.
const { canonicalUpdatePatch, canonicalSongIdFor, normalize } = require('../functions/src/canonical');
const { resolveTrack } = require('../functions/src/metadata/resolver');
const { spotifyCredentials, isSpotifyConfigured } = require('../functions/src/metadata/credentials');

// The migration's externalIdsFromSong lowercases MBIDs and uppercases/strips
// ISRCs, but queries the canonical side with a raw ==. So the canonical side has
// to already be in that shape or nothing will ever match.
const normalizeMbid = (v) => (typeof v === 'string' ? v.trim().toLowerCase() : null) || null;
const normalizeIsrc = (v) =>
  (typeof v === 'string' ? v.replace(/[^a-z0-9]/gi, '').toUpperCase() : null) || null;

const resolveCache = new Map();
async function resolveOnce(title, artist) {
  const key = `${normalize(title)}|${normalize(artist)}`;
  if (resolveCache.has(key)) return resolveCache.get(key);
  // Canonicals store no sections and no BPM, so skip those two providers.
  const resolved = await resolveTrack({ title, artist }, {
    spotifyCredentials: spotifyCredentials(),
    skip: ['lyrics', 'deezer'],
  });
  resolveCache.set(key, resolved);
  return resolved;
}

function canonicalPatchFrom(resolved) {
  return {
    album: resolved.album,
    releaseYear: resolved.releaseYear,
    durationMs: resolved.durationMs,
    isrc: normalizeIsrc(resolved.isrc),
    musicBrainzId: normalizeMbid(resolved.musicBrainzId),
    musicBrainzWorkId: resolved.musicBrainzWorkId,
    iswc: resolved.iswc,
  };
}

function isActive(data) {
  return ((data || {}).status || 'active') === 'active';
}

/** Find an existing canonical for a resolved track: MBID, then ISRC, then id. */
async function findCanonical(resolved, activeCanonicals) {
  const mbid = normalizeMbid(resolved.musicBrainzId);
  const isrc = normalizeIsrc(resolved.isrc);
  if (mbid) {
    const hit = activeCanonicals.find((c) => normalizeMbid(c.data.musicBrainzId) === mbid);
    if (hit) return hit;
  }
  if (isrc) {
    const hit = activeCanonicals.find((c) => normalizeIsrc(c.data.isrc) === isrc);
    if (hit) return hit;
  }
  const id = canonicalSongIdFor(normalize(resolved.title), normalize(resolved.artist));
  return activeCanonicals.find((c) => c.id === id) || null;
}

async function main() {
  if (!isSpotifyConfigured()) {
    console.error('Spotify is not configured — album/releaseYear/ISRC would all be blank.');
    console.error('Export SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET and re-run.');
    process.exit(1);
  }

  console.log(`Canonical repair + create — ${COMMIT ? 'COMMIT' : 'DRY RUN'}\n`);

  const canonicalSnap = await db.collection('canonical_songs').get();
  const canonicals = canonicalSnap.docs.map((d) => ({ id: d.id, ref: d.ref, data: d.data() }));
  const active = canonicals.filter((c) => isActive(c.data));
  console.log(`canonical_songs: ${canonicals.length} (${active.length} active)`);

  const songsSnap = await db.collection('users').doc(DEFAULT_UID).collection('songs').get();
  const live = songsSnap.docs
    .map((d) => ({ id: d.id, data: d.data() }))
    .filter((s) => !s.data.deletedAt);
  console.log(`live songs: ${live.length}\n`);

  const repairs = [];
  const creates = [];
  const unresolved = [];

  // Pass A — repair every active canonical from its own title/artist.
  console.log('Resolving canonicals…');
  for (const canonical of active) {
    const resolved = await resolveOnce(canonical.data.title, canonical.data.artist);
    if (!resolved.found) {
      unresolved.push(`canonical ${canonical.id} "${canonical.data.title}" / "${canonical.data.artist}"`);
      continue;
    }
    const { changes, warnings } = canonicalUpdatePatch(
      canonical.data, canonicalPatchFrom(resolved), { overwrite: true },
    );
    if (Object.keys(changes).length > 0) {
      repairs.push({ canonical, changes, warnings, resolved });
    }
  }

  // Pass B — create canonicals for live songs that have none.
  console.log('Resolving songs without a canonical…');
  const seenNewIds = new Set();
  for (const song of live) {
    if (song.data.canonicalSongId) continue;
    const title = song.data.title || '';
    const artist = song.data.artist || '';
    if (!title) continue;
    const resolved = await resolveOnce(title, artist);
    if (!resolved.found) {
      unresolved.push(`song ${song.id.slice(0, 8)} "${title}" / "${artist}"`);
      continue;
    }
    const existing = await findCanonical(resolved, active);
    if (existing) {
      const { changes } = canonicalUpdatePatch(
        existing.data, canonicalPatchFrom(resolved), { overwrite: true },
      );
      if (Object.keys(changes).length > 0 && !repairs.some((r) => r.canonical.id === existing.id)) {
        repairs.push({ canonical: existing, changes, warnings: [], resolved });
      }
      continue;
    }
    const normTitle = normalize(resolved.title);
    const normArtist = normalize(resolved.artist);
    if (!normTitle || !normArtist) {
      unresolved.push(`song ${song.id.slice(0, 8)} normalizes to empty — refusing to create a collision magnet`);
      continue;
    }
    const id = canonicalSongIdFor(normTitle, normArtist);
    if (seenNewIds.has(id)) continue; // two songs resolving to one canonical
    seenNewIds.add(id);
    creates.push({ id, song, resolved, normTitle, normArtist });
  }

  console.log(`\n=== REPAIR ${repairs.length} canonicals ===`);
  for (const r of repairs) {
    console.log(`  ${r.canonical.data.title} / ${r.canonical.data.artist}`);
    for (const [field, value] of Object.entries(r.changes)) {
      const before = r.canonical.data[field];
      console.log(`     ${field}: ${JSON.stringify(before)} -> ${JSON.stringify(value)}`);
    }
  }

  console.log(`\n=== CREATE ${creates.length} canonicals ===`);
  for (const c of creates) {
    const p = canonicalPatchFrom(c.resolved);
    console.log(`  ${c.resolved.title} / ${c.resolved.artist}`);
    console.log(`     id ${c.id}`);
    console.log(`     album=${JSON.stringify(p.album)} year=${p.releaseYear} isrc=${p.isrc} mbid=${p.musicBrainzId ? 'yes' : 'NONE'} iswc=${p.iswc || '-'}`);
  }

  if (unresolved.length > 0) {
    console.log(`\n=== UNRESOLVED ${unresolved.length} (left untouched) ===`);
    unresolved.forEach((u) => console.log(`  ${u}`));
  }

  if (!COMMIT) {
    console.log('\nDRY RUN — nothing written. Re-run with --commit to apply.');
    return;
  }

  console.log('\nApplying…');
  const now = admin.firestore.FieldValue.serverTimestamp();
  for (const r of repairs) {
    await r.canonical.ref.set({
      ...r.changes,
      canonicalRevision: (r.canonical.data.canonicalRevision || 1) + 1,
      updatedAt: now,
    }, { merge: true });
    console.log(`  repaired ${r.canonical.data.title}`);
  }
  for (const c of creates) {
    const p = canonicalPatchFrom(c.resolved);
    await db.collection('canonical_songs').doc(c.id).set({
      id: c.id,
      title: c.resolved.title,
      artist: c.resolved.artist,
      artists: [c.resolved.artist],
      album: p.album,
      releaseYear: p.releaseYear,
      durationMs: p.durationMs,
      isrc: p.isrc,
      spotifyId: c.resolved.spotifyId || null,
      musicBrainzId: p.musicBrainzId,
      musicBrainzWorkId: p.musicBrainzWorkId,
      iswc: p.iswc,
      normalizedTitle: c.normTitle,
      normalizedArtist: c.normArtist,
      genres: [],
      disambiguation: c.resolved.disambiguation || null,
      schemaVersion: 1,
      canonicalRevision: 1,
      source: p.musicBrainzId ? 'musicbrainz' : (c.resolved.spotifyId ? 'spotify' : 'manual'),
      status: 'active',
      createdBy: DEFAULT_UID,
      // Left null on purpose: see the header note on double-time BPM.
      baseKey: null,
      baseBpm: null,
      baseSections: [],
      baseAccentBeats: 4,
      baseRegularBeats: 1,
      baseBeatModes: [],
      baseLinks: [],
      createdAt: now,
      updatedAt: now,
    });
    console.log(`  created ${c.resolved.title}`);
  }

  await assertInvariants();
}

/**
 * The migration matches on a raw == against the canonical side, so a stray
 * uppercase MBID or hyphenated ISRC silently links nothing. And two active
 * canonicals sharing an external id makes every candidate ambiguous.
 */
async function assertInvariants() {
  console.log('\n=== post-write invariants ===');
  const snap = await db.collection('canonical_songs').get();
  const active = snap.docs.filter((d) => isActive(d.data()));
  const problems = [];
  const byMbid = new Map();
  const byIsrc = new Map();

  for (const doc of active) {
    const data = doc.data();
    const mbid = data.musicBrainzId;
    const isrc = data.isrc;
    if (mbid && mbid !== mbid.toLowerCase()) problems.push(`${doc.id}: musicBrainzId not lowercase (${mbid})`);
    if (isrc && isrc !== isrc.replace(/[^a-z0-9]/gi, '').toUpperCase()) {
      problems.push(`${doc.id}: isrc not uppercase-alnum (${isrc})`);
    }
    if (mbid) byMbid.set(mbid, [...(byMbid.get(mbid) || []), doc.id]);
    if (isrc) byIsrc.set(isrc, [...(byIsrc.get(isrc) || []), doc.id]);
  }
  for (const [mbid, ids] of byMbid) {
    if (ids.length > 1) problems.push(`MBID ${mbid} shared by ${ids.join(', ')}`);
  }
  for (const [isrc, ids] of byIsrc) {
    if (ids.length > 1) problems.push(`ISRC ${isrc} shared by ${ids.join(', ')}`);
  }

  console.log(`  active canonicals: ${active.length}`);
  console.log(`  with musicBrainzId: ${byMbid.size}   with isrc: ${byIsrc.size}`);
  if (problems.length === 0) {
    console.log('  OK — ids are correctly shaped and unique; the migration can match on them');
  } else {
    console.log('  PROBLEMS:');
    problems.forEach((p) => console.log(`    ${p}`));
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(`FAILED: ${error.message}`);
  process.exit(1);
});
