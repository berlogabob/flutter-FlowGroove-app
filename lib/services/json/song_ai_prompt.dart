import 'song_json_codec.dart';

/// Ready-made prompt that tells a user's own AI (ChatGPT / Claude / Gemini) to
/// output a song in FlowGroove Song JSON (see [SongJsonCodec] / the schema doc),
/// which the user then pastes into Import. Keeps AI cost on the user's side —
/// FlowGroove never spends tokens.
///
/// Optionally seeds the prompt with a [title]/[artist] the user has already typed.
String songImportPrompt({String? title, String? artist}) {
  final wanted = [
    if (title != null && title.trim().isNotEmpty) 'title "${title.trim()}"',
    if (artist != null && artist.trim().isNotEmpty) 'by "${artist.trim()}"',
  ].join(' ');
  final subject = wanted.isEmpty ? 'the song I name' : 'the song $wanted';

  return '''
You are helping me add a song to FlowGroove. Output **only** valid FlowGroove
Song JSON v${SongJsonCodec.schemaVersion} — no prose, no markdown fences.

Envelope:
{ "schemaVersion": ${SongJsonCodec.schemaVersion}, "songs": [ { ...song... } ] }

Song fields:
- "title" (required), "artist"
- "originalKey", "ourKey" — like "C", "G#", "Am", "Bbm"
- "originalBPM", "ourBPM" — integers 40–300
- "tags" — array of strings; "notes" — string
- "sections" — array of { "name", "duration" (bars, int), "notes",
  "chordChart" } where "chordChart" is ChordPro: lyrics with the chord in
  square brackets immediately before its syllable, e.g.
  "[Am]Twinkle [F]little [C]star".

Give me $subject with an accurate key, BPM, section structure, and
chords-over-lyrics in "chordChart". If you are unsure of a value, omit that
field rather than guessing. Return the JSON object only.''';
}
