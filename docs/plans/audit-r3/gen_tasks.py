#!/usr/bin/env python3
"""Generates tasks.json for the audit-r3 plan (source of truth for task text). Run from repo root."""
import json
P='lib/widgets/metronome/drum_practice_panel.dart'; E='lib/screens/songs/components/drum_grid_editor.dart'
K='lib/widgets/midi/drum_kit_view.dart'; DM='lib/services/audio/midi/drum_map.dart'
M='lib/screens/metronome_screen.dart'; PR='lib/providers/data/drum_practice_provider.dart'
PT=['test/midi/drum_practice_panel_test.dart','test/midi/drum_panel_editor_entry_test.dart']
ET=['test/midi/drum_grid_editor_test.dart','test/midi/drum_grid_editor_usability_test.dart']
KT=['test/midi/drum_kit_view_test.dart','test/midi/drum_kit_view_layout_test.dart']
T=[]
def t(i,title,fnd,files,prompt,tests=(),add=(),rem=(),cont=(),after=()):
    T.append(dict(id=i,title=title,finding=fnd,files=list(files),prompt=prompt,tests=list(tests),
        must_add=[list(x) for x in add],must_remove=[list(x) for x in rem],must_contain=[list(x) for x in cont],after=list(after)))
t('R01','Chip selected color orange app-wide','F-004',['lib/theme/mono_pulse_theme.dart'],
 "In lib/theme/mono_pulse_theme.dart find the `chipTheme:` ChipThemeData (around line 806). Add `selectedColor: MonoPulseColors.accentOrange,` and a `checkmarkColor` plus `secondaryLabelStyle` (copy of the existing labelStyle) whose text color is the same foreground color the filled buttons use on accentOrange in this theme (look at filledButtonTheme foregroundColor), so a selected ChoiceChip/FilterChip is orange with readable text. Change nothing else.",
 ['test/theme/mono_pulse_scheme_test.dart'],add=[('lib/theme/mono_pulse_theme.dart',r'selectedColor:\s*MonoPulseColors\.accentOrange')])
t('R02','Drums sheet empty state','F-003',[P],
 "In `_DrumPracticePanelState.build` replace `if (midi.isEmpty) const Text('No MIDI patterns yet'),` with a left-aligned `Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...]))` containing: an `Icon(Icons.queue_music, color: Theme.of(context).colorScheme.onSurfaceVariant)`, SizedBox(height: 8), `Text('No MIDI patterns yet', style: Theme.of(context).textTheme.titleMedium)` (keep this exact title string), SizedBox(height: 4), and `Text('Import a MIDI drum file or build a pattern step by step to play along with the click.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))`. Because it is inside a `Column(children: [...])` use a collection-if as before.",
 PT,add=[(P,'Import a MIDI drum file')],cont=[(P,"No MIDI patterns yet")])
t('R03','Hide Play and speed until a pattern is loaded','F-003',[P],
 "In `_DrumPracticePanelState.build` wrap the Play `FilledButton.icon(...)` and the speed chips `Wrap(...)` (ChoiceChips 0.5/0.75/1.0) so they are only built when `pattern != null` (use `if (pattern != null) ...[ ... ]` inside the ListView children). Directly above the speed `Wrap` add `Text('Speed', style: Theme.of(context).textTheme.labelMedium)`. Update only the test assertions that expect Play/speed chips to exist while no pattern is loaded.",
 PT,add=[(P,r"if \(pattern != null\)"),(P,"'Speed'")],after=['R02'])
t('R04','Import and New pattern as an equal-width row','F-003',[P],
 "Replace the `Wrap` that contains `OutlinedButton.icon` (label 'Import .mid') and `TextButton.icon` (label 'New pattern') with `Row(children: [Expanded(child: <the OutlinedButton.icon unchanged>), const SizedBox(width: 12), Expanded(child: FilledButton.icon(<same icon, label, onPressed as the New pattern button>))])`. Keep both labels and both onPressed handlers exactly.",
 PT,add=[(P,'Expanded'),(P,r'FilledButton\.icon')],rem=[(P,r'TextButton\.icon')],after=['R03'])
t('R05','Play and speed above the kit view','F-011',[P],
 "In `_DrumPracticePanelState.build` move the block `if (pattern != null) ...[ Play FilledButton, 'Speed' label, speed Wrap ]` so that it comes BEFORE the `if (pattern != null) DrumKitView(...)` entry (right after the SwitchListTile and the preview Text). Do not change anything inside the blocks.",
 PT,cont=[(P,r"'Speed'[\s\S]*DrumKitView\(")],after=['R03'])
