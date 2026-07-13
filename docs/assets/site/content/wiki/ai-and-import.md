---
title: "AI & Import"
---

# AI & Import

Get songs in fast — bring your own AI, no in-app tokens.

## Search to autofill

- When adding a song, search by title. Suggestions come from your library, Spotify
  and MusicBrainz, ranked by relevance.
- Pick a Spotify result to autofill **BPM and key** automatically.

## Import & export

- **Import:** paste CSV or FlowGroove Song JSON (the app detects which), see a preview
  of what will be added or merged, then save.
- **Export:** a song as JSON (**Copy as JSON**), or a song/setlist as a printable PDF.

## Use your own AI

- In the Import dialog, tap **Copy AI prompt**.
- Paste it into ChatGPT, Claude or Gemini and let it write the song.
- Copy the result and paste it back into Import.

## Connect an AI agent (MCP)

Let Claude, ChatGPT or Gemini list and add songs in your library directly.

- **One-click (remote connector):** add FlowGroove as a custom connector in your AI app and
  sign in — no key, no setup. (Rolling out; needs a paid AI plan on some apps.)
- **Advanced (API key):** Profile → **AI access (MCP)** → create a key, then run the local
  FlowGroove MCP server (see `mcp/README.md`) and add it to your client.
