# Graphify checkpoint

```json
{
  "checked_at": "2026-10-24T20:04:09.965974+01:00",
  "scope": "Fresh code extraction plus literal registry/task/allowed-file layer; not full document semantic extraction",
  "nodes": 13137,
  "raw_links": 20185,
  "activity_relationships": 355,
  "issue_nodes_verified": 34,
  "task_nodes_verified": 69,
  "dangling_endpoints": 0,
  "query_checked": "Fresh shared-card code extraction and literal 34-issue/69-task registry with corrected scopes, NEW-003, and current canonical file edges; no dangling endpoints.",
  "llm_tokens_for_registry_extraction": 0,
  "code_commit": "87bfe21f96a1273cb4711f75ad5cca0aed25b04d",
  "task_status": {
    "verified": 14,
    "blocked": 4,
    "queued": 50,
    "review": 1
  },
  "warnings": [
    "Existing linux/runner/my_application.h syntax error, no symbols",
    "34 source files without extracted symbols (NEW-001 remains open)",
    "No full changed-document semantic extraction or new HTML"
  ],
  "private_output": "graphify-out/ (gitignored)"
}
```

## Reproduction / integrity rule

1. Back up graph.json, run GRAPHIFY_NO_AUTO_REFRESH=1 graphify update . --no-cluster for code.
2. Rebuild the literal activity-extraction.json layer from canonical tasks, issues, dependencies and current allowed_files; relation may_edit is not proof of completed code.
3. build_merge then collect canonical _src/_tgt registry links from merged graph, preserving untouched raw code links.
4. Cluster and export; verify all 33 issues/65 tasks, all 331 relations, no dangling endpoints, exact UX-006-I allowlist by canonical node.source_file (not basename label), and seeded query.
5. Preserve pending semantic state; do not claim full document or label coverage. Use GRAPHIFY_SKIP_HOOK=1 only per commit, then explicit export to the accepted commit.
