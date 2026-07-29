# Google Play launch pack

Copy-paste answers for the manual Play Console steps (#48–#50). The code/content
blockers (#44–#47) are done in the repo; this covers what only you can do in the
Console. App: **FlowGroove** · package **`com.flowgroove.app`** · category **Music & Audio**.

---

## App access / reviewer login (#48 → App access)

The app requires an account, but there's a one-tap demo — give the reviewer this:

```
This app needs an account, but a demo is available with no credentials.

Steps:
1. Open the app.
2. On the sign-in screen, tap "Try Demo".
3. You now have full access — songs, setlists, bands, metronome and tuner are in
   the bottom navigation.
```

If the Console insists on typed credentials, set a password for the existing
`demo@flowgroove.app` account in Firebase Auth and provide:
`Email: demo@flowgroove.app` / `Password: <set one>`.

---

## Data safety (#48 → Data safety)

Match this to the privacy policy (already live at /privacy/).

**Does your app collect or share user data?** Yes (collect), No (share/sell).

**Data collected:**
| Type | Collected | Purpose | Optional? |
|------|-----------|---------|-----------|
| Email address | Yes | Account management | Required |
| Name (display name) | Yes | Account / app functionality | Required |
| User content (songs, setlists, bands, notes) | Yes | App functionality | Required |
| App activity / other (Firebase user ID) | Yes | App functionality | Required |
| Crash logs & diagnostics | Yes | Analytics / stability | Optional |

**Audio / microphone:** **NOT collected.** The tuner uses the mic for on-device
pitch detection only; audio is never recorded, stored, or transmitted.
**Location, contacts, photos/media, financial info:** not collected.

- Data is **encrypted in transit** (HTTPS/TLS). Yes.
- Users **can request deletion**: Yes — in-app (Profile → Delete account) + web:
  `https://flowgroove.app/delete-account/`.
- Data is **not sold**; not shared with third parties for ads.

---

## Data deletion (#48 → App content → Data deletion)

- App lets users create an account: **Yes**
- Users can request account deletion: **Yes — in app**
- Web deletion URL: `https://flowgroove.app/delete-account/`

---

## Foreground service declaration (#48)

The metronome runs a foreground service so the beat keeps playing when the screen
is off / app is backgrounded.

```
Type: mediaPlayback
Why: FlowGroove's metronome plays audio (a click track) that must continue while
the screen is off or the app is in the background during rehearsal/performance.
The service is started only when the user starts the metronome and stopped when
they stop it.
```
(Declared in `android/app/src/main/AndroidManifest.xml` as
`FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.)

---

## Content rating (#48 → questionnaire)

Music & audio utility — answer **No** to: violence, sexual content, profanity,
gambling, drugs/alcohol, hate/sensitive content, user-to-user location sharing.
- User-generated content shared with others? The band feature shares songs/setlists
  *within a private band* (no public feed) — answer per the questionnaire's exact
  wording; there is no public/anonymous UGC.
Expected result: rated for **Everyone / PEGI 3** (or similar).

## Target audience (#48)
Not directed at children. Target age **13+** (or 16+ to match the privacy policy's
under-16 stance — pick the stricter to be safe).

## Ads (#48)
**No**, the app does not contain ads.

---

## Store listing (#49)

**App name:** FlowGroove

**Short description** (≤80 chars):
```
Songs, setlists, tuner & metronome for musicians and bands.
```

**Full description** (no unshipped features):
```
FlowGroove helps musicians and bands keep their repertoire in one place.

Build a song library, prepare setlists, and manage your band's material together.
Play from a clean, stage-readable performance sheet with chords over the lyrics,
transpose to your key, and print or export to PDF. Practice with a built-in
metronome and tune up with the on-device tuner.

Made for cover bands, duos, session players, teachers and students who want a
simple workspace for rehearsal and live material — on phone and on the web.

• Personal and band song libraries
• Setlists, created and exported to PDF for printing
• Lyrics + chords performance sheet with transpose
• Metronome and microphone tuner
• Sync across devices with your account
```

**Category:** Music & Audio
**Contact email:** hello@flowgroove.app
**Privacy policy:** https://flowgroove.app/privacy/

**Assets still needed (your content):** 512×512 icon, 1024×500 feature graphic,
6–8 phone screenshots (song library, song detail, setlist, performance sheet,
metronome, tuner, band).

---

## Developer account (#50)

- Account type: **Organization**
- Legal entity: **Sounding Doubts - Unipessoal Lda**
- Address: Amadora, Portugal · **NIF/NIPC: 518200736**
- Developer contact email + phone (kept working)
- Pay the one-time $25 registration; complete identity/contact verification.
- Then: create app → upload the signed `.aab` (`make build-appbundle`) to
  **Internal testing** first → closed testing if the Console requires it →
  staged production rollout.
