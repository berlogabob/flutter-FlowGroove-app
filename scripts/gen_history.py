#!/usr/bin/env python3
"""Generate site/data/history.yaml from git log — the project source-of-truth changelog.

Full log of real feature/fix work; auto-deploy `Release x.y.z+N` churn is collapsed into a
compact version_timeline so it stays traceable without 235 noise entries.

Usage:
    python3 scripts/gen_history.py            # regenerate site/data/history.yaml from scratch
    python3 scripts/gen_history.py --since HASH  # print YAML stubs for commits after HASH (append flow)

# ponytail: one generator, no framework. Enrich `why` via the WHY overlay below, not by hand-editing YAML.
"""
import re
import subprocess
import sys

# Commit-subject substring -> motivation ("why"). Curated for arc-defining changes + June sessions
# (the latter mined from the root *.txt Claude Code transcripts). Everything else gets "".
WHY = {
    "Initial commit": "Day 0 — scaffold the Flutter project (then named repsync) that became FlowGroove.",
    "Add simple metronome": "Bands need a reliable click; the metronome was the first real feature beyond CRUD.",
    "Web Audio API sound": "flutter_soloud has no web path (silent on web), so web needs the Web Audio engine.",
    "Tone Matrix System": "Give the metronome per-beat tone/accent control instead of a single flat click.",
    "MusicBrainz": "Manual BPM/key entry is where good intentions die — autocomplete fills metadata from a real DB.",
    "duplicate detection": "Canonical songs must dedupe so the shared library doesn't fill with near-identical entries.",
    "dual-deploy architecture": "Split the public Hugo landing page from the Flutter app so each can ship independently.",
    "roles + demo": "Server-authoritative roles + a seeded demo account so 'Try Demo' shows a real, populated band.",
    "WallClockScheduler": "Metronome drifted over time; wall-clock scheduling with drift compensation keeps it tight.",
    "make release": "Codify the release ritual (Android + GitHub Release) into one command to stop manual mistakes.",
    # June transcript-sourced
    "in-app help": "Generic FAQs are useless mid-rehearsal — bundle the Hugo wiki so help matches the current screen.",
    "wiki": "Reuse the same Markdown for site docs and in-app help so they can't drift apart.",
    "avatar": "Avatar diverged (Google on home, Telegram on profile) — make the profile choice authoritative everywhere.",
    "iframe": "HtmlElementView/iframe freezes the web app; open external content in a new tab instead.",
    "deeplink": "Cold-start join links did nothing because redirect ran before Firebase auth restored.",
}

# area inference: first matching keyword in the lowercased subject wins.
AREA_RULES = [
    ("metronome", ["metronome", "bpm", "tempo", "accent", "subdivision", "tap ", "tone matrix"]),
    ("songs", ["song", "autocomplete", "musicbrainz", "canonical"]),
    ("bands", ["band", "member", "role", "join", "invite"]),
    ("setlists", ["setlist"]),
    ("sync", ["sync", "firestore", "offline", "realtime", "provider"]),
    ("auth", ["auth", "sign-in", "sign in", "login", "google", "avatar", "photo", "user doc"]),
    ("web", ["web", "iframe", "hugo", "landing", "site", "wiki", "blog"]),
    ("deploy", ["deploy", "release", "ftp", "pages", "rollback", "ci", "keystore", "signing"]),
    ("tooling", ["agent", "memory", "make ", "script", "version.json", "graphify"]),
]

TYPE_RE = re.compile(r"^(feat|fix|chore|docs|refactor|wip|deploy|build|perf|test|style|ci)\b", re.I)
VER_RE = re.compile(r"\d+\.\d+\.\d+(?:\+\d+)?")
RELEASE_RE = re.compile(r"^(Release \d|release:|chore: Release|Build & Deploy v|version$|v\d)", re.I)


def infer_type(subject):
    m = TYPE_RE.match(subject)
    if m:
        t = m.group(1).lower()
        return {"wip": "chore", "build": "infra", "ci": "infra", "perf": "refactor",
                "test": "chore", "style": "chore", "deploy": "deploy"}.get(t, t)
    s = subject.lower()
    if s.startswith(("add ", "implement", "integrate")):
        return "feat"
    if s.startswith(("fix", "revert", "hotfix")):
        return "fix"
    if s.startswith("deploy"):
        return "deploy"
    return "chore"


