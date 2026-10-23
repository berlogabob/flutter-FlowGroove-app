# Graphify checkpoint

{
  "checked_at": "2026-10-24T00:04:16.664390+01:00",
  "scope": "Current code extraction plus deterministic activity registry relationships; not full semantic re-extraction of every document",
  "nodes": 13118,
  "raw_links": 20105,
  "activity_relationships": 293,
  "activity_dependencies": 108,
  "dangling_endpoints": 0,
  "query_checked": "UX-006, seeded by sux:issue:UX-006",
  "llm_tokens_for_registry_extraction": 0,
  "warnings": [
    "linux/runner/my_application.h yielded no symbols after syntax error at line 18",
    "34 code files yielded no symbols; extractor coverage is not complete",
    "Community labels are hub-derived; LLM label refresh intentionally not run",
    "Other changed docs/papers/images still require semantic update; no manifest stamped as full coverage",
    "Graph is >5000 nodes; HTML intentionally not generated (--no-viz)"
  ],
  "private_output": "graphify-out/ (gitignored)",
  "issue_nodes_verified": 32,
  "task_nodes_verified": 59
}

## Reproduction / integrity rule

1. Back up graph.json, then `GRAPHIFY_NO_AUTO_REFRESH=1 graphify update . --no-cluster` for code.
2. Index activity.json literal issue/task/after/allowed_files fields as EXTRACTED, not inferred implementation claims. `may_edit` means planned allowlist, not completed code.
3. Merge with build_merge(root=repo); preserve old parallel raw links. Canonicalisation can remap file-reference IDs: obtain activity edges from the merged G with _src/_tgt, not the pre-merge fragment IDs, before passing original_links to to_json. Otherwise the exporter drops remapped-endpoint links.
4. Recluster with `graphify cluster-only . --no-viz --no-label`; validate all issue/task nodes, every dependency and all current activity relationships (293 at this checkpoint), and zero dangling endpoints. Query UX-006 against the saved graph.
5. Do not clear semantic pending state or claim all docs/labels refreshed. Graph/report remain local; this summary is the safe committed evidence.

The installed post-commit hook launches a code-only asynchronous rebuild. This planning commit uses its existing `GRAPHIFY_SKIP_HOOK=1` opt-out only for that command; security/pre-commit checks remain active. Code and registry were explicitly refreshed and verified. Future code updates must re-merge the structured registry layer afterwards: the scanner otherwise prunes its unsupported/ignored JSON source.