t('R06','Selected pattern row neutral with radio icon','F-012',[P],
 "In the `ListTile` built for each midi entry: add `selectedColor: Theme.of(context).colorScheme.onSurface,`, add `leading: Icon(_selectedId == entry.id ? Icons.radio_button_checked : Icons.radio_button_unchecked),` and give the trailing edit `IconButton` `constraints: const BoxConstraints(minWidth: 48, minHeight: 48),`.",
 PT,add=[(P,'radio_button_checked'),(P,'minWidth: 48')])
t('R07','Editor: remove duplicate heading','F-006',[E],
 "In `_DrumGridEditorState.build` delete the `Text('Drum pattern', style: ...titleLarge)` heading and put a `const SizedBox(height: 12)` above the Name TextField instead. Update only test assertions that look for that heading text.",
 ET,rem=[(E,"Drum pattern")],add=[(E,r'SizedBox\(height: 12\)')])
t('R08','Editor: bar chips on one row','F-006',[E],
 "Replace the Wrap/Row holding the four bar-count ChoiceChips (labels '1 bar' .. '4 bars') with a `Row(children: [for (final bars in [1, 2, 3, 4]) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: <the existing ChoiceChip for that bar count>))])` so all four fit on one line. Keep labels and selection logic.",
 ET,add=[(E,'Expanded')],after=['R07'])
t('R09','Editor: beat tint instead of orange outline','F-007',[E],
 "In the grid cell builder (`_cell`): the border color is `colors.primary` when `step % 4 == 0` and `colors.outlineVariant` otherwise. Change it so the border is always `colors.outline`, and for beat columns (`step % 4 == 0`) an EMPTY cell gets background fill `colors.surfaceContainerHigh`. Filled cells keep the current primary fill.",
 ET,add=[(E,'surfaceContainerHigh'),(E,r'colors\.outline\b')],after=['R08'])
t('R10','Editor: visible horizontal scrollbar','F-001',[E],
 "Find the horizontally scrolling grid (a `SingleChildScrollView` with `scrollDirection: Axis.horizontal`). Add `final ScrollController _gridScroll = ScrollController();` to the State, call `_gridScroll.dispose();` in dispose(), pass `controller: _gridScroll` to that SingleChildScrollView and wrap it in `Scrollbar(controller: _gridScroll, thumbVisibility: true, child: ...)`.",
 ET,add=[(E,'Scrollbar'),(E,r'_gridScroll\.dispose')],after=['R09'])
t('R11','Editor: legend above the grid','F-001',[E],
 "Move the legend `Text('Tap: Off → Normal (90) → Accent (120) → Ghost (40) → Off')` (and its style) so it is built directly ABOVE the grid (before the step-number header row / horizontal scroll view) instead of below it. Text unchanged.",
 ET,add=[(E,'Tap: Off')],rem=[(E,'Tap: Off')],after=['R10'])
t('R12','Editor: Play and Save pinned at the bottom','F-005',[E],
 "Restructure `_DrumGridEditorState.build`: the root becomes `Column(children: [Expanded(child: SingleChildScrollView(child: <everything currently above the Play/Save buttons>)), SafeArea(minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Row(children: [Expanded(child: <Play FilledButton.icon unchanged>), const SizedBox(width: 12), Expanded(child: <Save FilledButton unchanged>)]))])`. Keep button labels, onPressed and enabled logic exactly. If the content was already inside a scroll view, reuse it as the Expanded child instead of nesting another one.",
 ET+PT,add=[(E,'Expanded'),(E,'SafeArea')],after=['R11'])
t('R13','Editor: dirty notifier','F-005',[E],
 "Add an optional constructor parameter `this.dirty` to `DrumGridEditor` with field `final ValueNotifier<bool>? dirty;`. In the State set `widget.dirty?.value = true;` inside every handler that changes the pattern: toggling/cycling a cell, changing the bar count, and editing the name TextField (`onChanged`). Do not change layout.",
 ET,add=[(E,r'ValueNotifier<bool>\?'),(E,r'dirty\?\.value = true')],after=['R12'])
