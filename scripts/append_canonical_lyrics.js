#!/usr/bin/env node

/**
 * One-off: append canonical lyrics (from lyrics.ovh, the app's own lyric API) to
 * the songs of the "23/07 MAIN COURSE" setlist in band "super AG2700".
 *
 * APPEND-ONLY: existing chord sections (Грув/Припев...) and song `notes` are read
 * and written back byte-for-byte; lyric stanzas are appended AFTER them as new
 * `Verse N` / `Chorus` sections. Stanza→label logic mirrors
 * lib/utils/lyrics_sections.dart. Idempotent: a song that already has an English
 * lyric section (Verse/Chorus/Bridge/Lyrics) is skipped.
 *
 * Usage (creds via gcloud ADC or GOOGLE_APPLICATION_CREDENTIALS):
 *   NODE_PATH=functions/node_modules node scripts/append_canonical_lyrics.js          # dry run
 *   NODE_PATH=functions/node_modules node scripts/append_canonical_lyrics.js --commit # write
 */

const admin = require('firebase-admin');
const crypto = require('crypto');

const BAND_ID = '31384e08-b57f-40e4-81e4-e8b7cb024b82';
const SETLIST_ID = '1d8cd0d5-ec0e-4c1b-a9aa-4eba4aa04ff6';
const COMMIT = process.argv.includes('--commit');
const LYRIC_LABEL = /^(verse|chorus|bridge|lyrics)\b/i; // "already done" marker

// Songs lyrics.ovh has but only under a different artist/title spelling.
// Keyed by the DB title normalised to A-Z0-9 (apostrophes/case/spacing-agnostic).
const normKey = (s) => (s || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
const QUERY_OVERRIDES = {
  KNOCKINGONHEAVENSDOOR: ['Bob Dylan', 'Knockin on Heavens Door'],
  GIRLYOULLBEAWOMANSOON: ['Neil Diamond', 'Girl Youll Be A Woman Soon'],
  IMNOTYOURSTEPPINGSTONE: ['The Monkees', 'Im Not Your Steppin Stone'],
  THATSALRIGHTMA: ['Elvis Presley', 'Thats All Right'],
};

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Mirror of lib/utils/lyrics_sections.dart lyricsToSections().
function lyricsToSections(lyrics) {
  const stanzas = lyrics
    .split(/\n[ \t]*\n/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  if (stanzas.length === 0) return [];

  const counts = {};
  for (const s of stanzas) counts[s] = (counts[s] || 0) + 1;

  const out = [];
  const chorusLabel = {};
  let verseNo = 0;
  let chorusNo = 0;
  for (const s of stanzas) {
    let name;
    if (counts[s] > 1) {
      if (chorusLabel[s] === undefined) {
        chorusNo++;
        chorusLabel[s] = chorusNo === 1 ? 'Chorus' : `Chorus ${chorusNo}`;
      }
      name = chorusLabel[s];
    } else {
      verseNo++;
      name = `Verse ${verseNo}`;
    }
    out.push({ name, chart: s });
  }
  return out;
}

async function fetchLyrics(artist, title) {
  const tryOnce = async (a, t) => {
    const url = `https://api.lyrics.ovh/v1/${encodeURIComponent(a)}/${encodeURIComponent(t)}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(20000) });
    if (!res.ok) return null;
    const body = await res.json().catch(() => null);
    const lyrics = body && typeof body.lyrics === 'string' ? body.lyrics.trim() : '';
    return lyrics.length > 0 ? lyrics : null;
  };
  // lyrics.ovh returns literal "\r\n"; normalise to \n for stanza splitting.
  const norm = (s) => (s ? s.replace(/\r\n/g, '\n') : s);
  // Strip all punctuation (keep spaces) — lyrics.ovh matches many titles only
  // without apostrophes/periods/commas (Knockin', R.E.M., etc.).
  const clean = (s) => s.replace(/[^\p{L}\p{N} ]/gu, ' ').replace(/\s+/g, ' ').trim();
  const override = QUERY_OVERRIDES[normKey(title)];
  return (
    (override && norm(await tryOnce(override[0], override[1]))) ||
    norm(await tryOnce(artist, title)) ||
    norm(await tryOnce(artist.toLowerCase(), title.toLowerCase())) ||
    norm(await tryOnce(clean(artist), clean(title)))
  );
}

async function main() {
  const setlistRef = db.doc(`bands/${BAND_ID}/setlists/${SETLIST_ID}`);
  const setlistSnap = await setlistRef.get();
  if (!setlistSnap.exists) throw new Error(`Setlist ${SETLIST_ID} not found`);
  const setlist = setlistSnap.data();

  const items = Array.isArray(setlist.items) ? setlist.items : [];
  let songIds = items
    .filter((it) => it && it.type !== 'break' && it.songId)
    .map((it) => it.songId);
  if (songIds.length === 0 && Array.isArray(setlist.songIds)) songIds = setlist.songIds;

  console.log(`Setlist "${setlist.name}" — ${songIds.length} songs. ${COMMIT ? 'COMMIT' : 'DRY RUN'}\n`);

  const skippedNoLyrics = [];
  const skippedDone = [];
  let updated = 0;

  for (const songId of songIds) {
    const ref = db.doc(`bands/${BAND_ID}/songs/${songId}`);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`  ⚠️  ${songId} — song doc missing`);
      continue;
    }
    const song = snap.data();
    const label = `${song.title} — ${song.artist}`;
    const sections = Array.isArray(song.sections) ? song.sections : [];

    if (sections.some((s) => s && typeof s.name === 'string' && LYRIC_LABEL.test(s.name))) {
      console.log(`  ⏭  ${label} — already has lyric sections, skip`);
      skippedDone.push(label);
      continue;
    }

    const lyrics = await fetchLyrics(song.artist || '', song.title || '');
    await sleep(200);
    if (!lyrics) {
      console.log(`  ❌ ${label} — no lyrics on lyrics.ovh`);
      skippedNoLyrics.push(label);
      continue;
    }

    const parts = lyricsToSections(lyrics);
    const lyricSections = parts.map((p) => ({
      id: crypto.randomUUID(),
      name: p.name,
      notes: '',
      duration: 1,
      chordChart: p.chart,
    }));
    const verses = parts.filter((p) => /^Verse/.test(p.name)).length;
    const choruses = parts.length - verses;
    console.log(`  ✅ ${label} — +${parts.length} sections (Verse×${verses}, Chorus×${choruses})`);

    if (COMMIT) {
      await ref.update({
        sections: [...sections, ...lyricSections],
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      updated++;
    }
  }

  console.log(`\nSummary: ${COMMIT ? `${updated} updated` : `${songIds.length - skippedDone.length - skippedNoLyrics.length} would update`}, ` +
    `${skippedDone.length} already done, ${skippedNoLyrics.length} no lyrics.`);
  if (skippedNoLyrics.length) {
    console.log('No lyrics found (need manual handling):');
    for (const s of skippedNoLyrics) console.log(`  - ${s}`);
  }
  if (!COMMIT) console.log('\nDry run — re-run with --commit to write.');
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
