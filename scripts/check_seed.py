"""Reset the Firebase emulators and seed the data the cross-platform checks use.

Usage: uv run python scripts/check_seed.py <emulator-host>

<emulator-host> is how the app under test reaches the emulators (127.0.0.1 for
Android through adb reverse and for web, the Mac's LAN IP for iOS). It ends up
inside the audio download URL stored on the seeded recording. The seeding itself
always talks to localhost. Ids and credentials below are mirrored in
integration_test/check/check.dart.
"""

import io
import json
import math
import struct
import sys
import urllib.parse
import urllib.request
import wave
import os
from datetime import datetime, timedelta, timezone

PROJECT = "repsync-app-8685c"
BUCKET = "repsync-app-8685c.firebasestorage.app"
EMAIL, PASSWORD = "check@flowgroove.test", "Password123!"
# (id, title, our key, our BPM, tags); created one minute apart, Alpha first, so
# "Date Added" order is Gamma, Beta, Alpha.
SONGS = [("check-song-1", "Check Song Alpha", "C", 120, []),
         ("check-song-2", "Check Song Beta", "G", 100, ["learning"]),
         ("check-song-3", "Check Song Gamma", "Am", 140, [])]
# A second user: owner of a band the seed user can join, and member of a band the seed user admins.
EMAIL2 = "check2@flowgroove.test"
ENTRY_ID = "check-entry"
BAR_MS = 2000  # 120 bpm, 4/4
# (sectionId, section name, part ids): each part is one bar pair, 4 s long.
SECTIONS = [("sec-verse", "Verse", ["part-v1", "part-v2"]),
            ("sec-chorus", "Chorus", ["part-c1", "part-c2"])]


def call(method, url, body=None, headers=None, raw=False):
    data = body if raw else (json.dumps(body).encode() if body is not None else None)
    h = {"Content-Type": "application/json", "Authorization": "Bearer owner"}
    h.update(headers or {})
    req = urllib.request.Request(url, data=data, method=method, headers=h)
    with urllib.request.urlopen(req) as r:
        text = r.read()
    return json.loads(text) if text else {}


def fs_value(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, str):
        return {"stringValue": v}
    if v is None:
        return {"nullValue": None}
    if isinstance(v, list):
        return {"arrayValue": {"values": [fs_value(x) for x in v]}}
    return {"mapValue": {"fields": {k: fs_value(x) for k, x in v.items()}}}


def fs_set(path, doc):
    url = f"http://localhost:8080/v1/projects/{PROJECT}/databases/(default)/documents/{path}"
    call("PATCH", url, {"fields": {k: fs_value(v) for k, v in doc.items()}})


