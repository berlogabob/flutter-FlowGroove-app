#!/usr/bin/env node
/**
 * FlowGroove MCP server. A thin stdio bridge: each tool forwards to the
 * authenticated FlowGroove gateway with your API key. Runs locally — your AI
 * client spawns it. Config via env: FLOWGROOVE_API_KEY, FLOWGROOVE_GATEWAY_URL.
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const API_KEY = process.env.FLOWGROOVE_API_KEY;
const GATEWAY = process.env.FLOWGROOVE_GATEWAY_URL;

if (!API_KEY || !GATEWAY) {
  console.error(
    "FlowGroove MCP: set FLOWGROOVE_API_KEY and FLOWGROOVE_GATEWAY_URL " +
      "(create a key in the app: Profile → AI access (MCP)).",
  );
  process.exit(1);
}

async function call(tool, args) {
  try {
    const res = await fetch(GATEWAY, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${API_KEY}`,
      },
      body: JSON.stringify({ tool, args: args || {} }),
    });
    const body = await res.text();
    return { content: [{ type: "text", text: body }], isError: !res.ok };
  } catch (e) {
    return {
      content: [{ type: "text", text: `Gateway error: ${e.message}` }],
      isError: true,
    };
  }
}

const song = z
  .record(z.any())
  .describe("A song object in FlowGroove Song JSON (see the schema).");

const server = new McpServer({ name: "flowgroove", version: "1.0.0" });

server.tool("list_songs", "List the user's FlowGroove songs.", {}, () =>
  call("list_songs"),
);
server.tool(
  "get_song",
  "Get one song as FlowGroove Song JSON.",
  { id: z.string() },
  ({ id }) => call("get_song", { id }),
);
server.tool(
  "export_song",
  "Export a song as FlowGroove Song JSON.",
  { id: z.string() },
  ({ id }) => call("export_song", { id }),
);
server.tool(
  "validate_song",
  "Validate a song object against the FlowGroove schema (no write).",
  { song },
  ({ song }) => call("validate_song", { song }),
);
server.tool(
  "create_song",
  "Create a song from FlowGroove Song JSON (needs a write-scope key).",
  { song },
  ({ song }) => call("create_song", { song }),
);
server.tool(
  "update_song",
  "Update a song by id with FlowGroove Song JSON (needs a write-scope key).",
  { id: z.string(), song },
  ({ id, song }) => call("update_song", { id, song }),
);

await server.connect(new StdioServerTransport());
