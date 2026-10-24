# Graphify checkpoint

{
  "checked_at": "2026-10-24T04:35:19.454928+01:00",
  "scope": "Current code extraction plus deterministic activity registry relationships; not full semantic re-extraction of every document",
  "nodes": 13123,
  "raw_links": 20122,
  "activity_relationships": 310,
  "activity_dependencies": 115,
  "dangling_endpoints": 0,
  "query_checked": "UX-007 → R/I/S/V and file allowlists; source code + literal registry updated",
  "llm_tokens_for_registry_extraction": 0,
  "warnings": [
    "linux/runner/my_application.h yielded no symbols after syntax error at line 18",
    "34 code files yielded no symbols; extractor coverage is not complete",
    "Community labels are hub-derived; LLM label refresh intentionally not run",
    "Other changed docs/papers/images still require semantic update; no manifest stamped as full coverage",
    "Graph is >5000 nodes; HTML intentionally not generated (--no-viz)"
  ],
  "private_output": "graphify-out/ (gitignored)",
  "issue_nodes_verified": 33,
  "task_nodes_verified": 62
}

## Reproduction / integrity rule

1. Back up graph.json, then `GRAPHIFY_NO_AUTO_REFRESH=1 graphify update . --no-cluster` for code.
2. Index activity.json literal issue/task/after/allowed_files fields as EXTRACTED, not inferred implementation claims. `may_edit` means planned allowlist, not completed code.
3. Merge with build_merge(root=repo); preserve old parallel raw links. Canonicalisation can remap file-reference IDs: obtain activity edges from the merged G with _src/_tgt, not the pre-merge fragment IDs, before passing original_links to to_json. Otherwise the exporter drops remapped-endpoint links.
4. Recluster with `graphify cluster-only . --no-viz --no-label`; validate all issue/task nodes, every dependency and all current activity relationships (310 at this checkpoint), and zero dangling endpoints. Query UX-006 against the saved graph.
5. Do not clear semantic pending state or claim all docs/labels refreshed. Graph/report remain local; this summary is the safe committed evidence.

The installed post-commit hook launches a code-only asynchronous rebuild. This planning commit uses its existing `GRAPHIFY_SKIP_HOOK=1` opt-out only for that command; security/pre-commit checks remain active. Code and registry were explicitly refreshed and verified. Future code updates must re-merge the structured registry layer afterwards: the scanner otherwise prunes its unsupported/ignored JSON source.

UX-006-R follow-up: registry node status/executor refreshed from activity.json after rejected Ornith timeout and accepted parent review. 33 issue nodes, 62 task nodes and 310 registry relations retained. This is a literal registry metadata refresh, not a new AST/full-document semantic extraction.
