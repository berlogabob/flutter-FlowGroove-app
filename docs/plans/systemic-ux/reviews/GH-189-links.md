# GH-189-L0 — independently accepted source preflight

Evidence: CODE only. Parent checked the ten registered sources against primary and warm checkout; all were byte-identical at review. Worker draft remains in the private warm checkout; this report corrects overstatements rather than treating a model response as acceptance. No live ownership, signing, hosting, native handoff or GA4 checks.

## Confirmed contract and gaps

- `lib/screens/setlists/event_kit_editor_screen.dart:171-197` generates `https://app.flowgroove.app/#/event?t=$token` after successful minting, then copies it. Preserve existing links and token integrity. `lib/router/app_router.dart:190-198,310-320` exempts `/event` and `/event/` from auth redirect and builds the public event screen with `t`, `ownerUid`, `setlistId`. This proves source routing, not native fragment delivery.
- `lib/router/app_router.dart:200-225,291-307` preserves external join handling, including auth restoration and missing-code fallback. Do not disturb `/join` compatibility.
- `android/app/src/main/AndroidManifest.xml:38-62` enables Flutter deep links but verifies only HTTPS `flowgroove.app` with `/join` prefix. Generated event host is different. Fragment routes are not HTTP paths: an `/event` path filter does not match the current `/#/event` URL. This does NOT prove fragment URLs can never be delivered by a broader native filter; any such policy needs deliberate scope and runtime tests. Do not silently broaden all root URLs.
- `site/hugo.toml:1,52-55,151-155` distinguishes marketing `flowgroove.app` from app `app.flowgroove.app`. `.firebaserc:1-5` selects `repsync-app-8685c`. These are configured intent, not proof of domain control or current deployment.
- `site/static/.well-known/assetlinks.json:1-13` contains Android package `com.flowgroove.app` and two syntactically valid SHA-256 fingerprints. Neither manifest nor this asset proves the Gradle applicationId or fingerprint provenance/current Play signing identity. No fingerprint replacement authorized.
- `firebase.json:27-47` publishes `build/web`, ignores hidden files and has a catch-all SPA rewrite. Hugo static assets are not shown as copied to that output. A source/output inventory must precede Hosting edits; live JSON/content type must be checked later. Existing static files normally precede SPA rewrites, so the catch-all alone is not proof of a deployed defect.
- Tracked inventory contains no iOS entitlement or AASA. `ios/Runner.xcodeproj/project.pbxproj` contains no `CODE_SIGN_ENTITLEMENTS`; bundle ID is `com.flowgroove.app` in Profile/Debug/Release (Profile earlier in file, Debug/Release at 674-715), with tracked team `RC6V8UPV6X`. These are candidates, not validated signing or app-identifier-prefix evidence. `Info.plist:25-38` is Google Sign-In; `AppDelegate.swift:4-16` delegates through Flutter. No bespoke handler is not by itself a Flutter defect.

## Follow-up boundaries (not waived)

- L1 remains blocked on deliberate canonical native URL policy. Keep legacy hash URLs working; assess any path-based URL through existing clipboard/router tests, separately bounded source slices after A2.
- L2: recover actual Gradle applicationId and authoritative distributed signing identity; establish exact host/association output. Preserve join filter; native device acceptance remains V.
- L3: confirm signing/app identifier prefix and exact intended domains before registering entitlement/project slices. Candidate `ios/Runner/Runner.entitlements` is a proposed new path, not an existing artifact.
- L4: inspect source/build mapping for the real Hosting output before registering asset/config slices. Candidate AASA path is proposed only. No deploy or fabricated identifiers.

L0 completes bounded source classification, not resolution of every external prerequisite. L1–L4 stay blocked with these named uncertainties; research acceptance does not close GH-189 or count as a repaired product defect.