def infer_area(subject):
    s = subject.lower()
    for area, kws in AREA_RULES:
        if any(k in s for k in kws):
            return area
    return "core"


DOCS_IMPACT = {
    "metronome": "wiki/metronome.md", "songs": "wiki/songs.md", "bands": "wiki/bands.md",
    "setlists": "wiki/setlists.md", "auth": "wiki/profile.md", "web": "wiki/_index.md",
}


# Commit-subject substring -> (blog status, blog_ref) for work already turned into a post.
BLOG = {
    "in-panel navigation": ("published", "blog/2026-06-24-in-app-help-that-follows-the-screen-you-re-on.md"),
    "wiki panel": ("published", "blog/2026-06-24-in-app-help-that-follows-the-screen-you-re-on.md"),
    "WallClockScheduler": ("published", "blog/2026-06-25-why-the-metronome-slowly-drifted.md"),
    "index.html rule hid": ("published", "blog/2026-06-25-the-blog-posts-that-404d.md"),
    "drop iframe": ("published", "blog/2026-06-25-the-iframe-that-froze-the-app.md"),
    "import Google photo server-side": ("published", "blog/2026-06-25-two-faces-one-user.md"),
    "putData": ("published", "blog/2026-06-25-avatars-that-wouldnt-upload-on-web.md"),
    "decouple from MethodChannel": ("published", "blog/2026-06-25-the-provider-that-touched-everything.md"),
    "Revert version to": ("published", "blog/2026-06-25-the-v1-that-never-was.md"),
    # Season 1
    "Rename project from RepSync": ("published", "blog/2026-06-25-day-zero-it-was-called-repsync.md"),
    # Season 2
    "Web Audio API sound synthesis": ("published", "blog/2026-06-25-the-web-metronome-was-silent.md"),
    "Accent Pattern (Reaper DAW style)": ("published", "blog/2026-06-25-reaper-style-accent-patterns.md"),
    "Tone Matrix System - Core": ("published", "blog/2026-06-25-the-tone-matrix.md"),
    "route-change handling": ("published", "blog/2026-06-25-silent-on-bluetooth.md"),
    "Audio pre-initialization for instant first beat": ("published", "blog/2026-06-25-instant-first-beat.md"),
    "vibration sync + focus manager": ("published", "blog/2026-06-25-making-the-click-feel-tight.md"),
    "Metronome Phase 4 - Visual Polish": ("published", "blog/2026-06-25-readable-on-a-dark-stage.md"),
    # Season 3
    "MusicBrainz + Song Suggestion": ("published", "blog/2026-06-25-pulling-bpm-and-key-from-musicbrainz.md"),
    "duplicate detection": ("published", "blog/2026-06-25-canonical-songs-and-the-duplicate-problem.md"),
    "band -> song sorting and editing": ("published", "blog/2026-06-25-band-songs-are-copies-not-links.md"),
    "Fix band setlist creation flow": ("published", "blog/2026-06-25-setlists-that-survive-a-coffee-spill.md"),
    # Season 4
    "offline indicator": ("published", "blog/2026-06-25-real-time-sync-on-bad-wifi.md"),
    "server-authoritative leave/delete": ("published", "blog/2026-06-25-who-is-allowed-to-do-what.md"),
    "comprehensive debug and fix tools for permission": ("published", "blog/2026-06-25-permission-denied-on-a-new-account.md"),
    "real demo screenshots": ("published", "blog/2026-06-25-the-demo-account-thats-actually-real.md"),
    "wakelock": ("published", "blog/2026-06-25-concert-mode.md"),
    # Season 5
    "deployment with FTP and make release-stable": ("published", "blog/2026-06-25-two-deploy-channels-one-repo.md"),
    "transform Hugo into landing page": ("published", "blog/2026-06-25-landing-page-and-app-shipping-apart.md"),
    "make release' command for Android": ("published", "blog/2026-06-25-make-release-and-the-ritual-it-replaced.md"),
    "release Firebase init crash": ("published", "blog/2026-06-25-the-release-that-crashed-on-launch.md"),
    # Season 7
    "Memory System with Mr. Memory agent": ("published", "blog/2026-06-25-a-memory-that-survives-clear.md"),
    "comprehensive design system audit": ("published", "blog/2026-06-25-linking-my-design-system-to-an-ai.md"),
}


