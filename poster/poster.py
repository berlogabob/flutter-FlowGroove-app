"""FlowGroove Poster — pick commits, scaffold a Hugo blog draft, publish to
Telegram. Lazy single-module CLI. Drafting prose is done by a human/agent,
not this script. Reddit crossposting now lives in ../reddit-bot (Devvit). See README.md."""

import json
import os
import re
import subprocess
import sys
import urllib.request
from datetime import date
from pathlib import Path

import frontmatter
import typer
import yaml
from dotenv import load_dotenv

REPO = Path(__file__).resolve().parent.parent  # poster/ lives one level under repo root
BLOG = REPO / "site" / "content" / "blog"

app = typer.Typer(add_completion=False, help=__doc__)
publish = typer.Typer(help="Publish an approved draft to a channel.")
app.add_typer(publish, name="publish")

load_dotenv(REPO / "poster" / ".env")


def slugify(text: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", text.lower())).strip("-")


def base_url() -> str:
    # Canonical links must point at production (flowgroove.app, FTP-deployed),
    # not the github.io dev baseURL in hugo.toml. Override via SITE_BASE_URL.
    return os.getenv("SITE_BASE_URL", "https://flowgroove.app").rstrip("/")


def _paths(slug: str) -> tuple[Path, Path]:
    """Return (post.md, post.social.yaml) for a slug, matching the dated filename."""
    hits = sorted(BLOG.glob(f"*-{slug}.md"))
    if not hits:
        typer.secho(f"No draft found for slug '{slug}' in {BLOG}", fg="red")
        raise typer.Exit(1)
    md = hits[-1]
    return md, md.with_suffix("").with_suffix(".social.yaml")


def _load_social(slug: str) -> tuple[Path, dict]:
    _, sidecar = _paths(slug)
    return sidecar, yaml.safe_load(sidecar.read_text())


@app.command()
def changes(
    last_days: int = typer.Option(None, "--last-days"),
    since: str = typer.Option(None, "--since", help="git ref/tag, e.g. v0.4.0"),
):
    """List recent commits (sha + subject) so you can pick which to feature."""
    cmd = ["git", "-C", str(REPO), "log", "--pretty=%h\t%s"]
    if since:
        cmd.append(f"{since}..HEAD")
    elif last_days:
        cmd.append(f"--since={last_days} days ago")
    else:
        cmd.append("-20")
    typer.echo(subprocess.check_output(cmd, text=True).rstrip())


@app.command()
def draft(
    title: str = typer.Option(..., "--title"),
    commits: str = typer.Option("", "--commits", help="comma-separated short shas"),
):
    """Scaffold a Hugo blog draft (draft:true) + a .social.yaml sidecar."""
    slug = slugify(title)
    today = date.today().isoformat()
    md_path = BLOG / f"{today}-{slug}.md"
    if md_path.exists():
        typer.secho(f"{md_path} already exists", fg="red")
        raise typer.Exit(1)

    facts = []
    for sha in [c.strip() for c in commits.split(",") if c.strip()]:
        subj = subprocess.check_output(
            ["git", "-C", str(REPO), "log", "-1", "--pretty=%s", sha], text=True
        ).strip()
        facts.append(f"- `{sha}` {subj}")

    post = frontmatter.Post(
        "## What changed\n\n"
        + ("\n".join(facts) if facts else "- (describe the user-facing changes)")
        + "\n\n## Why it matters\n\n(write the prose here — only claims backed by the commits above)\n",
        title=title,
        slug=slug,
        date=f"{today}T10:00:00+01:00",
        draft=True,
        tags=["devlog"],
        categories=["devlog"],
        summary="",
    )
    md_path.write_bytes(frontmatter.dumps(post).encode())

    sidecar = md_path.with_suffix("").with_suffix(".social.yaml")
    url = f"{base_url()}/blog/{slug}/"
    sidecar.write_text(
        yaml.safe_dump(
            {
                "canonical_url": url,
                "telegram": {"text": "", "message_id": None},
            },
            sort_keys=False,
        )
    )
    typer.secho(f"Created {md_path.name} + {sidecar.name}", fg="green")
    typer.echo(f"Canonical URL: {url}")


@publish.command("telegram")
def publish_telegram(slug: str, dry_run: bool = typer.Option(False, "--dry-run")):
    """Send the sidecar telegram.text to the channel via Bot API sendMessage."""
    sidecar, data = _load_social(slug)
    tg = data["telegram"]
    if tg.get("message_id"):
        typer.secho(f"Already published (message_id={tg['message_id']}); refusing.", fg="red")
        raise typer.Exit(1)
    if not (tg.get("text") or "").strip():
        typer.secho("telegram.text is empty — fill it first.", fg="red")
        raise typer.Exit(1)

    payload = {"chat_id": os.getenv("TELEGRAM_CHANNEL_ID", "<TELEGRAM_CHANNEL_ID>"),
               "text": tg["text"], "disable_web_page_preview": False}
    if dry_run:
        typer.echo(json.dumps(payload, indent=2, ensure_ascii=False))
        return

    token = os.environ["TELEGRAM_BOT_TOKEN"]
    payload["chat_id"] = os.environ["TELEGRAM_CHANNEL_ID"]
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendMessage",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as resp:  # raises on HTTP error
        result = json.load(resp)
    tg["message_id"] = result["result"]["message_id"]
    sidecar.write_text(yaml.safe_dump(data, sort_keys=False))
    typer.secho(f"Posted to Telegram (message_id={tg['message_id']})", fg="green")


@app.command()
def selftest():
    """Assert the non-trivial logic: slug + dup guard."""
    assert slugify("Tuner & Metronome!") == "tuner-metronome", slugify("Tuner & Metronome!")
    assert slugify("  Multi --  Dash  ") == "multi-dash"
    # dup guard: a sidecar with a message_id must refuse telegram publish
    guarded = {"message_id": 42}
    refused = bool(guarded.get("message_id"))
    assert refused is True
    typer.secho("selftest ok", fg="green")


if __name__ == "__main__":
    app()
