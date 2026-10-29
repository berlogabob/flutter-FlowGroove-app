#!/usr/bin/env node

/**
 * Import a Spotify artist's catalogue into a band, then build a gig setlist with
 * per-song performers.
 *
 * Written for the Roumé album-release show (A fechada, 30 July) but driven by
 * flags, so it works for any artist/band.
 *
 * Song writes go through MCP runTool (create_band_song / update_band_song /
 * enrich_song) rather than touching Firestore directly, so schema validation,
 * section-id generation and the fill-only enrichment rules are exercised for real
 * instead of being reimplemented here.
 *
 * The setlist needs BOTH paths:
 *   - create_setlist_with_songs handles the ordered running order and the break
 *     dividers. It dedups by title|artist, so it reuses the songs imported above
 *     rather than creating duplicates.
 *   - eventDateTime / eventLocation / eventKit.people / items[].performerIds have
 *     NO MCP tool and no update_setlist tool, so they need one direct admin write
 *     afterwards.
 *
 * Guests with no account are EventPerson entries with `uid: null` —
 * lib/models/event_kit.dart documents `uid` as "set once this person is a real
 * app user", which is exactly the add-now-link-later case.
 *
 * Usage:
 *   NODE_PATH=functions/node_modules node scripts/band_import_spotify.js --band <id>
 *   NODE_PATH=functions/node_modules node scripts/band_import_spotify.js --band <id> --commit
 *   ... --skip-enrich   (faster: no MusicBrainz/Deezer/lyrics pass)
 */

const crypto = require('crypto');
const admin = require('firebase-admin');

const PROJECT_ID = 'repsync-app-8685c';
const UID = '7RPi5xPJV5XeTm0SIWubea9DVjJ3';
const ARTIST_ID = '1cZk55CwhWHyupsQSfFFWR';
const ARTIST_NAME = 'Roumé';

const SETLIST_NAME = 'Album release, A fechada // July 30';
const EVENT_DATE = '2026-07-30T21:00:00';
const EVENT_LOCATION = 'A fechada';

// Songs the setlist needs that are not on Spotify. "wake" is the middle of the
// opening medley; "good team" is marked "feat Lee (?)" on the sheet, i.e. still
// tentative. Title + artist only — there is nothing to source.
const MANUAL_SONGS = [
  { title: 'wake', note: 'Not on Spotify — part of the opening medley.' },
  { title: 'good team', note: 'Not on Spotify — unreleased/tentative (feat Lee).' },
];

// The printed running order. Matched to catalogue titles case-insensitively;
// `manual: true` entries come from MANUAL_SONGS.
const RUNNING_ORDER = [
  { divider: 'Medley — meltem / wake / Spill out colours on the snow' },
  { match: 'meltem' },
  { match: 'wake', manual: true },
  { match: 'spill out colours on the snow' },
  { match: 'i woke up angry and scared' },
  { match: 'mountains.clouds.rain' },
  { match: 'heima' },
  { match: 'we are melting snow' },
  { match: 'viento helado' },
  { match: 'i want to tell you my heart' },
  { match: 'chasing horizon' },
  { match: 'ocean and snow' },
  { match: 'passo em falso' },
  { match: 'i come with the rain' },
  { match: 'good team', manual: true },
  { match: 'new home' },
  { match: 'beautiful.dark.unknown' },
  { match: 'neva in winter' },
  { match: 'take me to your shelter' },
];

// Tonight's lineup per song, from the sheet. Deliberately NOT Spotify's recorded
// features (Sol Vk / inês / Ashlele) — different people, different question.
const FEATS = {
  'we are melting snow': ['Maria', 'André'],
  'viento helado': ['Sofia', 'Maria', 'André'],
  'i want to tell you my heart': ['André'],
  'chasing horizon': ['Maria', 'André'],
  'passo em falso': ['Sofia', 'Maria', 'André'],
  'good team': ['Lee'],
  'new home': ['Ashlee'],
  'beautiful.dark.unknown': ['Maria', 'André'],
};

// The Event Kit roster. Roumé plays everything. André is you, so that entry
// carries a real uid; the rest are guests to be linked once they join.
const ROSTER = [
  { name: ARTIST_NAME, role: 'Artist', uid: null, allSongs: true },
  { name: 'André', role: 'Guitar', uid: UID },
  { name: 'Maria', role: 'Guest', uid: null },
  { name: 'Sofia', role: 'Guest', uid: null },
  { name: 'Lee', role: 'Guest', uid: null },
  { name: 'Ashlee', role: 'Guest', uid: null },
];

