import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/midi_pattern.dart';
import '../../models/song_lab.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/drum_practice_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../repositories/firestore_lab_repository.dart';
import '../../screens/songs/components/drum_grid_editor.dart';
import '../../services/analytics_service.dart';
import '../../services/audio/midi/smf_parser.dart';
import '../../utils/picked_file.dart';
import '../../utils/snackbar.dart' show showGlobalSnackBar;
import '../midi/drum_kit_view.dart';

class DrumPracticePanel extends ConsumerStatefulWidget {
  const DrumPracticePanel({required this.songId, this.bandId, super.key});

  final String songId;
  final String? bandId;

  @override
  ConsumerState<DrumPracticePanel> createState() => _DrumPracticePanelState();
}

class _DrumPracticePanelState extends ConsumerState<DrumPracticePanel> {
  late final DrumPracticeNotifier _practice;

  @override
  void initState() {
    super.initState();
    _practice = ref.read(drumPracticeProvider.notifier);
    // Reopening the sheet keeps the loaded pattern; otherwise load the first
    // saved one so Sync with click works without an extra tap.
    _selectedId = ref.read(drumPracticeProvider).entryId;
    ref.listenManual(
      labEntriesProvider((widget.songId, widget.bandId)),
      (_, next) => next.whenData(_autoSelect),
      fireImmediately: true,
    );
  }

  void _autoSelect(List<SongLabEntry> entries) {
    if (_selectedId != null || ref.read(drumPracticeProvider).pattern != null) {
      return;
    }
    final first = entries.where(
      (e) => e.type == LabEntryType.midi && e.pattern != null,
    );
    if (first.isEmpty) return;
    final entry = first.first;
    scheduleMicrotask(() {
      if (!mounted || _selectedId != null) return;
      setState(() => _selectedId = entry.id);
      unawaited(
        _practice.loadPattern(
          entry.id,
          entry.pattern!.withName(entry.title ?? 'Drum pattern'),
        ),
      );
    });
  }

