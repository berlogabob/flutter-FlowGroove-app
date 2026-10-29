# GH-179-REC-R — independently reviewed recorder contract

CODE evidence only. Luna draft independently checked by Hermes against primary sources on 2026-10-25. This accepts research, not an audio/product/device fix; GH-179-LAB remains open.

## Confirmed source behavior

- `lib/services/idea_recorder.dart:25-75`: capture opens a recording sheet without shared authorization, uploads before reading the author uid, and saves without rechecking identity/authority across awaits. `StorageService.uploadLabAudio` binds the personal Storage path to current auth synchronously before its upload await (`storage_service.dart:69-87`); `FirestoreLabRepository.saveEntry` chooses the personal Firestore path later from current auth (`firestore_lab_repository.dart:29-70`). An account switch can therefore separate object owner, author and document owner.
- Parent searched all `lib`: capture callers are Recorder auto-start/Record (`recorder_screen.dart:36-62`) and Song Lab (`song_lab_screen.dart:640-649`); linkIdeaToSong has one Recorder caller. Song Lab start gates do not protect the shared awaits. Recorder exposes Record, edit navigation, link and delete without personal write gates (`recorder_screen.dart:55-65,127-193`). Playback/read navigation must remain available to permitted readers.
- `idea_recorder.dart:85-87` calls every error Upload failed, including Firestore save errors after a completed upload. No cleanup/reconciliation exists. A failed save response is not proof that no document committed. Do not delete uploaded audio on ambiguous outcome or reuse pending-delete queue for it.
- Recorder queues audio before deleting the document and has no cancel-on-rejection/revocation path (`recorder_screen.dart:171-193`). This can leave referenced audio queued after a denied/failed document delete. Undo saves without awaiting success then cancels the queue. Song Lab already cancels after enqueue when authority is lost (`song_lab_screen.dart:202-229`); its real delayed queue integration still needs verification.
- Repository entry deletion handles MIDI URLs, not recording attachment URLs (`firestore_lab_repository.dart:63-90`); preserve this distinction when checking screen-owned queue cancellation.

## Policy and corrections to worker recommendations

Firestore personal Lab create/update/delete requires authenticated non-demo owner (`firestore.rules:537-543`); band create/update requires non-demo editor/admin and delete additionally permits non-demo author (`:321-335`). Use current identity plus existing permission providers; do not invent a second role model. Fail closed on explicit loading/error, including retained cached data, not just null.

Storage band rules require membership, not editor/admin, and reads allow any authenticated account (`storage.rules:51-57`). Personal writes/delete require matching uid (`:45-49`). Critically, Storage `isNotDemo` checks a custom claim, with an explicit comment that no code mints it (`:4-8`): this is NOT established effective app-role demo protection. AUDIO-R/I retain the policy/security gate. Do not change rules here.

The worker overstated queue guarantees: `PendingStorageDeletes.cancel` wins only before flush's membership check; `flush` cannot revoke an already-started Storage deletion (`pending_storage_deletes.dart:54-57`). `sweep` deletes a snapshot without per-item cancellation recheck (`:74-82`). No general race-safety credit. Keep a separate queue concurrency regression/fix slice before audio acceptance.

Conservative capture contract: bind uid/song/band before opening work; require current same uid, current non-demo target authority and mounted caller before upload/save. Keep author/target stable. Denial after upload must not delete the object blindly. Uncertain save status must not be presented as confirmed failure or retried under a new id; exact-path server reconciliation and unavailable-read behavior need explicit preflight. A local cached read cannot prove server commit or non-commit. No automatic cleanup is approved by this research.

## Registered implementation slices and acceptance boundaries

- **GH-179-REC-S1:** existing rendered RecorderScreen seam; one production screen and existing screen test. Gate Record/auto-start and screen-owned mutation menus/callbacks; snapshot identity for open link/delete/Undo; recheck after selection/enqueue, cancel queued deletion if document deletion is not attempted or fails. Preserve authorized link/delete/Undo and read/play access. Shared capture/link awaits remain S2/S3, not accepted by S1.
- **GH-179-REC-S2:** shared capture/link identity and live-authority checks across all awaits. Blocked until existing Firebase/platform test seam and exact one-source/one-test lease are preflighted; no callback/dependency architecture prescribed without inspection.
- **GH-179-REC-S3:** stage-accurate save status and deterministic server reconciliation without deleting committed/unknown references. Blocked on exact repository/public service seam and reliable server-vs-cache behavior; no blind retry/cleanup.
- **GH-179-REC-S4:** Song Lab pending-enqueue cancellation and authorized recording Undo through existing rendered screen with controlled pending-delete fake; test-only unless a bounded source defect is reproduced.
- **GH-179-REC-S5:** pending-delete cancellation/flush/sweep concurrency through existing public PendingStorageDeletes tests. Reproduce before choosing minimal queue fix; never infer Undo wins once Storage deletion started.

REC-I is an aggregate of all five slices; LAB, GH-179-V and FINAL-TEST remain gated. Human/device/audio playback, real upload/network/auth transitions, deployed rules and issue closure are not verified. No raw account/device data published.

## Worker evidence

Original exact gpt-6-luna/openai-codex turn ended text_response(stop) at 18:15:54.267 UTC, CLI result exit 0, nonempty report. Fifteen actual tool events: ten exact reads, one report write, two filename discoveries and two broad searches outside the original exact window. Deviations retained; no strict allowlist-compliance claim. Parent verified ten primary/warm source identities and inspected existing RecorderScreen and pending-delete public test seams. No tests/builds were executed for this research acceptance.