def wav_bytes(seconds=16, rate=22050):
    # A tone that steps up every bar so the audio is not silent or constant.
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        for i in range(seconds * rate):
            bar = int(i / rate * 1000 // BAR_MS)
            freq = 220 * (1 + 0.125 * (bar % 8))
            frames += struct.pack("<h", int(9000 * math.sin(2 * math.pi * freq * i / rate)))
        w.writeframes(bytes(frames))
    return buf.getvalue()


def main():
    host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
    now = datetime.now(timezone.utc).replace(tzinfo=None).isoformat()

    call("DELETE", f"http://localhost:9099/emulator/v1/projects/{PROJECT}/accounts")
    call("DELETE", f"http://localhost:8080/emulator/v1/projects/{PROJECT}/databases/(default)/documents")

    uid = call("POST", "http://localhost:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake",
               {"email": EMAIL, "password": PASSWORD, "returnSecureToken": True})["localId"]
    ts = {"timestampValue": now + "Z"}
    call("PATCH", f"http://localhost:8080/v1/projects/{PROJECT}/databases/(default)/documents/users/{uid}",
         {"fields": {"uid": {"stringValue": uid}, "email": {"stringValue": EMAIL},
                     "displayName": {"stringValue": "Check User"}, "accessRole": {"stringValue": "member"},
                     "bandIds": fs_value([]), "musicRoles": fs_value([]), "systemTags": fs_value([]),
                     "telegramConsent": {"booleanValue": False}, "createdAt": ts, "updatedAt": ts}})

    uid2 = call("POST", "http://localhost:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake",
                {"email": EMAIL2, "password": PASSWORD, "displayName": "Check Two", "returnSecureToken": True})["localId"]
    call("PATCH", f"http://localhost:8080/v1/projects/{PROJECT}/databases/(default)/documents/users/{uid2}",
         {"fields": {"uid": {"stringValue": uid2}, "email": {"stringValue": EMAIL2},
                     "displayName": {"stringValue": "Check Two"}, "accessRole": {"stringValue": "member"},
                     "bandIds": fs_value([]), "musicRoles": fs_value([]), "systemTags": fs_value([]),
                     "telegramConsent": {"booleanValue": False}, "createdAt": ts, "updatedAt": ts}})
    # Band the seed user admins (user 2 is an editor), with one band song; band the seed user can join by code.
    members = [{"uid": uid, "role": "admin", "displayName": "Check User", "email": EMAIL, "musicRoles": []},
               {"uid": uid2, "role": "editor", "displayName": "Check Two", "email": EMAIL2, "musicRoles": []}]
    fs_set("bands/check-band-admin", {
        "id": "check-band-admin", "name": "Check Admin Band", "createdBy": uid, "members": members,
        "memberUids": [uid, uid2], "adminUids": [uid], "editorUids": [uid2], "tags": [],
        "inviteCode": "ADMIN1", "createdAt": now})
    fs_set(f"users/{uid}/bands/check-band-admin", {"bandId": "check-band-admin"})
    fs_set(f"users/{uid2}/bands/check-band-admin", {"bandId": "check-band-admin"})
    fs_set("bands/check-band-admin/songs/check-band-song", {
        "id": "check-band-song", "title": "Band Song One", "artist": "Check Band", "originalKey": "D",
        "originalBPM": 110, "ourKey": "D", "ourBPM": 110, "tags": [], "bandId": "check-band-admin",
        "contributorId": uid, "contributorName": "Check User", "createdAt": now, "updatedAt": now})
    fs_set("bands/check-band-join", {
        "id": "check-band-join", "name": "Check Join Band", "createdBy": uid2,
        "members": [{"uid": uid2, "role": "admin", "displayName": "Check Two", "email": EMAIL2, "musicRoles": []}],
        "memberUids": [uid2], "adminUids": [uid2], "editorUids": [], "tags": [],
        "inviteCode": "JOIN42", "createdAt": now})
    fs_set(f"users/{uid2}/bands/check-band-join", {"bandId": "check-band-join"})
    # Band the seed user can join through a deep link, and one whose members BD-06 edits.
    fs_set("bands/check-band-link", {
        "id": "check-band-link", "name": "Check Link Band", "createdBy": uid2,
        "members": [{"uid": uid2, "role": "admin", "displayName": "Check Two", "email": EMAIL2, "musicRoles": []}],
        "memberUids": [uid2], "adminUids": [uid2], "editorUids": [], "tags": [],
        "inviteCode": "LINK77", "createdAt": now})
    fs_set(f"users/{uid2}/bands/check-band-link", {"bandId": "check-band-link"})
    fs_set("bands/check-band-members", {
        "id": "check-band-members", "name": "Check Members Band", "createdBy": uid, "members": members,
        "memberUids": [uid, uid2], "adminUids": [uid], "editorUids": [uid2], "tags": [],
        "inviteCode": "MEMBR1", "createdAt": now})
    fs_set(f"users/{uid}/bands/check-band-members", {"bandId": "check-band-members"})
    fs_set(f"users/{uid2}/bands/check-band-members", {"bandId": "check-band-members"})

    base = datetime.now(timezone.utc).replace(tzinfo=None)
    for i, (sid, title, key, bpm, tags) in enumerate(SONGS):
        created = (base + timedelta(minutes=i - len(SONGS))).isoformat()
        fs_set(f"users/{uid}/songs/{sid}", {
            "id": sid, "title": title, "artist": "Check Band", "originalKey": key, "originalBPM": bpm,
            "ourKey": key, "ourBPM": bpm, "tags": tags, "createdAt": created, "updatedAt": created})

    name = f"lab_audio/user/{uid}/{SONGS[0][0]}/check.wav"
    # CHECK_SEED_AUDIO=<file>: seed that file (any format) instead of the 16 s tone, and
    # CHECK_SEED_OFFSET_MS=<ms>: shift every region later in the song (for long-file checks).
    own = os.environ.get("CHECK_SEED_AUDIO")
    if own:
        name = name.rsplit(".", 1)[0] + os.path.splitext(own)[1]
        body, ctype = open(own, "rb").read(), {".aac": "audio/aac", ".mp3": "audio/mpeg", ".wav": "audio/wav"}.get(os.path.splitext(own)[1], "application/octet-stream")
    else:
        body, ctype = wav_bytes(), "audio/wav"
    up = call("POST", f"http://localhost:9199/v0/b/{BUCKET}/o?name={urllib.parse.quote(name, safe='')}",
              body, {"Content-Type": ctype}, raw=True)
    token = up["downloadTokens"].split(",")[0]
    audio_url = (f"http://{host}:9199/v0/b/{BUCKET}/o/{urllib.parse.quote(name, safe='')}"
                 f"?alt=media&token={token}")

    regions, t = [], int(os.environ.get("CHECK_SEED_OFFSET_MS", "0"))
    for sec_id, sec_name, parts in SECTIONS:
        for n, pid in enumerate(parts, 1):
            regions.append({"id": pid, "name": f"{sec_name} {n}", "startMs": t, "endMs": t + 2 * BAR_MS,
                            "sectionId": sec_id, "section": sec_name})
            t += 2 * BAR_MS
    fs_set(f"users/{uid}/songs/{SONGS[0][0]}/labEntries/{ENTRY_ID}", {
        "id": ENTRY_ID, "songId": SONGS[0][0], "type": "recording", "title": "Check recording",
        "authorId": uid, "visibility": "private", "tags": [], "createdAt": now, "updatedAt": now,
        "attachmentIds": [audio_url], "peaks": [], "peaksRms": False,
        "grid": {"bpm": 120.0, "offsetMs": 0, "beatsPerBar": 4}, "regions": regions})
    print(f"seeded uid={uid} songs={len(SONGS)} regions={len(regions)} audio={audio_url}")


if __name__ == "__main__":
    main()