def find_why(subject):
    for key, why in WHY.items():
        if key.lower() in subject.lower():
            return why
    return ""


# The 2026-06-25 series is written but held as drafts until the coordinated launch
# (waiting on subreddit approval). Flip to True on launch day, then regenerate.
SERIES_LIVE = False


def find_blog(subject):
    for key, (status, ref) in BLOG.items():
        if key.lower() in subject.lower():
            if status == "published" and not SERIES_LIVE and "/2026-06-25-" in ref:
                return "drafted", ref  # written, not yet live
            return status, ref
    return "idea", ""


def yaml_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def load_commits(since=None):
    rng = f"{since}..HEAD" if since else "HEAD"
    out = subprocess.check_output(
        ["git", "log", "--reverse", "--format=%h\t%cI\t%s", rng], text=True)
    rows = []
    for line in out.splitlines():
        h, iso, subj = line.split("\t", 2)
        rows.append((h, iso[:10], subj))
    return rows


def is_release(subj):
    return bool(RELEASE_RE.match(subj))


def assign_versions(rows):
    """Each feature commit -> the next release version chronologically after it."""
    versions = {}
    next_ver = ""
    for h, date, subj in reversed(rows):
        if is_release(subj):
            m = VER_RE.search(subj)
            if m:
                next_ver = m.group(0)
        versions[h] = next_ver
    return versions


def build_entries(rows, versions):
    entries = []
    for h, date, subj in rows:
        if is_release(subj):
            continue
        area = infer_area(subj)
        why = find_why(subj)
        blog, blog_ref = find_blog(subj)
        if blog == "idea" and not blog_ref and not why:
            blog = "none"  # only curated arcs (those with a why) are blog candidates
        entries.append({
            "date": date, "version": versions.get(h, ""), "type": infer_type(subj),
            "area": area, "title": subj, "what": subj, "why": why,
            "commits": [h], "docs_impact": DOCS_IMPACT.get(area, ""),
            "blog": blog, "blog_ref": blog_ref,
        })
    return entries


def build_timeline(rows):
    tl, seen = [], set()
    for h, date, subj in rows:
        if is_release(subj):
            m = VER_RE.search(subj)
            ver = m.group(0) if m else subj
            if ver not in seen:
                seen.add(ver)
                tl.append((date, ver, h))
    return tl


def emit_entry(e, indent="  "):
    L = [f"{indent}- date: {e['date']}",
         f'{indent}  version: "{e["version"]}"',
         f"{indent}  type: {e['type']}",
         f"{indent}  area: {e['area']}",
         f"{indent}  title: {yaml_str(e['title'])}",
         f"{indent}  what: {yaml_str(e['what'])}",
         f"{indent}  why: {yaml_str(e['why'])}",
         f"{indent}  commits: [{', '.join(e['commits'])}]",
         f'{indent}  docs_impact: "{e["docs_impact"]}"',
         f"{indent}  blog: {e['blog']}",
         f'{indent}  blog_ref: "{e["blog_ref"]}"']
    return "\n".join(L)


PHASES = """phases:
  - id: genesis
    range: "2026-02-03"
    title: "Genesis"
    summary: "Flutter project repsync scaffolded, README, project setup — becomes FlowGroove."
  - id: metronome
    range: "2026-02-19 → 2026-02-21"
    title: "First releases + Metronome"
    summary: "Web Audio synth, accent patterns, subdivisions, Tap BPM, presets, song integration."
  - id: unified
    range: "2026-02-23 → 2026-02-26"
    title: "Unified interaction + churn era"
    summary: "Unified item interaction across songs/bands/setlists, custom AppBar, Firestore rules; v1.0.0 attempt + revert."
  - id: tooling
    range: "2026-03-14"
    title: "Tooling + Memory"
    summary: "Mr. Memory agent, version.json automation, make release command."
  - id: autocomplete
    range: "2026-03-30"
    title: "Autocomplete + Tone Matrix"
    summary: "MusicBrainz + suggestion services, autocomplete widgets, canonical songs backend, Tone Matrix metronome."
  - id: dual-deploy
    range: "2026-04-01 → 2026-04-09"
    title: "Dual-deploy + Landing"
    summary: "deploy-stable safety + rollback, dual-deploy Hugo landing + Flutter app, MonoPulse theme, roles + demo."
  - id: hardening
    range: "2026-05 → 2026-06"
    title: "Hardening + Wiki/Help"
    summary: "WallClockScheduler drift, server-authoritative bands, join deeplink fixes, desktop wiki panel, in-app help, avatar sync."
"""