t('R14','Panel: discard-changes prompt on closing the editor','F-005',[P],
 "In `_openEditor`: create `final dirty = ValueNotifier<bool>(false);` pass `dirty: dirty` to `DrumGridEditor`, and wrap the route's `Scaffold` in `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) async { if (didPop) return; if (!dirty.value) { Navigator.of(ctx).pop(); return; } final discard = await showDialog<bool>(context: ctx, builder: (dc) => AlertDialog(title: const Text('Discard changes?'), actions: [TextButton(onPressed: () => Navigator.of(dc).pop(false), child: const Text('Keep editing')), FilledButton(onPressed: () => Navigator.of(dc).pop(true), child: const Text('Discard'))])); if (discard == true && ctx.mounted) Navigator.of(ctx).pop(); }, child: Scaffold(...))` where `ctx` is the route builder's BuildContext. Dispose `dirty` in the existing finally block.",
 PT,add=[(P,'PopScope'),(P,'Discard changes\\?')],after=['R13'])
t('R15','Shared lane labels in drum_map','F-009',[DM,'test/midi/drum_map_test.dart'],
 "In lib/services/audio/midi/drum_map.dart add two top-level functions using `switch` expressions over DrumLane: `String laneLabel(DrumLane lane)` returning 'Kick','Snare','Closed hat','Open hat','High tom','Mid tom','Floor tom','Crash','Ride', and `String lanePadLabel(DrumLane lane)` returning 'Kick','Snare','C-hat','O-hat','Hi','Mid','Floor','Crash','Ride'. In test/midi/drum_map_test.dart add one test asserting laneLabel(DrumLane.hatClosed) == 'Closed hat' and lanePadLabel(DrumLane.tomHigh) == 'Hi'.",
 ['test/midi/drum_map_test.dart'],add=[(DM,'String laneLabel'),(DM,'String lanePadLabel')])
t('R16','Kit view uses shared labels','F-009',[K],
 "In lib/widgets/midi/drum_kit_view.dart delete the private `_labels` and `_padLabels` maps. Use `laneLabel(lane)` wherever `_labels[...]` was used (lane rows, Semantics labels, chip tooltips) and `lanePadLabel(entry.key)` for the pad face text in `DrumKitPainter.paint`. `drum_map.dart` is already imported.",
 KT,add=[(K,r'lanePadLabel\('),(K,r'laneLabel\(')],rem=[(K,'_padLabels')],after=['R15'])
t('R17','Editor uses shared labels','F-009',[E],
 "In the grid editor replace its own lane label strings/map (Kick, Snare, Closed hat, ...) with `laneLabel(lane)` from drum_map.dart (add the import if missing).",
 ET,add=[(E,r'laneLabel\(')],after=['R15','R13'])
t('R18','Kit pads: contrast, stroke, 12sp labels','F-009',[K],
 "In `DrumKitPainter.paint`: the pad base color lerp starts from `colors.surfaceContainerHigh` (instead of surfaceContainerHighest); the outline Paint uses `..strokeWidth = 1.5` with `colors.outline`; the label TextStyle `fontSize` becomes 12.",
 KT,add=[(K,'strokeWidth'),(K,r'fontSize: 12')],after=['R16'])
t('R19','Lane dots bigger with visible ring','F-010',[K],
 "In the lane rows the step dot `Container` is 8x8: make it 10x10, and use `colors.outline` for the unlit (not offset == 0) border color instead of `colors.outlineVariant`.",
 KT,add=[(K,r'width: 10'),(K,r'colors\.outline\b')],after=['R18'])
t('R20','M/S chips less cramped','F-008',[K],
 "In `_chip(...)` keep the 48x48 SizedBox but give the FilterChip `labelPadding: const EdgeInsets.symmetric(horizontal: 14)` instead of zero padding.",
 KT,add=[(K,r'horizontal: 14')],after=['R19'])
t('R21','Drums button always visible','F-002',[M],
 "In `_MetronomeSongLibrary.build` the Drums `OutlinedButton.icon` is built only when `state.activeSong != null`. Build it always; when there is no active song `onPressed` is null and a `Text('Pick a song first', style: Theme.of(context).textTheme.bodySmall)` is shown directly under it. Update test/midi/drums_button_test.dart: the test that expects the button to be hidden without a song must now expect it present and disabled with the caption.",
 ['test/midi/drums_button_test.dart','test/screens/metronome_screen_test.dart'],add=[(M,'Pick a song first')])
