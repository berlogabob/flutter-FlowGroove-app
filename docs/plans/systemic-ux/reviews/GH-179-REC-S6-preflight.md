# REC-S6 cancellation persistence preflight

Evidence: CODE only. Public baseline: 11 tests passed, process.json exit 0 in GH-179-REC-S6-PARENT-20261026-0340. No product/device acceptance.

## Root cause and public seam

`PendingStorageDeletes.cancel` (lib/services/pending_storage_deletes.dart:42-49) ignores `setStringList` false. Installed shared_preferences 2.5.6 `shared_preferences_legacy.dart:202-211` updates its cache **before** platform persistence, including failures. Therefore simply throwing on false is insufficient: a subsequent cancel sees the mutated empty cache and returns without repairing the durable queue. Public seam: cancel → retry → prefs.reload → fresh queue sweep with fake Storage. Simulate false and thrown platform writes using the installed platform interface, not a mocked queue. Real process restart/power-loss durability is NOT established by reload.

## Required bounded slices (aggregate stays open)

- GH-179-REC-S6-Q: queue source/existing service test pair; false and throw reject cancellation; reload failed cache so retry reaches platform, then fresh queue sweep must preserve cancelled audio. Preserve current successful cancellation and sweep races. A persistence error must never be reported as successful cancellation.
- GH-179-REC-S6-R: Recorder source/existing screen test pair. Undo must await cancellation before restoring attachment-backed documents; catch failure with safe retry feedback. Existing Undo starts saveEntry and cancel independently (recorder_screen.dart:254-255). Failed document delete/revocation cleanup can leave durable queue state: retain explicit recovery blocker, not a claim that generic error text makes audio safe.
- GH-179-REC-S6-L: Song Lab source/existing screen test pair. Same cancellation-before-restore constraint for attachments (song_lab_screen.dart:233-234), including failed-delete cleanup feedback.
- GH-179-REC-S6-F: repository/existing public repository test seam preflight. saveEntry awaits cancellation for midiSong.fileUrl only (firestore_lab_repository.dart:63-70), not recording attachmentIds. Register exact source/test pair before implementation; shared save restoration must not bypass the cancellation boundary. Do not duplicate caller protections as a substitute for shared validation.

## Limits / unresolved safety gate

Prefs success is not a cross-process durability acknowledgement on every platform (installed plugin docs lines 182-187). Cancellation cannot reverse a Storage deletion already in flight. On a failed cancellation while its owning document still exists, a durable URL can remain eligible for next-launch sweep. Queue-only error propagation is NOT restart-safe recovery. REC-S6 cannot close until this boundary has a conservative design/test (for example checking owning-document existence before deletion, within approved REC-S2/S3 identity/authority scope); no owner policy or new storage migration is silently assumed. Tests must retain this distinction. No real Storage calls, user-data edits, model retries, installs or releases.
