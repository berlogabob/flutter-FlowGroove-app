# Canonical Library Migration Runbook

**Scope:** exact external-ID matches only
**Status:** tooling-ready; production execution deferred

## Purpose

Convert legacy full song documents into v2 linked library songs only when the
existing dry-run report found one unambiguous MusicBrainz, ISRC, or Spotify
canonical match.

This runbook does not authorize normalized title/artist candidates, ambiguous
matches, unmatched songs, standalone songs, or unknown owner paths.

## Prerequisites

- Node dependencies installed in `functions/`.
- Firebase CLI available.
- Java 21+ for emulator validation.
- A fresh dry-run report generated within 24 hours.
- Dry-run JSON where `samplesTruncated.exactExternalIdLinkedCandidates` is
  `false`. If exact candidates are truncated, regenerate with a higher
  `--sample-limit` before previewing or writing.
- Review of `exact-candidates.csv` before any production write.

## Generate Dry Run

```bash
npm --prefix functions run migration:dry-run -- \
  --out functions/migration-reports/library-dry-run.json \
  --csv-dir functions/migration-reports/review \
  --sample-limit 100
```

Review:

- `functions/migration-reports/review/exact-candidates.csv`
- `functions/migration-reports/review/ambiguous-matches.csv`
- `functions/migration-reports/review/normalized-review-candidates.csv`

Only exact candidates are eligible for this stage.

If the dry-run exact-candidate sample is truncated, rerun with a larger
`--sample-limit` until the JSON contains the full exact-candidate set. The
write-run refuses truncated exact-candidate reports.

## Preview Write Run

Run validation without writes:

```bash
npm --prefix functions run migration:write-run -- \
  --input functions/migration-reports/library-dry-run.json \
  --out functions/migration-reports/library-write-preview.json \
  --limit 50 \
  --project repsync-app-8685c
```

The preview re-reads Firestore, re-runs exact external-ID matching, and reports
skips for stale or changed candidates.

Before continuing, confirm:

- `counts.failed == 0`
- unexpected skip counts are `0`
- `counts.validatedOnly` matches the intended batch size
- no normalized-review, ambiguous, unmatched, standalone, or unknown-owner rows
  are being processed

## Execute Small Batch

Production execution remains deferred until the preview report is reviewed.
When approved, run a small first batch:

```bash
npm --prefix functions run migration:write-run -- \
  --input functions/migration-reports/library-dry-run.json \
  --out functions/migration-reports/library-write-run.json \
  --limit 50 \
  --project repsync-app-8685c \
  --execute
```

Use the write report to verify:

- converted count matches expectations
- skipped rows are understood
- each converted song has `schemaVersion: 2`
- each converted song has one `commits/{commitId}` record
- setlist references still point to the preserved song document IDs

After every executed batch, generate a fresh dry-run report before planning the
next batch. Do not repeat the same `--limit` command against an old report and
assume it advances automatically.

## Rollback Notes

This migration overwrites each converted song document with a v2 library shape
but preserves the legacy full song in `materialized`. Do not delete
`materialized`, legacy IDs, or commit subcollections during this stage.

To pause rollout, stop running write batches. Existing app code reads both
legacy and v2 song documents.
