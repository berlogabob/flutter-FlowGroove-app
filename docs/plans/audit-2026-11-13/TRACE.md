# Trace — problem -> task -> executor/verdict -> commit

| Problem | Task | File | Result | Commit |
|---|---|---|---|---|
| M-02 | M-02-a Gradle wrapper 9.5.0 | android/gradle/wrapper/gradle-wrapper.properties | pass via pi | 77d860db |
| M-02 | M-02-b AGP 9.3.1 and Kotlin 2.4.20 | android/settings.gradle.kts | pass via pi | 72bc340b |
| M-04 | M-04-a Dart SDK constraint 3.14 | pubspec.yaml | pass via pi | 0f2e3d54 |
| F-001 | F-001-a Allow resume navigation from Progress | lib/widgets/practice_resume_card.dart | pass via pi | 92f9517d |
| F-001 | F-001-b Open song directly from Progress | lib/screens/practice_screen.dart | pass via pi | a9ce88b0 |
| F-002 | F-002-a Allow delete in song card menu | lib/widgets/unified_item/song_card_actions.dart | pass via pi | 31415c65 |
| F-002 | F-002-b Connect list menu to existing deletion | lib/screens/songs/songs_list_screen.dart | pass via pi | 7a103c86 |
| F-002 | F-002-c Add confirmed deletion to song page | lib/screens/songs/song_page_screen.dart | pass via pi | 4f4bd3d6 |
| F-003 | F-003-a Put manual song fields first | lib/screens/songs/components/song_form.dart | pass via pi | 442ab17f |
| F-005 | F-005-a Improve dial note contrast | lib/widgets/tuner/central_dial.dart | pass via pi | 79b550a8 |
| F-005 | F-005-b Improve outer tick contrast | lib/widgets/tuner/tick_marks.dart | pass via pi | ec8afea6 |
| F-007 | F-007-a Label and enlarge key selectors | lib/screens/songs/components/bpm_selector.dart | FAIL x5: /songs/add_song_screen_test.dart: AddSongScreen displays key selector dropdowns  |  |
| F-007 | F-007-b Update version label assertions | test/screens/songs/add_song_screen_test.dart | pass via pi |  |
| F-008 | F-008-a Label beat controls and states | lib/widgets/metronome/time_signature_block.dart | pass via pi | 96f11aa6 |
| F-008 | F-008-b Enlarge beat tap targets | lib/widgets/metronome/time_signature_block.dart | FAIL x5: one column grid (F-019) cell width is shared even when the clamp is not in play  |  |
| F-008 | F-008-c Update tap target assertion | test/widgets/metronome/time_signature_grid_test.dart | FAIL x4:  |  |
| F-009 | F-009-a Identify the listen mode | lib/screens/tuner_screen.dart | pass via pi | 855e1aa4 |
| F-009 | F-009-b Label the microphone action | lib/widgets/tuner/transport_bar.dart | pass via pi | 59effe83 |
| F-009 | F-009-c Clarify the idle instruction | lib/widgets/tuner/central_dial.dart | pass via codex | dbbe29ae |
| F-009 | F-009-d Enlarge detection mode targets | lib/widgets/tuner/detection_mode_toggle.dart | pass via codex | 6df7d53a |
| F-009 | F-009-e Enlarge dial note targets | lib/widgets/tuner/central_dial.dart | pass via codex | 2d1ff9ba |
| F-010 | F-010-a Label and enlarge playback control | lib/screens/songs/components/lab_recording_sheet.dart | pass via codex | 22744261 |
| F-010 | F-010-b Name recorder playback and menus | lib/screens/recorder_screen.dart | pass via pi | 7464c036 |
| F-011 | F-011-a Label the search field | lib/widgets/unified_item/unified_filter_sort_widget.dart | pass via pi | 85ca7b84 |
| F-011 | F-011-b Support action icon semantic labels | lib/widgets/unified_item/unified_item_model.dart | pass via pi | 2e9e0a2d |
| F-011 | F-011-c Identify songs in action labels | lib/widgets/unified_item/song_card_actions.dart | pass via pi | 199d29b8 |
| F-012 | F-012-a Label the bands search field | lib/widgets/unified_item/unified_filter_sort_widget.dart | pass via pi | b0a0adec |
| F-012 | F-012-b Remove duplicate band row semantics | lib/widgets/unified_item/unified_item_list.dart | pass via pi | c77b5698 |
| F-012 | F-012-c Allow contextual overflow labels | lib/widgets/unified_item/unified_item_model.dart | FAIL x4:  |  |
| F-012 | F-012-d Add band names to action labels | lib/screens/bands/my_bands_screen.dart | pending |  |
| F-013 | F-013-a Label the search field | lib/widgets/unified_item/unified_filter_sort_widget.dart | pass via pi | c2395cc3 |
| F-013 | F-013-b Label setlist row taps | lib/widgets/unified_item/unified_item_card.dart | pass via pi | 088a5473 |
| F-013 | F-013-c Remove duplicate setlist tap semantics | lib/widgets/unified_item/unified_item_list.dart | pass via pi | fec65a43 |
| F-013 | F-013-d Allow named overflow tooltips | lib/widgets/unified_item/unified_item_model.dart | FAIL x4:  |  |
| F-013 | F-013-e Support named setlist actions | lib/widgets/unified_item/setlist_card_actions.dart | pending |  |
| F-013 | F-013-f Name actions on setlist rows | lib/screens/setlists/setlists_list_screen.dart | pending |  |
| F-014 | F-014-a Label song search for accessibility | lib/widgets/autocomplete_type_ahead.dart | pass via pi | cda309bd |
| F-014 | F-014-b Label title and artist fields | lib/screens/songs/components/song_form.dart | pass via pi | ceed1e26 |
| F-015 | F-015-a Label band form fields for accessibility | lib/screens/bands/create_band_screen.dart | pass via pi | 3b0a437e |
| F-016 | F-016-a Label the required setlist name | lib/screens/setlists/create_setlist_screen.dart | pass via pi | 412ba2fd |
| F-016 | F-016-b Expose event details toggle state | lib/screens/setlists/create_setlist_screen.dart | pass via pi | 941a3aa9 |
| F-017 | F-017-a Persist session song titles | lib/models/metronome_session.dart | pass via pi | dd33d29f |
| F-017 | F-017-b Capture metronome song title | lib/providers/data/metronome_provider.dart | pass via pi | eba2f122 |
| F-017 | F-017-c Capture practice region context | lib/screens/practice_regions_screen.dart | FAIL x4: bash: ? 'Section ${index + 1}': bad substitution  |  |
| F-017 | F-017-d Show saved titles in history | lib/screens/practice_screen.dart | pass via pi | 7865d8d3 |
| F-018 | F-018-a Add stage mode exit control | lib/screens/performance_sheet_screen.dart | pass via pi | 946942da |
| F-019 | F-019-a Label transpose units | lib/widgets/performance_sheet_view.dart | pass via pi | b5048589 |
| F-019 | F-019-b Show transposed key in header | lib/screens/songs/song_page_screen.dart | FAIL x4: se)}',                                                                     ^^^^  |  |
| F-020 | F-020-a Scroll metronome controls into view | lib/screens/songs/components/song_form.dart | pass via pi | cb7f444a |
| F-021 | F-021-a Update key chip test | test/screens/songs/songs_list_screen_test.dart | pass via pi | 72325998 |
| F-021 | F-021-b Show enharmonic key names | lib/screens/songs/songs_list_screen.dart | pass via pi | dcaf24e5 |
| F-022 | F-022-a Clarify empty editor guidance | lib/screens/songs/song_editor_screen.dart | pass via codex | 0968e177 |
| F-023 | F-023-a Increase tag filter row height | lib/widgets/tag_cloud_widget.dart | pass via pi | 2c29df0a |
| F-025 | F-025-a Label and enlarge play controls | lib/screens/setlists/setlist_view_screen.dart | pass via pi | 88c7ae5b |
| F-027 | F-027-a Show filter above navigation | lib/screens/songs/songs_list_screen.dart | pass via pi | 6d7af159 |
| F-028 | F-028-a Shorten songs search placeholder | lib/screens/songs/songs_list_screen.dart | FAIL x4: reen_test.dart: SongsListScreen renders songs list screen with title and search  |  |
| F-028 | F-028-b Update search placeholder assertion | test/screens/songs/songs_list_screen_test.dart | pass via pi |  |
| F-029 | F-029-a Wrap the song detail title | lib/screens/songs/song_page_screen.dart | pass via pi | 9ac34047 |
| F-030 | F-030-a Make tool labels consistently readable | lib/screens/practice_screen.dart | FAIL x4: _test.dart: song titles resolve after loading and cached titles survive refresh  |  |
| F-031 | F-031-a Separate and wrap session details | lib/screens/practice_screen.dart | pass via pi | bb83c5be |
| F-034 | F-034-a Improve empty-state text contrast | lib/screens/songs/components/song_constructor/song_constructor.dart | pass via pi | 5da0f734 |
| F-035 | F-035-a Label the card destination | lib/widgets/practice_dashboard_card.dart | pending |  |
| F-035 | F-035-b Update card label assertions | test/widgets/practice_dashboard_card_test.dart | FAIL x4: PracticeDashboardCard (#133) readonly empty card does not announce a tap action  |  |
| F-035 | F-035-c Use consistent menu destination | lib/screens/main_shell.dart | pending |  |
| F-035 | F-035-d Update menu label assertion | test/screens/songs/songs_list_screen_test.dart | FAIL x4: _screen_test.dart: SongsListScreen four roots expose the same global More items  |  |
| F-036 | F-036-a Timeout stalled homework requests | lib/providers/homework_provider.dart | pass via codex | 2e489b20 |
| F-037 | F-037-a Keep section icons stationary | lib/screens/songs/components/collapsible_section.dart | pass via pi | db2b74b0 |
| F-038 | F-038-a Use control font for sort labels | lib/widgets/unified_item/unified_filter_sort_widget.dart | pass via pi | 3755eebe |
| F-040 | F-040-a Align More metronome icon | lib/screens/main_shell.dart | pass via pi | 1569ffec |
| F-040 | F-040-b Update Home icon assertion | test/screens/home_screen_test.dart | FAIL x4: reens/home_screen_test.dart: HomeScreen renders tool buttons with correct icons  |  |
| F-040 | F-040-c Align Home metronome icon | lib/screens/home_screen.dart | pending |  |
| F-040 | F-040-d Align Progress metronome icon | lib/screens/practice_screen.dart | pass via pi | fb5de7ad |
| M-05 | M-05-a Migrate remove selection to RadioGroup | lib/screens/setlists/event_share_screen.dart | pass via codex | 7848723b |
| M-05 | M-05-b Migrate reorder callback | lib/screens/setlists/event_share_screen.dart | pass via pi | 428f30c4 |
| M-05 | M-05-c Read picked bytes through supported API | lib/utils/picked_file.dart | pass via pi | ce9abfab |
| M-05 | M-05-d Migrate practice card opacity | lib/widgets/practice_dashboard_card.dart | pass via pi | 6b05411a |
| M-09 | M-09-a Remove stale analyzer plugin | analysis_options.yaml | pass via pi |  |
| M-10 | M-10-a Use Wasm-safe audio context check | lib/services/audio/backing_engine_web.dart | pass via pi | 04162817 |
| F-007 | F-007-a-r repair: Label and enlarge key selectors | lib/screens/songs/components/bpm_selector.dart | pass via codex | 71fbc98a |
| F-008 | F-008-b-r repair: Enlarge beat tap targets | lib/widgets/metronome/time_signature_block.dart | pass via codex | f4887f0e |
| F-012 | F-012-c-r repair: Allow contextual overflow labels | lib/widgets/unified_item/unified_item_model.dart | FAIL x1:  |  |
| F-013 | F-013-d-r repair: Allow named overflow tooltips | lib/widgets/unified_item/unified_item_model.dart | FAIL x1:  |  |
| F-017 | F-017-c-r repair: Capture practice region context | lib/screens/practice_regions_screen.dart | FAIL x1: bash: ? 'Section ${index + 1}': bad substitution  |  |
| F-019 | F-019-b-r repair: Show transposed key in header | lib/screens/songs/song_page_screen.dart | pass via codex | 1b7c4808 |
| F-028 | F-028-a-r repair: Shorten songs search placeholder | lib/screens/songs/songs_list_screen.dart | pass via codex | 399d4c71 |
| F-030 | F-030-a-r repair: Make tool labels consistently readable | lib/screens/practice_screen.dart | pass via codex | ed253b37 |
| F-035 | F-035-b-r repair: Update card label assertions | test/widgets/practice_dashboard_card_test.dart | FAIL x1: PracticeDashboardCard (#133) readonly empty card does not announce a tap action  |  |
| F-035 | F-035-d-r repair: Update menu label assertion | test/screens/songs/songs_list_screen_test.dart | FAIL x1: _screen_test.dart: SongsListScreen four roots expose the same global More items  |  |
| F-040 | F-040-b-r repair: Update Home icon assertion | test/screens/home_screen_test.dart | FAIL x1: reens/home_screen_test.dart: HomeScreen renders tool buttons with correct icons  |  |
| F-012 | F-012-c-r2 repair: repair: Allow contextual overflow labels | lib/widgets/unified_item/unified_item_model.dart | pass via codex | 680a2abe |
| F-013 | F-013-d-r2 repair: repair: Allow named overflow tooltips | lib/widgets/unified_item/unified_item_model.dart | FAIL x3:  |  |
| F-017 | F-017-c-r2 repair: repair: Capture practice region context | lib/screens/practice_regions_screen.dart | pass via codex | 27443912 |
| F-035 | F-035-b-r2 repair: repair: Update card label assertions | test/widgets/practice_dashboard_card_test.dart | pass via codex | dcbc2ad1 |
| F-035 | F-035-d-r2 repair: repair: Update menu label assertion | test/screens/songs/songs_list_screen_test.dart | FAIL x3:  |  |
| F-040 | F-040-b-r2 repair: repair: Update Home icon assertion | test/screens/home_screen_test.dart | FAIL x3:  |  |
| F-004 | F-004-a Store song details on setlist items | lib/models/setlist.dart | pass via codex | e7215bbb |
| F-004 | F-004-b Show unavailable song details | lib/widgets/setlist_song_row.dart | pass via codex | 9c19f72d |
| F-004 | F-004-c Save and show song snapshots | lib/screens/setlists/create_setlist_screen.dart | pass via codex | 5be9c455 |
| F-004 | F-004-d Open review directly from setlist | lib/screens/setlists/setlist_view_screen.dart | FAIL x1: est.dart: SetlistViewScreen distinguishes song-load error from unresolved songs  |  |
| N-002 | N-002-a Add band names to action labels | lib/screens/bands/my_bands_screen.dart | pass via codex | c1cb246c |
| N-003 | N-003-a Support named setlist actions | lib/widgets/unified_item/setlist_card_actions.dart | pass via codex | 539231bf |
| N-003 | N-003-b Name actions on setlist rows | lib/screens/setlists/setlists_list_screen.dart | pass via codex | 8e0cc3ef |
| N-004 | N-004-a Label the card destination | lib/widgets/practice_dashboard_card.dart | pass via codex | 7f09565f |
| N-004 | N-004-b Match the More menu destination | lib/screens/main_shell.dart | pass via codex | d0e0de21 |
| N-005 | N-005-a Align Home metronome icon | lib/screens/home_screen.dart | pass via codex | 03bae384 |
| F-008 | F-008-c-r repair: Update tap target assertion | test/widgets/metronome/time_signature_grid_test.dart | pass via codex | 1fd58088 |
| F-004 | F-004-d-r repair: Open review directly from setlist | lib/screens/setlists/setlist_view_screen.dart | pass via codex | bbb7ff40 |
| M-06 | M-06-0 Add material_ui dependency | pubspec.yaml | pass via codex | a66cd6f2 |
| M-06 | M-06-1 material_ui imports in lib/screens/ | lib/screens/ | FAIL x1: ditor_test.dart: band viewers cannot change or save the grid   ... and 463 more  |  |
| M-06 | M-06-2 material_ui imports in lib/widgets/ | lib/widgets/ | pending |  |
| M-06 | M-06-3 material_ui imports in lib/services/ | lib/services/ | pending |  |
| M-06 | M-06-4 material_ui imports in lib/providers/ | lib/providers/ | pending |  |
| M-06 | M-06-5 material_ui imports in lib/router/ | lib/router/ | pending |  |
| M-06 | M-06-6 material_ui imports in lib/theme/ | lib/theme/ | pending |  |
| M-06 | M-06-7 material_ui imports in lib/models/ | lib/models/ | pending |  |
| M-06 | M-06-8 material_ui imports in lib/repositories/ | lib/repositories/ | pending |  |
| M-06 | M-06-9 material_ui imports in lib/utils/ | lib/utils/ | pending |  |
| M-06 | M-06-10 material_ui imports in lib/analytics/ | lib/analytics/ | pending |  |
| M-06 | M-06-11 material_ui imports in lib/config/ | lib/config/ | pending |  |
| M-06 | M-06-12 material_ui imports in lib/dev/ | lib/dev/ | pending |  |
| M-06 | M-06-13 material_ui imports in lib/domain/ | lib/domain/ | pending |  |
| M-06 | M-06-14 material_ui imports in test/ | test/ | pending |  |
| M-06 | M-06-15 material_ui imports in integration_test/ | integration_test/ | pending |  |
| M-06 | M-06-16 material_ui imports in lib root files | lib/ | pending |  |
| M-07 | M-07-1 dart fix remaining codes in lib | lib/ | pass via codex | 7fff2ea3 |
| M-07 | M-07-2 dart fix remaining codes in test | test/ | pass via codex |  |
| M-11 | M-11-a Same-major dependency upgrades | pubspec.lock | pass via codex | 90a9526a |
| A-01 | A-01-a Label-driven crawler and flows in scripts/audit_crawl | scripts/audit_crawl/ | pass via codex | b5426791 |
| A-02 | A-02-a covered by A-01-a (verify only) | scripts/audit_crawl/ | pass via codex |  |
| A-04 | A-04-a covered by A-01-a (verify only) | scripts/audit_crawl/ | pass via codex |  |
| M-06 | M-06-all material_ui imports, whole repo at once | lib/ | pass via codex |  |
| M-08 | M-08-01 analyzer warnings in band.dart | lib/models/band.dart | pass via pi | a4f5fc05 |
| M-08 | M-08-02 analyzer warnings in canonical_song.dart | lib/models/canonical_song.dart | pass via pi | 2935122c |
| M-08 | M-08-03 analyzer warnings in setlist.dart | lib/models/setlist.dart | pass via pi | d0d05f32 |
| M-08 | M-08-04 analyzer warnings in song.dart | lib/models/song.dart | pass via pi | b74f9be7 |
| M-08 | M-08-05 analyzer warnings in song_commit.dart | lib/models/song_commit.dart | pass via pi | 45c51c9f |
| M-08 | M-08-06 analyzer warnings in song_delta.dart | lib/models/song_delta.dart | pass via pi | 7f804c3d |
| M-08 | M-08-07 analyzer warnings in song_lab.dart | lib/models/song_lab.dart | pass via pi | 5042aaf4 |
| M-08 | M-08-08 analyzer warnings in user.dart | lib/models/user.dart | pass via pi | 5d9e7ba9 |
| M-08 | M-08-09 analyzer warnings in analytics_service.dart | lib/services/analytics_service.dart | pass via pi | d1941782 |
| M-08 | M-08-10 analyzer warnings in song_csv_schema.dart | lib/services/csv/song_csv_schema.dart | pass via pi | 3b014819 |
| M-08 | M-08-11 analyzer warnings in song_json_codec.dart | lib/services/json/song_json_codec.dart | pass via pi | f9ec33da |
| M-08 | M-08-12 analyzer warnings in song_library_block.dart | lib/widgets/metronome/song_library_block.dart | pass via pi | 92809f45 |
| M-08 | M-08-13 analyzer warnings in export_band_data.dart | scripts/export_band_data.dart | pass via pi | f68b66ed |
| M-08 | M-08-14 analyzer warnings in test_music_apis.dart | scripts/test_music_apis.dart | pass via pi | 275efe43 |
| M-08 | M-08-15 analyzer warnings in test_helpers.dart | test/helpers/test_helpers.dart | pass via pi | c0591dd8 |
| M-08 | M-08-16 analyzer warnings in api_integration_test.dart | test/integration/api_integration_test.dart | pass via codex | bc958383 |
| M-08 | M-08-17 analyzer warnings in metronome_flow_test.dart | test/integration/metronome_flow_test.dart | pass via pi | 6ebab02a |
| M-08 | M-08-18 analyzer warnings in metronome_timing_test.dart | test/integration/metronome_timing_test.dart | pass via codex | aa3599de |
| M-08 | M-08-19 analyzer warnings in band_test.dart | test/models/band_test.dart | pass via pi | 409d0471 |
| M-08 | M-08-20 analyzer warnings in setlist_test.dart | test/models/setlist_test.dart | pass via pi | 3ccbb9df |
| M-08 | M-08-21 analyzer warnings in song_metronome_test.dart | test/models/song_metronome_test.dart | pass via codex | 5954b8f1 |
| M-08 | M-08-22 analyzer warnings in song_test.dart | test/models/song_test.dart | pass via pi | ae246a2a |
| M-08 | M-08-23 analyzer warnings in user_test.dart | test/models/user_test.dart | pass via pi | f54bb8d3 |
| M-08 | M-08-24 analyzer warnings in auth_provider_test.dart | test/providers/auth_provider_test.dart | pass via pi | 7a3ce37c |
| M-08 | M-08-25 analyzer warnings in error_provider_test.dart | test/providers/error_provider_test.dart | pass via pi | 3bef4fb1 |
| M-08 | M-08-26 analyzer warnings in firestore_metronome_test.dart | test/services/firestore_metronome_test.dart | pass via codex | cb82f67d |
| M-08 | M-08-27 analyzer warnings in pdf_service_test.dart | test/services/pdf_service_test.dart | pass via pi | fa5c7537 |
| M-08 | M-08-28 analyzer warnings in wall_clock_scheduler_test.dart | test/services/wall_clock_scheduler_test.dart | pass via codex | be0d490e |
| N-006 | N-006-a Give tuning names more room | lib/widgets/tuner/instrument_picker.dart | pass via codex | 67dfba42 |
| N-007 | N-007-a Limit beat pattern button size | lib/screens/songs/components/metronome_pattern_editor.dart | pass via codex | 9fce5ec3 |
| N-008 | N-008-a Move dial marker inside note labels | lib/widgets/tuner/central_dial.dart | pass via codex | a673058e |
| N-009 | N-009-a Show autofill search hint | lib/widgets/autocomplete_type_ahead.dart | pass via codex | 8e9b2b3b |
| N-010 | N-010-a Add scroll clearance below song form | lib/screens/songs/add_song_screen.dart | pass via codex | 2d4dbfdc |
| N-011 | N-011-a Keep band rows clear of FAB | lib/screens/bands/my_bands_screen.dart | pass via codex | e0edd27c |
| N-013 | N-013-a restore tap-to-open on list cards | lib/widgets/ | pass via codex | 91bcaef6 |