t('R22','Drum practice notifier mirrors playing state','F-013',[PR],
 "Import `drum_active_provider.dart` (same folder). In `DrumPracticeNotifier`: in `start()` right after `playing: true` is set call `ref.read(drumActiveProvider.notifier).set(state.pattern?.name ?? 'Drums');` and in `stop()` after `playing: false` and in `clearPattern()` call `ref.read(drumActiveProvider.notifier).set(null);`. Do NOT touch it in onDispose.",
 ['test/midi/drum_practice_provider_test.dart'],add=[(PR,'drumActiveProvider')])
t('R23','Drums button shows active state','F-013',[M],
 "Import `../providers/data/drum_active_provider.dart`. In the widget that builds the Drums button use `final active = ref.watch(drumActiveProvider);` (make the widget a ConsumerWidget if it is not). When `active != null` render `FilledButton.icon` with the same icon/onPressed and label `Drums · $active`; otherwise keep the OutlinedButton.icon. Do NOT import or watch drum_practice_provider.dart in this file.",
 ['test/midi/drums_button_test.dart','test/screens/metronome_screen_test.dart'],add=[(M,'drumActiveProvider')],after=['R21','R22'])
t('R24','BPM number stays white while playing','F-014',['lib/widgets/metronome/central_tempo_circle.dart'],
 "In central_tempo_circle.dart the BPM number color is `MonoPulseColors.accentOrange` when `state.isPlaying` else `context.mp.textPrimary`. Make it always `context.mp.textPrimary`. Update only test assertions that check the orange color while playing.",
 ['test/widgets/metronome/central_tempo_circle_test.dart'],rem=[('lib/widgets/metronome/central_tempo_circle.dart','accentOrange')])
t('R25','Fast tempo hint','F-015',['lib/widgets/metronome/central_tempo_circle.dart'],
 "The 'BPM' sub-label under the number: show `'BPM · double-time?'` instead when the current bpm is >= 240, otherwise 'BPM' unchanged.",
 ['test/widgets/metronome/central_tempo_circle_test.dart'],add=[('lib/widgets/metronome/central_tempo_circle.dart','double-time')],after=['R24'])
t('R26','Steppers 48dp on small screens','F-018',['lib/widgets/metronome/time_signature_block.dart'],
 "In time_signature_block.dart the stepper buttons use 40 on small screens and 48 otherwise (conditionals around lines 286, 401, 677 like `isSmall ? 40 : 48`). Make the size 48 in all cases at those places. Update only test assertions that expect 40.",
 ['test/widgets/metronome/time_signature_block_test.dart','test/widgets/metronome/time_signature_grid_test.dart'],rem=[('lib/widgets/metronome/time_signature_block.dart',r'\b40\b')])
t('R27','Practice card: Tap to start readable','F-021',['lib/widgets/practice_dashboard_card.dart'],
 "Make the 'Tap to start' text use `context.mp.textPrimary` (alpha 0.85) instead of textSecondary and add a trailing `Icon(Icons.chevron_right, size: 16)` next to it in a Row (mainAxisSize: min). Keep the text string.",
 ['test/widgets/practice_dashboard_card_test.dart'],add=[('lib/widgets/practice_dashboard_card.dart','chevron_right')])
t('R28','Quick action labels with verbs','F-021',['lib/screens/home_screen.dart'],
 "In the Quick Actions the `QuickActionButton` labels 'Song', 'Band', 'Setlist' become 'Add song', 'Add band', 'Add setlist' ('Audio note' stays). Update test/screens/home_quick_actions_test.dart and test/screens/home_screen_test.dart only where they look for the old labels.",
 ['test/screens/home_quick_actions_test.dart','test/screens/home_screen_test.dart'],add=[('lib/screens/home_screen.dart',"Add song")])
t('R29','Rehearsals sheet: demo users sign up','F-017',['lib/screens/home_screen.dart','lib/screens/bands/create_band_screen.dart'],
 "In `_showRehearsalsEmptyState` (lib/screens/home_screen.dart) the CTA is 'Create a band'. For a demo user (use the same demo check create_band_screen.dart uses for its read-only message) show 'Sign up to create a band' and make onPressed do what the 'Sign Up' button in create_band_screen.dart does (sign out then go to the login route). Non-demo users unchanged. Edit only home_screen.dart; create_band_screen.dart is context.",
 ['test/screens/home_screen_test.dart'],add=[('lib/screens/home_screen.dart','Sign up to create a band')],after=['R28'])
