# GH-179-AUDIO-R — independently accepted source contract

Evidence: CODE only, reviewed by Hermes. No emulator, deployed-rule, device, real Storage or repaired-product credit.

## Confirmed predicates

- `storage.rules:4-8`: Storage demo restriction reads only `request.auth.token.get('demo', false) != true`. With an absent claim the restriction permits the operation, provided the other predicates pass. This does not establish equivalence to the app role. The comment saying no code mints this claim is not a repository-wide or deployment proof.
- `firestore.rules:21-37`: Firestore demo restriction reads `users/{uid}.accessRole`, defaulting missing document/field to `member`. The two enforcement inputs differ.
- `storage.rules:45-50`: personal audio read requires authenticated matching uid; create/update also requires non-demo claim and size strictly below 25 MiB. Delete has a separate matching-uid/non-demo allow. `allow write` includes delete, but its `request.resource.size` cannot establish delete permission; the explicit delete allow is the relevant additional grant. Firebase allows are additive, not sequential restrictions.
- `storage.rules:15-19,51-58`: band audio read permits any authenticated user. Create/update requires band `memberUids` membership, non-demo claim and size below 25 MiB; delete requires membership/non-demo claim. No editor/admin distinction or object-author check. Comments suggesting app-only gating are stale relative to the actual membership predicate; a comment is not effective policy or a failed production request.
- `firestore.rules:324-336`: band Lab documents read requires band membership; create/update requires non-demo app role and editor/admin. Delete requires non-demo and editor/admin OR matching entry author. The author branch has no separate membership conjunct; do not silently add one when describing the actual rule.
- `firestore.rules:538-543`: personal Lab documents read permits owner or the existing admin/owner helper; writes require authenticated owner and non-demo app role. Document authority does not imply Storage object authority, or vice versa.

## Upload/save/link boundaries

- `lib/services/storage_service.dart:69-88`: signed-in user, client size check rejecting >=25 MiB, `lab_audio/{user/currentUid|band/bandId}/{songId}/{entryId}.{ext}`, upload then download URL. No app-role check. Actual Storage requests remain subject to independently deployed rules.
- `lib/services/idea_recorder.dart:25-87`: recording sheet precedes upload; target is the supplied song or `_inbox`; uid is read after upload, defaulting to empty string. Upload identity and saved author are not snapshotted together. Upload can succeed before document save fails or becomes ambiguous. Catch labels every error as upload failure. No destructive compensation is performed; adding blind cleanup would risk deleting committed audio.
- `lib/services/idea_recorder.dart:94-116`: link saves destination with existing entry id/attachments before deleting inbox source; destination omits bandId. It neither moves nor deletes the object. Destination success followed by source-delete failure can leave both records. Scope/authority and deterministic reconciliation remain REC-S2/REC-S3, not REC-S6.
- `lib/services/storage_service.dart:307-326`: deleteByUrl starts deletion and returns true for success/not-found, false for other errors. Cancellation cannot reverse an already-started deletion. Durable cancellation persistence remains REC-S6; accepted S5 only fixes queue snapshot/concurrent-enqueue races.

## Missing evidence and bounded follow-up

1. AUDIO-I remains blocked on explicit approved object read/write/delete and demo identity policy (`requires_approval` retained). Before implementation inspect exact claim provisioning/refresh and demo source plus existing public Storage-rule tests. Do not infer claim issuance from a comment or broaden/restrict band access without approval. Test claim absent/true/false separately from Firestore app roles; personal ownership, band membership vs editor/admin, read/write/delete, exact size boundary and cross-service lookup failure. Emulator evidence would still not prove deployed policy.
2. REC-S2 requires the existing public shared capture/link seam, Firebase/platform upload injection and every real caller. Preserve original uid/target/author across awaits and recheck current authorization without switching identity or deleting unknown objects.
3. REC-S3 requires exact repository save/read/delete semantics and deterministic server-path reconciliation. Cached absence, failed readback or an exception is not proof of noncommit. Never enqueue destructive cleanup while a document may reference the upload.
4. REC-S6 is specifically cancellation persistence false/throw/restart safety, not upload/save/link recovery. Its source/test preflight and aggregate gates remain open.

## Independent acceptance

Original Luna stream contains four allowlisted source reads and one assigned report write; nonempty final and exit 0. Original exact-model server terminal stop at 2026-10-25T20:54:32.448Z. Hermes checked primary/warm source identities and the actual predicates/sequencing, corrected absent-claim wording, additive delete grants, author-delete membership description, stale-comments interpretation and wrong REC-S6 assignment. The original worker draft remains private as evidence. No production code changed and no security issue or release gate is closed by this review.
