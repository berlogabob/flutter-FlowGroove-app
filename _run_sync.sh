#!/usr/bin/env bash
set -uo pipefail
cd /Users/berloga/Documents/GitHub/flutter_repsync_midi
timeout 600 flutter test test/midi/drum_sync_test.dart 2>&1 | tail -45
