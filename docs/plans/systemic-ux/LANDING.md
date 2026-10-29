# Landing pack — implementation tracker (Claude + Codex, from 2026-10-26)
Executor: Claude verifies/commits, Codex edits. Gate per slice: RED→GREEN, full `flutter test`, commit. Device/human verification stays with the owner.

## Done (GH-179)
- [x] VOTE 6c902a29 · LEGACY-M 4bcc3931 · LEGACY-A e6fb043f · LEGACY-U 06bcfc12 · REC-S2 4ae08e59

## UX (DESIGN-01 approved as written 2026-10-26)
- [x] UX-005 89d46e32 · last-practice-context record + Resume card (no autoplay)
- [x] UX-008 microtext onto shared type scale
- [x] UX-002 stable global More menu
- [x] UX-003 view-first song open (supersedes Edit-first, owner-approved via DESIGN-01)
- [x] UX-001 Practice entry consolidation (Progress title, Start practice, Tools)

## Event sharing (host: app.flowgroove.app)
- [x] GH-186-URL central base-URL helper (lib/utils/event_share_url.dart)
- [x] GH-189 L1 canonical URL (hash form kept, origin app.flowgroove.app) · [ ] L2 assetlinks · L3 iOS entitlement · L4 hosting AASA
- [x] GH-187 proposals wiring: S1 80794e78 (candidates backend) · S2/S3 0eb9a29b (publisher toggles, guest picker) · S4 (typed proposals in inbox) — owner policy: publisher-picked list. NOT deployed (needs functions+rules deploy)

## GH-179 remaining
- [x] REC-S3 9f31bd30 · REC-S6 2ebb6b5a · REC-S6-F fe5ed3c2 · [ ] LAB aggregate · TUNER-I aggregate
- [ ] AUDIO-I, DELETE-OWNER (owner decision)

## Final
- [ ] FINAL-TEST full suite · FINAL-DOCS · owner device verification · release