  @override
  void didUpdateWidget(covariant DrumPracticePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId ||
        oldWidget.bandId != widget.bandId) {
      _preview = null;
      _selectedId = null;
      scheduleMicrotask(() {
        if (mounted) unawaited(_practice.clearPattern());
      });
    }
  }

  SongLabEntry? _preview;
  String? _selectedId;
  bool _busy = false;

  bool get _canImport =>
      widget.bandId == null || ref.read(canEditBandProvider(widget.bandId!));

  @override
  void dispose() {
    // Saved patterns stay loaded so the metronome can drive them with the
    // sheet closed; only an unsaved import preview is discarded.
    if (_preview != null) unawaited(_practice.clearPattern());
    _practice.releaseUnlessSynced();
    super.dispose();
  }

  void _showError(Object error) {
    // Root messenger: the panel sits in a modal sheet that covers the local one.
    showGlobalSnackBar('$error', error: true);
  }

  Future<void> _openEditor([SongLabEntry? entry]) async {
    final dirty = ValueNotifier<bool>(false);
    final parent = ProviderScope.containerOf(context, listen: false);
    final editorScope = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(
          parent.read(firebaseAuthProvider),
        ),
        drumPracticeProvider.overrideWith(() => _EditorPractice(parent)),
        // Draft editing and preview are available even without save access.
        canEditBandProvider.overrideWith((ref, bandId) => true),
        labRepositoryProvider.overrideWith(
          (ref) => _EditorRepository(
            firestore: parent.read(firebaseFirestoreProvider),
            auth: parent.read(firebaseAuthProvider),
            save: (entry, bandId) {
              if (!parent.read(canEditProvider)) {
                throw StateError(
                  'Cannot save: demo or read-only accounts cannot save patterns.',
                );
              }
              if (bandId != null && !parent.read(canEditBandProvider(bandId))) {
                throw StateError(
                  'Cannot save: you do not have permission to edit this band.',
                );
              }
              return parent
                  .read(labRepositoryProvider)
                  .saveEntry(entry, bandId: bandId);
            },
          ),
        ),
      ],
    );
    final route = MaterialPageRoute<SongLabEntry>(
      fullscreenDialog: true,
      builder: (ctx) => UncontrolledProviderScope(
        container: editorScope,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (!dirty.value) {
              Navigator.of(ctx).pop();
              return;
            }
            final discard = await showDialog<bool>(
              context: ctx,
              builder: (dc) => AlertDialog(
                title: const Text('Discard changes?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dc).pop(false),
                    child: const Text('Keep editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dc).pop(true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            );
            if (discard == true && ctx.mounted) Navigator.of(ctx).pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(entry == null ? 'New pattern' : 'Edit pattern'),
            ),
            body: DrumGridEditor(
              songId: widget.songId,
              bandId: widget.bandId,
              entry: entry,
            ),
          ),
        ),
      ),
    );
    try {
      await Navigator.of(context, rootNavigator: true).push(route);
      await route.completed;
    } finally {
      editorScope.dispose();
      dirty.dispose();
    }
  }

  Future<void> _import() async {
    if (!_canImport) return;
    setState(() => _busy = true);
    try {
      // Any file keeps native pickers compatible; the SMF parser validates it.
      // ignore: avoid_redundant_argument_values
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      final bytes = await readPickedBytes(file);
      final pattern = parseDrumSmf(bytes);
      if (!mounted) return;
      final now = DateTime.now();
      final entry = SongLabEntry(
        id: const Uuid().v4(),
        songId: widget.songId,
        bandId: widget.bandId,
        type: LabEntryType.midi,
        title: file.name,
        authorId: ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
        createdAt: now,
        updatedAt: now,
        midi: pattern.toJson(),
      );
      setState(() {
        _preview = entry;
        _selectedId = entry.id;
      });
      await _practice.loadPattern(
        entry.id,
        pattern.withName(file.name.split('.').first),
      );
      unawaited(
        AnalyticsService.logDrumPatternImported(hitCount: pattern.hits.length),
      );
    } on FormatException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final entry = _preview;
    if (entry == null || !_canImport) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(labRepositoryProvider)
          .saveEntry(entry, bandId: widget.bandId);
      unawaited(
        AnalyticsService.logDrumPatternSaved(
          hitCount: entry.pattern?.hits.length ?? 0,
        ),
      );
      if (mounted) setState(() => _preview = null);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(
      labEntriesProvider((widget.songId, widget.bandId)),
    );
    final state = ref.watch(drumPracticeProvider);
    final canImport =
        widget.bandId == null || ref.watch(canEditBandProvider(widget.bandId!));
    final pattern = state.entryId == _selectedId ? state.pattern : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => SafeArea(
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Drums', style: Theme.of(context).textTheme.titleLarge),
            entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Failed to load drums: $error'),
              data: (entries) {
                final midi = entries.where((e) => e.type == LabEntryType.midi);
                return Column(
                  children: [
                    if (midi.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.queue_music,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No MIDI patterns yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Import a MIDI drum file or build a pattern step by step to play along with the click.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    for (final entry in midi)
                      ListTile(
                        title: Text(entry.title ?? 'MIDI pattern'),
                        selectedColor: Theme.of(context).colorScheme.onSurface,
                        leading: Icon(
                          _selectedId == entry.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        trailing: IconButton(
                          tooltip: 'Edit pattern',
                          icon: const Icon(Icons.edit_outlined),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: !_busy && entry.midi != null
                              ? () => _openEditor(entry)
                              : null,
                        ),
                        selected: _selectedId == entry.id,
                        enabled: !_busy && entry.midi != null,
                        onTap: () {
                          setState(() {
                            _preview = null;
                            _selectedId = entry.id;
                          });
                          unawaited(
                            _practice.loadPattern(
                              entry.id,
                              entry.pattern!.withName(
                                entry.title ?? 'Drum pattern',
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
            SwitchListTile(
              title: const Text('Sync with click'),
              value: state.syncWithClick,
              onChanged: (enabled) {
                _practice.setSyncWithClick(enabled: enabled);
                unawaited(
                  AnalyticsService.logDrumSyncToggled(enabled: enabled),
                );
              },
            ),
            if (_preview != null) Text('Preview: ${_preview!.title}'),
            if (pattern != null) ...[
              FilledButton.icon(
                onPressed: () {
                  if (state.playing) {
                    _practice.stop();
                    return;
                  }
                  unawaited(_practice.start());
                  unawaited(
                    AnalyticsService.logDrumPlayStarted(
                      syncWithClick: state.syncWithClick,
                    ),
                  );
                },
                icon: Icon(state.playing ? Icons.stop : Icons.play_arrow),
                label: Text(state.playing ? 'Stop' : 'Play'),
              ),
              Text('Speed', style: Theme.of(context).textTheme.labelMedium),
              Wrap(
                spacing: 8,
                children: [
                  for (final speed in [0.5, 0.75, 1.0])
                    ChoiceChip(
                      label: Text('${(speed * 100).round()}%'),
                      selected: state.speed == speed,
                      onSelected: (_) => _practice.setSpeed(speed),
                    ),
                ],
              ),
            ],
            if (pattern != null)
              DrumKitView(
                currentStep: state.currentStep,
                pattern: pattern,
                muted: state.muted,
                solo: state.solo,
                onToggleMute: _practice.toggleMute,
                onToggleSolo: _practice.toggleSolo,
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canImport && !_busy ? _import : null,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import .mid'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _openEditor,
                    icon: const Icon(Icons.add),
                    label: const Text('New pattern'),
                  ),
                ),
              ],
            ),
            if (_preview != null)
              FilledButton(
                onPressed: canImport && !_busy ? _save : null,
                child: const Text('Save to Song Lab'),
              ),
          ],
        ),
      ),
    );
  }
}

// Keep the editor's persistence guard separate from its local draft permissions.
class _EditorRepository extends FirestoreLabRepository {
  _EditorRepository({
    required super.firestore,
    required super.auth,
    required this.save,
  });

  final Future<void> Function(SongLabEntry entry, String? bandId) save;

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) =>
      save(entry, bandId);
}

// Share playback while isolating draft permissions from the app's provider scope.
class _EditorPractice extends DrumPracticeNotifier {
  _EditorPractice(this.parent);

  final ProviderContainer parent;
  DrumPracticeNotifier get _practice =>
      parent.read(drumPracticeProvider.notifier);

  @override
  DrumPracticeState build() {
    final subscription = parent.listen(drumPracticeProvider, (_, next) {
      state = next;
    });
    ref.onDispose(subscription.close);
    return parent.read(drumPracticeProvider);
  }

  @override
  Future<void> loadPattern(String entryId, MidiPattern pattern) =>
      _practice.loadPattern(entryId, pattern);

  @override
  Future<void> start() => _practice.start();

  @override
  Future<void> stop() => _practice.stop();
}