const COMMIT = process.argv.includes('--commit');
const SKIP_ENRICH = process.argv.includes('--skip-enrich');
const bandIdx = process.argv.indexOf('--band');
const BAND_ID = bandIdx >= 0 ? process.argv[bandIdx + 1] : null;
if (!BAND_ID) {
  console.error('--band <bandId> is required');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

const { runTool } = require('../functions/src/mcp/tools');
const { spotifyCredentials } = require('../functions/src/metadata/credentials');

const norm = (s) => String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();

/**
 * Tag slug that survives accents. Stripping non-[a-z] turned "André" into
 * "andr", giving the tag `feat-andr`. NFD splits the letter from its diacritic
 * so the base letter is kept: "André" -> "andre".
 */
const slug = (s) => String(s || '')
  .normalize('NFD')
  .replace(/[̀-ͯ]/g, '')
  .toLowerCase()
  .replace(/[^a-z0-9]+/g, '');

// --- Spotify ---------------------------------------------------------------

/**
 * Spotify credentials for a LOCAL script.
 *
 * credentials.js resolves secrets from process.env or a bound Cloud Functions
 * secret — neither applies here, and the repo root .env holds only placeholders.
 * So fall back to reading Secret Manager through the firebase CLI, which is where
 * the real values now live. Values are never printed.
 */
function credsFromSecretManager() {
  const { execFileSync } = require('child_process');
  const read = (name) => {
    try {
      return execFileSync('firebase',
        ['functions:secrets:access', name, '--project', PROJECT_ID],
        { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    } catch (_) {
      return '';
    }
  };
  return { clientId: read('SPOTIFY_CLIENT_ID'), clientSecret: read('SPOTIFY_CLIENT_SECRET') };
}

async function spotifyToken() {
  let { clientId, clientSecret } = spotifyCredentials();
  if (!clientId || !clientSecret) {
    ({ clientId, clientSecret } = credsFromSecretManager());
    if (clientId && clientSecret) console.log('(Spotify credentials read from Secret Manager)');
  }
  if (!clientId || !clientSecret) {
    throw new Error('Spotify is not configured — set SPOTIFY_CLIENT_ID/SECRET or store them in Secret Manager');
  }
  const res = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  return (await res.json()).access_token;
}

async function fetchCatalog(token) {
  const H = { Authorization: `Bearer ${token}` };
  const get = async (url) => (await fetch(url, { headers: H })).json();
  // NOTE: the bare albums endpoint only. limit=50 returns "Invalid limit" for
  // this app, and /top-tracks returns 403 (Development mode).
  const albums = (await get(`https://api.spotify.com/v1/artists/${ARTIST_ID}/albums`)).items || [];
  const tracks = [];
  for (const al of albums) {
    const page = await get(`https://api.spotify.com/v1/albums/${al.id}/tracks?limit=20`);
    for (const t of page.items || []) {
      tracks.push({
        title: t.name,
        album: al.name,
        releaseDate: al.release_date,
        spotifyId: t.id,
        durationMs: t.duration_ms,
        artists: (t.artists || []).map((a) => a.name),
      });
    }
  }
  // ISRC only comes back from a full track object, and it must be fetched ONE AT
  // A TIME: the batch /tracks?ids= endpoint returns 403 for this app (another
  // Development-mode restriction), and the first version of this script swallowed
  // that silently — every song imported with isrc undefined.
  let isrcFails = 0;
  for (const t of tracks) {
    const full = await get(`https://api.spotify.com/v1/tracks/${t.spotifyId}`);
    if (full && full.external_ids && full.external_ids.isrc) {
      t.isrc = full.external_ids.isrc;
    } else {
      isrcFails += 1;
    }
  }
  if (isrcFails) console.log(`  (warning: no ISRC for ${isrcFails}/${tracks.length} tracks)`);

  // Same recording released twice (single + album track) shares one ISRC.
  // Importing both makes a confusing duplicate in the band library, so keep the
  // first occurrence — album tracks come first from the albums endpoint.
  const seenIsrc = new Map();
  const deduped = [];
  for (const t of tracks) {
    if (t.isrc && seenIsrc.has(t.isrc)) {
      console.log(`  (duplicate ISRC ${t.isrc}: keeping "${seenIsrc.get(t.isrc)}", skipping "${t.title}" from ${t.album})`);
      continue;
    }
    if (t.isrc) seenIsrc.set(t.isrc, `${t.title} (${t.album})`);
    deduped.push(t);
  }
  return { albums, tracks: deduped };
}

// --- main ------------------------------------------------------------------

async function main() {
  const band = await db.collection('bands').doc(BAND_ID).get();
  if (!band.exists) throw new Error(`band ${BAND_ID} not found`);
  console.log(`Band "${band.data().name}" (${BAND_ID}) — ${COMMIT ? 'COMMIT' : 'DRY RUN'}\n`);

  const token = await spotifyToken();
  const { albums, tracks } = await fetchCatalog(token);
  console.log(`Spotify: ${albums.length} releases, ${tracks.length} tracks`);
  albums.forEach((a) => console.log(`  ${a.album_type.padEnd(7)} ${a.release_date}  ${a.name}`));

  const plannedTitles = [...tracks.map((t) => t.title), ...MANUAL_SONGS.map((m) => m.title)];
  console.log(`\nSongs to import: ${plannedTitles.length} (${tracks.length} from Spotify + ${MANUAL_SONGS.length} manual)`);

  // Resolve the running order against what we are about to have.
  console.log('\nRunning order:');
  const resolved = [];
  let n = 0;
  for (const step of RUNNING_ORDER) {
    if (step.divider) {
      resolved.push({ divider: step.divider });
      console.log(`  ──  ${step.divider}`);
      continue;
    }
    const want = norm(step.match);
    const hit = plannedTitles.find((t) => norm(t).includes(want) || want.includes(norm(t)));
    if (!hit) throw new Error(`running order entry "${step.match}" matches no song — aborting`);
    n += 1;
    resolved.push({ title: hit, feats: FEATS[step.match] || null });
    console.log(`  ${String(n).padStart(2)}. ${hit.slice(0, 56).padEnd(58)}${(FEATS[step.match] || []).join(', ')}`);
  }

  console.log(`\nEvent: ${EVENT_DATE} @ ${EVENT_LOCATION}`);
  console.log('Roster:');
  ROSTER.forEach((p) => console.log(`  ${p.name.padEnd(8)} ${p.role.padEnd(8)} ${p.uid ? 'uid ' + p.uid.slice(0, 10) + '…' : 'guest — link later'}`));

  if (!COMMIT) {
    console.log('\nDRY RUN — nothing written. Re-run with --commit to apply.');
    return;
  }

  // 1. Import songs -------------------------------------------------------
  console.log('\n[1/4] Importing songs…');
  const created = [];
  for (const t of tracks) {
    const q = encodeURIComponent(`${ARTIST_NAME} ${t.title}`);
    const out = await runTool(db, UID, 'write', 'create_band_song', {
      bandId: BAND_ID,
      song: {
        title: t.title,
        artist: ARTIST_NAME,
        album: t.album,
        durationMs: t.durationMs,
        spotifyId: t.spotifyId,
        spotifyUrl: `https://open.spotify.com/track/${t.spotifyId}`,
        ...(t.isrc ? { isrc: t.isrc } : {}),
        links: [
          { type: 'other', title: 'Spotify', url: `https://open.spotify.com/track/${t.spotifyId}` },
          { type: 'youtube_original', title: 'YouTube', url: `https://www.youtube.com/results?search_query=${q}` },
          { type: 'chords', title: 'Chords', url: `https://www.ultimate-guitar.com/search.php?search_type=title&value=${q}` },
        ],
      },
    });
    if (out.error) { console.log(`   ! ${t.title}: ${out.error}`); continue; }
    created.push({ id: out.result.id, title: t.title });
  }
  for (const m of MANUAL_SONGS) {
    const out = await runTool(db, UID, 'write', 'create_band_song', {
      bandId: BAND_ID,
      song: { title: m.title, artist: ARTIST_NAME, notes: m.note },
    });
    if (out.error) { console.log(`   ! ${m.title}: ${out.error}`); continue; }
    created.push({ id: out.result.id, title: m.title });
  }
  console.log(`   created ${created.length} band songs`);

  // 2. Enrich -------------------------------------------------------------
  if (SKIP_ENRICH) {
    console.log('\n[2/4] Enrichment skipped (--skip-enrich)');
  } else {
    console.log('\n[2/4] Enriching (MusicBrainz 1 req/sec — this takes a few minutes)…');
    let enriched = 0;
    for (const s of created) {
      const out = await runTool(db, UID, 'write', 'enrich_song', { id: s.id, bandId: BAND_ID });
      if (!out.error && out.result.found && (out.result.applied || []).length) enriched += 1;
    }
    console.log(`   enriched ${enriched}/${created.length}`);
  }

  // 3. Setlist ------------------------------------------------------------
  console.log('\n[3/4] Creating the setlist…');
  const entries = resolved.map((r) => (r.divider
    ? { type: 'break', breakType: 'custom', label: r.divider }
    : { title: r.title, artist: ARTIST_NAME }));
  const slOut = await runTool(db, UID, 'write', 'create_setlist_with_songs', {
    bandId: BAND_ID,
    name: SETLIST_NAME,
    description: buildDescription(resolved),
    entries,
  });
  if (slOut.error) throw new Error(`setlist: ${slOut.error}`);
  const setlistId = slOut.result.id;
  console.log(`   setlist ${setlistId}  created=${slOut.result.songsCreated} updated=${slOut.result.songsUpdated} breaks=${slOut.result.breaks}`);

  // 4. Event Kit + performers (no MCP tool writes these) ------------------
  console.log('\n[4/4] Writing Event Kit roster + per-song performers…');
  const people = ROSTER.map((p) => ({
    id: crypto.randomUUID(),
    name: p.name,
    role: p.role,
    ...(p.uid ? { uid: p.uid } : {}),
  }));
  const idByName = Object.fromEntries(people.map((p, i) => [ROSTER[i].name, p.id]));
  const everyone = ROSTER.filter((p) => p.allSongs).map((p) => idByName[p.name]);

  const slRef = db.collection('bands').doc(BAND_ID).collection('setlists').doc(setlistId);
  const slDoc = await slRef.get();
  const items = (slDoc.data().items || []).map((item) => {
    if (!item.songId) return item;   // divider
    const match = resolved.find((r) => r.title && lookupId(created, r.title) === item.songId);
    const feats = (match && match.feats) || [];
    const ids = [...everyone, ...feats.map((f) => idByName[f]).filter(Boolean)];
    return ids.length ? { ...item, performerIds: ids } : item;
  });

  await slRef.set({
    eventDateTime: EVENT_DATE,
    eventLocation: EVENT_LOCATION,
    eventKit: { stage: {}, people, rider: [] },
    items,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  const withPerformers = items.filter((i) => (i.performerIds || []).length).length;
  console.log(`   roster ${people.length} people; performerIds set on ${withPerformers} items`);

  // 5. Feat credits onto the songs themselves ----------------------------
  console.log('\n[5/5] Feat credits into song notes + tags…');
  let tagged = 0;
  for (const r of resolved) {
    if (!r.title || !r.feats) continue;
    const id = lookupId(created, r.title);
    if (!id) continue;
    const out = await runTool(db, UID, 'write', 'update_band_song', {
      bandId: BAND_ID,
      id,
      song: {
        notes: `Live 30 Jul (${EVENT_LOCATION}): feat ${r.feats.join(', ')}`,
        tags: r.feats.map((f) => `feat-${slug(f)}`),
      },
    });
    if (!out.error) tagged += 1;
  }
  console.log(`   annotated ${tagged} songs`);

  console.log(`\nDone.\n  BAND_ID=${BAND_ID}\n  SETLIST_ID=${setlistId}\n  invite code: ${band.data().inviteCode}`);
}

function lookupId(created, title) {
  const hit = created.find((c) => norm(c.title) === norm(title));
  return hit ? hit.id : null;
}

function buildDescription(resolved) {
  const lines = ['Album release show — A fechada, 30 July.', '', 'Tonight\'s lineup:'];
  let n = 0;
  for (const r of resolved) {
    if (r.divider) { lines.push(`   -- ${r.divider}`); continue; }
    n += 1;
    lines.push(`${String(n).padStart(2)}. ${r.title}${r.feats ? `  // feat ${r.feats.join(', ')}` : ''}`);
  }
  lines.push('', `${ARTIST_NAME} performs all songs. Guests are in the Event Kit roster and can be linked to accounts once they join.`);
  return lines.join('\n');
}

main().catch((error) => {
  console.error(`FAILED: ${error.message}`);
  process.exit(1);
});
