// Seed demo bands/songs/setlists via Firestore REST commit.
// Usage: TOKEN=$(gcloud auth print-access-token) node seed.js
const PROJECT = 'repsync-app-8685c';
const BASE = `projects/${PROJECT}/databases/(default)/documents`;
const UID = 'lePjILMinYV4A0UFbg5qePv6VBg2';
const NOW = '2026-07-03T12:00:00.000'; // app stores local ISO strings

const toValue = (v) => {
  if (v === null) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (Number.isInteger(v)) return { integerValue: String(v) };
  if (typeof v === 'number') return { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  return { mapValue: { fields: toFields(v) } };
};
const toFields = (obj) =>
  Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, toValue(v)]));

const member = {
  uid: UID, role: 'admin', displayName: 'demo',
  email: 'demo@flowgroove.app', musicRoles: [],
};
const band = (id, name, description, tags, inviteCode) => ({
  id, name, description, tags, inviteCode,
  photoURL: null, createdAt: NOW, createdBy: UID,
  memberUids: [UID], adminUids: [UID], editorUids: [],
  members: [member],
});

// Band-song copy of a personal demo song (mirrors _copySongForBand).
const song = (id, bandId, srcId, title, artist, bpm, key, tags) => ({
  id, bandId, title, artist, tags,
  originalBPM: bpm, ourBPM: bpm, originalKey: key, ourKey: key,
  accentBeats: 4, regularBeats: 1, beatModes: {},
  album: null, notes: null, links: [], sections: [],
  spotifyId: null, spotifyUrl: null, isFromMusicBrainz: false,
  isCopy: srcId !== null, contributedBy: 'demo', contributedAt: NOW,
  originalOwnerId: srcId ? UID : null, originalSongId: srcId,
  createdAt: NOW, updatedAt: NOW,
});

const setlist = (id, bandId, name, description, location, when, songIds) => ({
  id, bandId, name, description,
  eventLocation: location, eventDateTime: when,
  songIds, items: songIds.map((s, i) => ({ id: `${id}-item-${i + 1}`, songId: s })),
  assignments: {}, totalDuration: null, createdAt: NOW, updatedAt: NOW,
});

const CC = 'd7d59480-5aa0-413c-b579-bbcb76933b1f'; // The Cover Collective (exists)
const B2 = 'demo-band-02';
const B3 = 'demo-band-03';

const docs = {
  [`bands/${B2}`]: band(B2, 'Funk Foundry',
    'Funk and soul covers with a horn-section attitude.', ['funk', 'soul', 'covers'], 'FNKFRY'),
  [`bands/${B3}`]: band(B3, 'Indie Echoes',
    'Indie and britpop anthems for club nights.', ['indie', 'rock', 'britpop'], 'INDECH'),

  [`bands/${CC}/songs/demo-cc-song-01`]: song('demo-cc-song-01', CC, 'demo-song-01', "Sweet Child O' Mine", "Guns N' Roses", 125, 'D', ['rock', 'classic rock']),
  [`bands/${CC}/songs/demo-cc-song-02`]: song('demo-cc-song-02', CC, 'demo-song-02', 'Billie Jean', 'Michael Jackson', 117, 'F#m', ['pop', '80s']),
  [`bands/${CC}/songs/demo-cc-song-03`]: song('demo-cc-song-03', CC, 'demo-song-06', "Don't Stop Believin'", 'Journey', 119, 'E', ['rock', '80s']),

  [`bands/${B2}/songs/demo-b02-song-01`]: song('demo-b02-song-01', B2, 'demo-song-04', 'Uptown Funk', 'Mark Ronson ft. Bruno Mars', 115, 'Dm', ['funk', 'pop']),
  [`bands/${B2}/songs/demo-b02-song-02`]: song('demo-b02-song-02', B2, 'demo-song-08', 'Superstition', 'Stevie Wonder', 100, 'Eb', ['funk', 'soul']),
  [`bands/${B2}/songs/demo-b02-song-03`]: song('demo-b02-song-03', B2, 'demo-song-07', 'Valerie', 'Mark Ronson ft. Amy Winehouse', 106, 'Eb', ['soul', 'pop']),

  [`bands/${B3}/songs/demo-b03-song-01`]: song('demo-b03-song-01', B3, 'demo-song-05', 'Mr. Brightside', 'The Killers', 148, 'Db', ['rock', 'indie']),
  [`bands/${B3}/songs/demo-b03-song-02`]: song('demo-b03-song-02', B3, 'demo-song-03', 'Wonderwall', 'Oasis', 87, 'G', ['britpop', '90s']),
  [`bands/${B3}/songs/demo-b03-song-03`]: song('demo-b03-song-03', B3, null, 'Seven Nation Army', 'The White Stripes', 124, 'Em', ['rock', 'indie']),

  [`bands/${CC}/setlists/demo-cc-setlist-01`]: setlist('demo-cc-setlist-01', CC, 'Wedding Party Set',
    'Crowd-pleasers for the reception.', 'Riverside Hall', '2026-07-18T19:00:00.000',
    ['demo-cc-song-03', 'demo-cc-song-02', 'demo-cc-song-01']),
  [`bands/${B2}/setlists/demo-b02-setlist-01`]: setlist('demo-b02-setlist-01', B2, 'Friday Funk Night',
    'High-energy funk block, no breaks.', 'Groove Cellar', '2026-07-10T21:00:00.000',
    ['demo-b02-song-01', 'demo-b02-song-02', 'demo-b02-song-03']),
  [`bands/${B3}/setlists/demo-b03-setlist-01`]: setlist('demo-b03-setlist-01', B3, 'Indie Night Opener',
    'Opening slot at the club.', 'The Velvet Room', '2026-07-24T20:30:00.000',
    ['demo-b03-song-03', 'demo-b03-song-01', 'demo-b03-song-02']),
};

(async () => {
  const writes = Object.entries(docs).map(([path, data]) => ({
    update: { name: `${BASE}/${path}`, fields: toFields(data) },
  }));
  const res = await fetch(`https://firestore.googleapis.com/v1/${BASE}:commit`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.TOKEN}`,
      'Content-Type': 'application/json',
      'x-goog-user-project': PROJECT,
    },
    body: JSON.stringify({ writes }),
  });
  const body = await res.json();
  if (!res.ok) { console.error(JSON.stringify(body, null, 2)); process.exit(1); }
  console.log(`committed ${writes.length} writes`);
})();
