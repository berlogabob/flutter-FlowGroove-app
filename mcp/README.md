# FlowGroove MCP server

Let your own AI (Claude, ChatGPT, Gemini, a local agent) read and add songs in your
FlowGroove library. It talks to an authenticated FlowGroove gateway with a key **you**
create — FlowGroove never uses your AI tokens.

## 1. Get an API key

In the app: **Profile → AI access (MCP) → New key**. Choose:
- **Read only** — list/get/export songs.
- **Read + write** — also create/update songs.

Copy the key (`fg_…`) — it's shown once.

## 2. Install

```bash
cd mcp
npm install
```

Requires Node 18+.

## 3. Configure your AI client

The server is spawned by your client over stdio. Set two env vars:

- `FLOWGROOVE_API_KEY` — your key
- `FLOWGROOVE_GATEWAY_URL` — `https://us-central1-repsync-app-8685c.cloudfunctions.net/mcpGateway`

### Claude Desktop (`claude_desktop_config.json`)

```json
{
  "mcpServers": {
    "flowgroove": {
      "command": "node",
      "args": ["/absolute/path/to/mcp/server.js"],
      "env": {
        "FLOWGROOVE_API_KEY": "fg_your_key_here",
        "FLOWGROOVE_GATEWAY_URL": "https://us-central1-repsync-app-8685c.cloudfunctions.net/mcpGateway"
      }
    }
  }
}
```

Gemini CLI / other MCP clients use the same `command` + `args` + `env` shape.

## 4. Tools

| Tool | Scope | Purpose |
|------|-------|---------|
| `list_songs` | read | List your songs (id, title, artist, key, BPM). |
| `get_song` / `export_song` | read | One song as FlowGroove Song JSON. |
| `validate_song` | read | Dry-run validate a song object. |
| `create_song` | write | Add a song from FlowGroove Song JSON. |
| `update_song` | write | Update a song by id. |
| `list_bands` | read | Your bands + your role (admin/editor/viewer). |
| `list_band_songs` | read | Songs in a band (member only). |
| `create_band_song` | write | Add one song to a band (admin/editor). |
| `list_setlists` | read | Setlists — personal, or a band's. |
| `create_setlist` | write | Setlist from existing song ids. |
| `create_setlist_with_songs` | write | Songs **and** setlist in one call. Preferred for imports. |
| `delete_setlist` | write | Delete a setlist. The only delete. |

**Personal vs band:** every setlist tool takes an *optional* `bandId`. Omit it and the
tool acts on your personal library (`users/{uid}/…`); pass it for a band. To move a
setlist, recreate it in the new scope and `delete_setlist` the old one.

Song shape: see [`SONG_JSON_SCHEMA.md`](../SONG_JSON_SCHEMA.md) — `sections[].chordChart`
is ChordPro (`[Am]Twinkle [F]star`). Writes are validated server-side and scoped to your
own library / your bands; there are no canonical writes and no song deletes.

## Try it

> "List my FlowGroove songs, then add *Zombie* by The Cranberries in Em with the verse
> and chorus chords over the lyrics."

## Remote connector (no key, no local server)

The one-click OAuth path for claude.ai/ChatGPT lives in
`functions/src/mcp/remote.js` (`mcpRemote`) — setup runbook: [REMOTE_SETUP.md](REMOTE_SETUP.md).