# phase id -> (start date, title). A change belongs to the latest phase whose start <= its date.
PHASE_BOUNDS = [
    ("2026-02-03", "Genesis"),
    ("2026-02-19", "First releases + Metronome"),
    ("2026-02-23", "Unified interaction + churn era"),
    ("2026-03-14", "Tooling + Memory"),
    ("2026-03-30", "Autocomplete + Tone Matrix"),
    ("2026-04-01", "Dual-deploy + Landing"),
    ("2026-05-01", "Hardening + Wiki/Help"),
]
# Types worth showing on the human changelog; chore/docs churn stays in the YAML only.
CHANGELOG_TYPES = {"feat", "fix", "deploy", "infra", "refactor"}


def phase_for(date):
    title = PHASE_BOUNDS[0][1]
    for start, t in PHASE_BOUNDS:
        if date >= start:
            title = t
    return title


def render_changelog(entries, timeline):
    shown = [e for e in entries if e["type"] in CHANGELOG_TYPES]
    out = [
        "---",
        'title: "Changelog & Archive"',
        'description: "What shipped in FlowGroove, when, and why — the human-readable project history."',
        "---",
        "",
        "# Changelog & Archive",
        "",
        f"The full FlowGroove history — **{len(shown)} notable changes** across "
        f"**{len(timeline)} releases**, from day 0 ({entries[0]['date']}) to today. "
        "The complete machine-readable log (including chores and every release) lives in "
        "`site/data/history.yaml`.",
        "",
    ]
    last_phase = None
    for e in shown:
        ph = phase_for(e["date"])
        if ph != last_phase:
            out += ["", f"## {ph}", ""]
            last_phase = ph
        ver = f" `v{e['version']}`" if e["version"] else ""
        tag = {"feat": "✨", "fix": "🔧", "deploy": "🚀", "infra": "⚙️", "refactor": "♻️"}[e["type"]]
        line = f"- **{e['date']}**{ver} {tag} {e['what']}"
        if e["why"]:
            line += f" — _{e['why']}_"
        if e["blog"] == "published" and e["blog_ref"]:
            slug = e["blog_ref"].split("/")[-1].replace(".md", "")
            line += f" ([blog](/blog/{slug.split('-', 3)[-1] if slug[:4].isdigit() else slug}/))"
        out.append(line)
    out.append("")
    return "\n".join(out)


def main():
    if "--changelog" in sys.argv:
        import yaml
        d = yaml.safe_load(open("site/data/history.yaml"))
        entries = [{**e, "date": str(e["date"])} for e in d["changes"]]
        with open("site/content/wiki/changelog.md", "w") as f:
            f.write(render_changelog(entries, d["version_timeline"]))
        print("wrote site/content/wiki/changelog.md")
        return

    if "--since" in sys.argv:
        since = sys.argv[sys.argv.index("--since") + 1]
        rows = load_commits(since)
        versions = assign_versions(rows)
        for e in build_entries(rows, versions):
            print(emit_entry(e))
        return

    rows = load_commits()
    versions = assign_versions(rows)
    entries = build_entries(rows, versions)
    timeline = build_timeline(rows)

    parts = [
        "# FlowGroove — project history / source-of-truth changelog.",
        "# Generated by scripts/gen_history.py from git log. Enrich `why` via the WHY overlay in that script.",
        "# Schema per entry: date, version, type, area, title, what, why, commits, docs_impact, blog, blog_ref.",
        f"# {len(entries)} feature/fix entries · {len(timeline)} released versions · day 0 = {rows[0][1]}.",
        "",
        PHASES,
        "version_timeline:",
    ]
    for date, ver, h in timeline:
        parts.append(f'  - {{ date: {date}, version: "{ver}", commit: {h} }}')
    parts.append("")
    parts.append("changes:")
    for e in entries:
        parts.append(emit_entry(e))
    parts.append("")

    with open("site/data/history.yaml", "w") as f:
        f.write("\n".join(parts))
    print(f"wrote site/data/history.yaml — {len(entries)} entries, {len(timeline)} versions")


if __name__ == "__main__":
    main()
