# Graphify checkpoint

```json
{
  "checked_at": "2026-10-24T16:49:36.498401+01:00",
  "scope": "Fresh code extraction plus literal registry/task/allowed-file layer; not full document semantic extraction",
  "nodes": 13123,
  "raw_links": 20123,
  "activity_relationships": 310,
  "issue_nodes_verified": 33,
  "task_nodes_verified": 62,
  "dangling_endpoints": 0,
  "query_checked": "UX-006 seed and exact canonical-source-file implementation allowlist",
  "llm_tokens_for_registry_extraction": 0,
  "code_commit": "e6d8f26b6782fd3f3d3ce686a46a3ae396f6fcdc",
  "task_status": {
    "queued": 53,
    "verified": 7,
    "blocked": 1,
    "running": 1
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
4. Cluster and export; verify all 33 issues/62 tasks, all 310 relations, no dangling endpoints, exact UX-006-I allowlist by canonical node.source_file (not basename label), and seeded query.
5. Preserve pending semantic state; do not claim full document or label coverage. Use GRAPHIFY_SKIP_HOOK=1 only per commit, then explicit export to the accepted commit.
