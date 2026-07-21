# Remote MCP connector — setup (the "magic" one-click flow)

The goal: a user adds FlowGroove in Claude via **Settings → Connectors → Add custom
connector → paste one URL → Connect → sign in with Google → done**. No API key, no local
server, no config file. This is powered by `functions/src/mcp/remote.js` (`mcpRemote`) + a
managed OAuth provider. (The API-key + local-server path in `mcp/` still works for power users.)

**MCP endpoint URL:** `https://app.flowgroove.app/mcp`
**PRM URL:** `https://app.flowgroove.app/.well-known/oauth-protected-resource`

(Fronted by a Firebase Hosting rewrite in `firebase.json` → the `mcpRemote` function; the raw
`https://us-central1-repsync-app-8685c.cloudfunctions.net/mcpRemote/mcp` URL still works too.)

## Step 1 — Managed OAuth provider (you)

Pick one with MCP-native OAuth (Dynamic Client Registration + PKCE) and a **Google** login:
**WorkOS AuthKit**, **Auth0**, **Stytch (Connected Apps)**, or **Scalekit**. All have MCP
quickstarts and free tiers. In it:

1. Enable **Google** as the sign-in method.
2. Enable **Dynamic Client Registration** (so Claude/ChatGPT can register themselves).
3. Set the **resource / audience** to the MCP endpoint URL above.
4. Note the provider's **issuer URL** and **JWKS URL**.

No client secret goes into FlowGroove — a resource server only *validates* tokens.

## Step 2 — Function env (you)

These are public (not secrets). Add to `functions/.env` (loaded automatically) or set via
`firebase functions:config`:

```
MCP_OAUTH_ISSUER=https://your-tenant.example.com
MCP_OAUTH_AUDIENCE=https://app.flowgroove.app/mcp
MCP_RESOURCE_URL=https://app.flowgroove.app/mcp
# optional; defaults to ${MCP_OAUTH_ISSUER}/.well-known/jwks.json
MCP_JWKS_URL=https://your-tenant.example.com/.well-known/jwks.json
```

If using WorkOS AuthKit specifically: `MCP_OAUTH_ISSUER`/`MCP_JWKS_URL` must be the **AuthKit
domain** (Dashboard → Domains, e.g. `https://your-project.authkit.app`), not the generic
`api.workos.com/user_management/{client_id}` issuer — the generic one has no
`registration_endpoint`, which breaks Dynamic Client Registration.

The token must carry the user's **email** (Google login provides it); the server maps
email → Firebase uid via `admin.auth().getUserByEmail`.

## Step 3 — Deploy

```
firebase deploy --only hosting,functions:mcpRemote
```

Check it's live:
- `GET https://app.flowgroove.app/.well-known/oauth-protected-resource` returns JSON with your
  issuer in `authorization_servers`.
- `POST https://app.flowgroove.app/mcp` without a token → `401` + `WWW-Authenticate` header.

## Step 4 — Connect in Claude (you)

Claude **Pro/Max** → **Settings → Connectors → Add custom connector** → URL =
`https://app.flowgroove.app/mcp` → **Connect** → the Google sign-in popup → authorize. Then chat:

> "List my FlowGroove songs, then add *Zombie* by The Cranberries in Em with the verse and
> chorus chords over the lyrics."

The song lands in that Google user's library in the app.

## Notes / limits

- **Platform gating:** the connector UX needs Claude Pro/Max today (ChatGPT: Plus/Pro +
  developer mode; public listing needs review). Same URL will serve ChatGPT once enabled.
- **Identity:** email→uid targets users who signed into FlowGroove with the same Google
  account. Email/password-only users need account-linking (follow-up).
- **Tools:** `list/get/validate/export/create/update_song` — same shared logic as the API-key
  gateway (`functions/src/mcp/tools.js`); writes scoped to the caller's own library.
- If session/SSE features are ever needed, move `mcpRemote` to Cloud Run (same code).