t('R30','Create band demo: Sign Up as filled button','F-017',['lib/screens/bands/create_band_screen.dart'],
 "In the demo read-only card replace the `TextButton` 'Sign Up' with a `FilledButton` with the same onPressed and label. Update test/screens/bands/create_band_demo_test.dart where it finds `TextButton`.",
 ['test/screens/bands/create_band_demo_test.dart'],add=[('lib/screens/bands/create_band_screen.dart','FilledButton')])
t('R31','Song card: muted -- BPM placeholder','F-019',['lib/widgets/unified_item/unified_item_card.dart'],
 "In the meta rail, BPM is shown (Icons.speed + number) only when `displayBPM != null`. For SONG items only (the ones that show the key chip) when the BPM is null render a muted `Text('-- BPM')` with the same text size and `textSecondary` color so rows stay aligned. Other item types unchanged.",
 ['test/screens/songs/songs_list_screen_test.dart'],add=[('lib/widgets/unified_item/unified_item_card.dart','-- BPM')])
t('R32','Filter sheet: chips aligned to the gutter','F-022',['lib/screens/songs/songs_list_screen.dart'],
 "In the 'Filter Options' bottom sheet find the Key section row with the Major/Minor chips and make them left-aligned (`MainAxisAlignment.start` or `WrapAlignment.start`, spacing 8) instead of spread out/centered.",
 ['test/screens/songs/songs_list_screen_test.dart'],add=[('lib/screens/songs/songs_list_screen.dart',r'(MainAxisAlignment|WrapAlignment)\.start')])
t('R33','Audio note: microphone caption','F-016',['lib/screens/audio_note_screen.dart'],
 "Under the primary Record button add `Text('Microphone access is requested the first time you record.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center)` with 8dp spacing above it.",
 ['test/screens/audio_note_screen_test.dart'],add=[('lib/screens/audio_note_screen.dart','Microphone access is requested')])
t('R34','Analytics: drum event names','F-023',['lib/services/analytics_events.dart'],
 "In `AnalyticsEvents` add `static const String drumPatternImported = 'drum_pattern_imported'; drumPatternSaved = 'drum_pattern_saved'; drumPlayStarted = 'drum_play_started'; drumSyncToggled = 'drum_sync_toggled';` and in `AnalyticsParams` add `static const String syncWithClick = 'sync_with_click'; hitCount = 'hit_count';` (skip a param if the name exists). Register the new events everywhere `metronomeStarted` is registered in this file (look near line 366), following that exact pattern.",
 ['test/services/analytics_service_test.dart'],add=[('lib/services/analytics_events.dart','drum_pattern_imported')])
t('R35','Analytics: drum log methods','F-023',['lib/services/analytics_service.dart'],
 "Add four static methods modeled exactly on `logMetronomeStarted`: `logDrumPatternImported({required int hitCount})`, `logDrumPatternSaved({required int hitCount})`, `logDrumPlayStarted({required bool syncWithClick})`, `logDrumSyncToggled({required bool enabled})`, using the AnalyticsEvents/AnalyticsParams names added in analytics_events.dart (for `enabled` reuse AnalyticsParams.syncWithClick).",
 ['test/services/analytics_service_test.dart'],add=[('lib/services/analytics_service.dart','logDrumPlayStarted')],after=['R34'])
t('R36','Panel logs drum analytics','F-023',[P],
 "Import analytics_service.dart (relative path from this file). Call `AnalyticsService.logDrumPatternImported(hitCount: pattern.hits.length)` after a successful import preview, `AnalyticsService.logDrumPatternSaved(hitCount: ...)` after a successful save of the preview, `AnalyticsService.logDrumPlayStarted(syncWithClick: state.syncWithClick)` in the Play button handler when starting, and `AnalyticsService.logDrumSyncToggled(enabled: enabled)` in the Sync switch onChanged. Use `unawaited(...)`.",
 PT,add=[(P,r'AnalyticsService\.logDrumPlayStarted')],after=['R35','R14'])
t('R37','Editor logs pattern saved','F-023',[E],
 "After a successful save in the editor call `unawaited(AnalyticsService.logDrumPatternSaved(hitCount: <number of hits of the saved pattern>))` (import analytics_service.dart relative; import dart:async if needed).",
 ET,add=[(E,r'logDrumPatternSaved')],after=['R35','R13'])
json.dump(dict(branch='fix/audit-r3',tasks=T),open('docs/plans/audit-r3/tasks.json','w'),indent=1)
print(len(T),'tasks')
