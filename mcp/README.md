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

All 22, kept in step with the code by `functions/test/mcp-manifest-parity.test.js` —
if a tool is added and this table is not updated, that test fails.

| Tool | Scope | Purpose |
|------|-------|---------|
| `list_songs` | read | List your songs (id, title, artist, key, BPM). |
| `get_song` | read | One song as FlowGroove Song JSON. |
| `export_song` | read | The same JSON, shaped for handing to another tool. |
| `validate_song` | read | Dry-run validate a song object. |
| `lookup_metadata` | read | Resolve a title/artist against MusicBrainz, Spotify, Deezer and lyrics — no write. |
| `create_song` | write | Add a song from FlowGroove Song JSON. |
| `update_song` | write | Update a song by id. |
| `enrich_song` | write | `lookup_metadata` + write what belongs on the song. Fill-only unless `overwrite`. |
| `list_bands` | read | Your bands + your role (admin/editor/viewer). |
| `list_band_songs` | read | Songs in a band (member only). |
| `get_band_song` | read | One band song as FlowGroove Song JSON. |
| `create_band_song` | write | Add one song to a band (admin/editor). |
| `update_band_song` | write | Update an existing band song (admin/editor). |
| `list_setlists` | read | Setlists — personal, or a band's. |
| `create_setlist` | write | Setlist from existing song ids. |
| `create_setlist_with_songs` | write | Songs **and** setlist in one call. Preferred for imports. |
| `add_songs_to_setlist` | write | Append existing songs to a setlist. |
| `delete_setlist` | write | Delete a setlist. Songs are never deleted. |
| `list_personal_setlists` | read | Your personal setlists, explicitly. |
| `create_personal_setlist` | write | Personal setlist, from song ids or full entries. |
| `add_personal_song_to_setlist` | write | Append personal songs to a personal setlist. |
| `delete_personal_setlist` | write | Delete a personal setlist. Songs are never deleted. |

**Personal vs band:** every setlist tool takes an *optional* `bandId`. Omit it and the
tool acts on your personal library (`users/{uid}/…`); pass it for a band. To move a
setlist, recreate it in the new scope and `delete_setlist` the old one. The
`*_personal_*` tools are the same thing said explicitly, for clients that send a
literal `"personal"` instead of omitting the field.

**Scope** is a property of your API key, not of the tool: a read-only key refuses every
`write` row above. Create keys in the app under Profile → AI access (MCP).

Song shape: see [`SONG_JSON_SCHEMA.md`](../SONG_JSON_SCHEMA.md) — `sections[].chordChart`
is ChordPro (`[Am]Twinkle [F]star`). Writes are validated server-side and scoped to your
own library / your bands; there are no canonical writes and no song deletes.

## Try it

> "List my FlowGroove songs, then add *Zombie* by The Cranberries in Em with the verse
> and chorus chords over the lyrics."

## Remote connector (no key, no local server)

The one-click OAuth path for claude.ai/ChatGPT lives in
`functions/src/mcp/remote.js` (`mcpRemote`) — setup runbook: [REMOTE_SETUP.md](REMOTE_SETUP.md).
