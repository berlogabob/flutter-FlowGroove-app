# Third-party web assets

## lamejs 1.2.7 (`lamejs.iife.js`)

MP3 encoder used only on **web**, to turn a recorded WAV into a file messengers
will actually play. Native doesn't need it — it records AAC and shares `.m4a`.

Why it's here at all: no browser can encode MP3 on its own, and the one codec
browsers *can* encode (AAC, via WebCodecs) is unavailable in Firefox and on
desktop Linux. lamejs is pure JavaScript, so it works everywhere. MP3's patents
expired in 2017, so only the software licence applies.

Source: <https://github.com/zhuker/lamejs> — a JavaScript port of
[LAME](https://lame.sourceforge.net/), **LGPL**.

### Meeting the LGPL conditions

`lamejs.LICENSE` states three requirements. How each is met:

1. **"Link to LAME as a separate jar"** — this file is served as-is from
   `web/vendor/` and loaded by a `<script>` tag in `web/index.html`. It is
   never bundled, minified, or concatenated into another artifact, so a user
   can replace it with their own build. **Do not fold this into a bundler
   step** — that is what would break compliance.
2. **"Fully acknowledge that you are using LAME, and give a link"** — credited
   on the in-app licenses page (see `lib/main.dart`, `LicenseRegistry`).
3. **"Release modifications back to the LAME project"** — we make none. The
   file is byte-for-byte `@breezystack/lamejs@1.2.7`'s `dist/lamejs.iife.js`.

### Updating

Replace with a newer `dist/lamejs.iife.js` from the same package. Don't patch it
in place; if a fix is ever needed, upstream it (condition 3).
