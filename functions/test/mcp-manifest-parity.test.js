// The MCP tool surface is declared once, in src/mcp/tool_manifest.js, and
// consumed by two servers: functions/src/mcp/remote.js (remote OAuth) and
// mcp/server.js (local stdio, a separate npm package). They used to hold
// copy-pasted declarations and had ALREADY drifted — the same tool carried
// different descriptions depending on which transport an agent connected
// through, and update_song/create_song/validate_song/enrich_song and three
// others disagreed. A description IS the API for an LLM caller, so that was a
// real defect.
//
// The earlier "parity is asserted at 22 tools" check compared NAMES ONLY. It
// could never have caught the drift. This one guards the thing that actually
// broke: it fails if either server goes back to declaring a tool inline.

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { z } = require("zod");

const { TOOLS, TOOL_NAMES, zodShape } = require("../src/mcp/tool_manifest");
const { WRITE_TOOLS } = require("../src/mcp/tools");

const REPO = path.join(__dirname, "..", "..");
const REMOTE = path.join(REPO, "functions", "src", "mcp", "remote.js");
const LOCAL = path.join(REPO, "mcp", "server.js");
const DISPATCHER = path.join(REPO, "functions", "src", "mcp", "tools.js");

const read = (p) => fs.readFileSync(p, "utf8");

describe("MCP tool manifest parity", () => {
  it("declares a non-trivial, unique tool set", () => {
    assert.ok(TOOLS.length >= 20, `only ${TOOLS.length} tools — did the manifest lose entries?`);
    assert.equal(new Set(TOOL_NAMES).size, TOOL_NAMES.length, "duplicate tool name");
    for (const t of TOOLS) {
      assert.match(t.name, /^[a-z][a-z0-9_]*$/, `bad tool name: ${t.name}`);
      assert.ok(t.description && t.description.length > 15, `${t.name}: description too thin`);
      assert.ok(t.annotations, `${t.name}: missing annotations`);
    }
  });

  // The drift guard. Both servers must iterate the manifest; neither may
  // hand-write a `server.tool("name", "description", …)` call, because that is
  // exactly how the two descriptions diverged in the first place.
  for (const [label, file] of [["remote.js", REMOTE], ["mcp/server.js", LOCAL]]) {
    it(`${label} builds its tools from the manifest, not inline literals`, () => {
      const src = read(file);
      assert.ok(
        /tool_manifest/.test(src),
        `${label} does not import the manifest`,
      );
      assert.ok(
        /for \(const t of TOOLS\)/.test(src),
        `${label} does not iterate TOOLS`,
      );
      const inline = [...src.matchAll(/server\.tool\(\s*["']([a-z_]+)["']/g)].map((m) => m[1]);
      assert.deepEqual(
        inline,
        [],
        `${label} declares ${inline.length} tool(s) inline again: ${inline.join(", ")}`,
      );
    });
  }

  // A tool declared but never dispatched answers a client with "unknown tool";
  // a dispatched case with no declaration is unreachable. Both are silent.
  it("matches runTool's dispatcher exactly", () => {
    const src = read(DISPATCHER);
    const body = src.slice(src.indexOf("async function runTool"));
    const cases = [...body.matchAll(/^\s*case "([a-z_]+)":/gm)].map((m) => m[1]);
    assert.deepEqual(
      [...new Set(cases)].sort(),
      [...TOOL_NAMES].sort(),
      "manifest tools and runTool cases disagree",
    );
  });

  // WRITE_TOOLS is the actual write-scope gate. A tool the gate treats as a
  // write but that advertises readOnlyHint:true tells an agent it is safe to
  // call unprompted — the one annotation mistake with real consequences.
  it("agrees with WRITE_TOOLS on what writes", () => {
    const byName = new Map(TOOLS.map((t) => [t.name, t]));
    for (const name of WRITE_TOOLS) {
      const tool = byName.get(name);
      assert.ok(tool, `WRITE_TOOLS has "${name}" but the manifest does not declare it`);
      assert.notEqual(
        tool.annotations.readOnlyHint,
        true,
        `${name} is write-gated but advertises readOnlyHint: true`,
      );
    }
    for (const t of TOOLS) {
      if (t.annotations.readOnlyHint === true) {
        assert.ok(!WRITE_TOOLS.has(t.name), `${t.name} claims read-only but is write-gated`);
      }
    }
  });

  it("converts every schema to zod", () => {
    for (const t of TOOLS) {
      const shape = zodShape(t.schema, z);
      assert.deepEqual(Object.keys(shape), Object.keys(t.schema), `${t.name}: field loss`);
      for (const [field, node] of Object.entries(shape)) {
        const optional = String(t.schema[field].type || t.schema[field]).endsWith("?");
        assert.equal(
          node.safeParse(undefined).success,
          optional,
          `${t.name}.${field}: optionality does not match "${JSON.stringify(t.schema[field])}"`,
        );
      }
    }
  });

  // The README's tool table is a third copy of the surface. It had already
  // fallen to 11 of 22 — every personal-setlist tool, plus lookup_metadata and
  // enrich_song, were undocumented. Guarding it here is cheaper than noticing.
  it("matches the README tool table", () => {
    const md = read(path.join(REPO, "mcp", "README.md"));
    const table = md.slice(md.indexOf("| Tool | Scope | Purpose |"));
    const rows = table.slice(0, table.indexOf("\n\n"));
    const documented = new Set([...rows.matchAll(/^\|([^|]+)\|/gm)]
      .flatMap((m) => [...m[1].matchAll(/`([a-z_]+)`/g)].map((x) => x[1])));
    const byName = new Map(TOOLS.map((t) => [t.name, t]));
    assert.deepEqual(
      [...documented].filter((n) => !byName.has(n)),
      [],
      "README documents a tool that does not exist",
    );
    assert.deepEqual(
      TOOL_NAMES.filter((n) => !documented.has(n)),
      [],
      "tool(s) missing from the README table in mcp/README.md",
    );
    // A read-only key refuses every write tool, so a mislabelled scope column
    // sends people to create the wrong kind of key.
    for (const [, cells] of [...rows.matchAll(/^\| `([a-z_]+)` \| (read|write) \|/gm)]
      .map((m) => [m[1], m])) {
      const [, name, scope] = cells;
      assert.equal(
        scope === "write",
        WRITE_TOOLS.has(name),
        `README says ${name} is "${scope}" but WRITE_TOOLS disagrees`,
      );
    }
  });

  it("rejects an unknown field type instead of silently dropping it", () => {
    assert.throws(() => zodShape({ x: "uuid" }, z), /unknown field type/);
  });
});
