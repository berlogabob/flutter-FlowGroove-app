#!/usr/bin/env bash
# Ledger for EVENT_SHARING_BACKLOG.md (epic #180). One check per E-item.
# ponytail: greps, not a test framework. Items needing a live project or a
# browser print SKIP and name the manual command instead of faking a pass.
cd "$(dirname "$0")/.."
fail=0

chk()  { if [ "$2" = "$3" ]; then printf 'E%-3s PASS  %s\n' "$1" "$4"
         else printf 'E%-3s FAIL  %s (got %s, want %s)\n' "$1" "$4" "$2" "$3"; fail=1; fi; }
has()  { [ "$(grep -c "$1" "$2")" -gt "${3:-0}" ] && echo yes || echo no; }
skip() { printf 'E%-3s SKIP  %s\n' "$1" "$2"; }

EV=functions/src/events.js

chk 1 "$(grep -c "collection('setlists')\|collection('bands')" lib/services/firestore_service.dart)" 0 \
  "FirestoreService owns no direct Firestore collection calls"
chk 2 "$(has 'expiresAt' $EV)" yes "share tokens carry expiresAt, honoured in resolveToken"
chk 3 "$(has 'suggestionCount' $EV)" yes "per-token suggestion cap exists"
chk 4 "$(has 'ownSuggestions\|mySuggestions' $EV)" yes "getEventView returns the caller's own suggestions"
chk 5 "$(has 'getAll(' $EV)" yes "getEventView song fan-out uses db.getAll"
chk 6 "$(has 'createShare\|claimShare\|revokeShare' test/services/event_share_service_test.dart 3)" yes \
  "client share write wrappers are tested"
chk 7 "$(grep -rn 'resolveSuggestion' lib --include='*.dart' | grep -vc event_share_service | \
        awk '{print ($1>0)?"yes":"no"}')" yes "a screen calls resolveSuggestion (suggestions inbox)"

# E8/E9 are settled; the checks that prove them are not greps over this repo.
printf 'E%-3s DONE  %s\n' 8 "guestUids exemption cleared 2026-08-22 -- reverify: gcloud firestore indexes fields describe guestUids --collection-group=setlists"
chk 9 "$(has 'appUserProvider).isLoading' lib/screens/bands/join_band_screen.dart)" yes \
  "the join gate treats a still-loading user document as demo"
printf 'E%-3s DONE  %s\n' 10 "/event rendered in a browser 2026-10-12 (venue + engineer links, scoping correct); claim/edit and console not checked -- see EVENT_SHARING_BACKLOG.md E10"

exit $fail
