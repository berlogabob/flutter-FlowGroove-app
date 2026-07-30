#!/usr/bin/env node
/**
 * FlowGroove MCP server. A thin stdio bridge: each tool forwards to the
 * authenticated FlowGroove gateway with your API key. Runs locally — your AI
 * client spawns it. Config via env: FLOWGROOVE_API_KEY, FLOWGROOVE_GATEWAY_URL.
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import manifest from "../functions/src/mcp/tool_manifest.js";

const { TOOLS, zodShape } = manifest;

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

const server = new McpServer({ name: "flowgroove", version: "1.0.0" });

// Declarations come from the shared manifest in functions/ — see the note there.
// Only the handler is local: every tool is the same POST to the gateway.
for (const t of TOOLS) {
  server.tool(t.name, t.description, zodShape(t.schema, z), (args) => call(t.name, args));
}


await server.connect(new StdioServerTransport());
