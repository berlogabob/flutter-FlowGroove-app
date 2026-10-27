import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/audio_region.dart';
import '../../models/band.dart';
import '../../models/song.dart';
import '../../models/song_lab.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../router/app_router.dart';
import '../../services/analytics_service.dart';
import '../../services/export/lab_markdown.dart';
import '../../services/idea_recorder.dart';
import '../../services/pending_storage_deletes.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/chordpro.dart';
import '../../utils/member_label.dart';
import '../../utils/snackbar.dart';
import '../../widgets/app_filter_chip.dart';
import '../../widgets/app_menu_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/midi/midi_import_flow.dart';
import '../../widgets/midi/midi_song_panel.dart';
import '../../widgets/standard_screen_scaffold.dart';
import 'components/lab_recording_sheet.dart';

/// Song Lab timeline (#67): a reverse-chronological journal of typed entries
/// for one song — the history of "our version" (notes, decisions,
/// experiments, problems). Quick-add covers 4 types; the model carries more.
class SongLabScreen extends ConsumerStatefulWidget {
  const SongLabScreen({
    required this.song,
    this.bandId,
    this.embedded = false,
    super.key,
  });

  final Song song;
  final String? bandId;

  /// True when hosted inside the Song Page's Lab tab: no own scaffold or
  /// shell-menu publication (the page owns those); Save version / Export
  /// surface as inline icons next to the Entries/Tasks toggle instead.
  final bool embedded;

  @override
  ConsumerState<SongLabScreen> createState() => _SongLabScreenState();
}

class _SongLabScreenState extends ConsumerState<SongLabScreen> {
  static const _uuid = Uuid();

  /// null = all types.
  LabEntryType? _typeFilter;
  bool _showTasks = false;
  bool _migrated = false;
  bool _importingMidi = false;
  (String, String?) get _key => (widget.song.id, widget.bandId);

  bool get _canEdit => widget.bandId == null
      ? ref.watch(canEditProvider)
      : ref.watch(canEditBandProvider(widget.bandId!));

  bool _canEditNow() =>
      mounted &&
      (widget.bandId == null
          ? ref.read(canEditProvider)
          : ref.read(canEditBandProvider(widget.bandId!)));

  bool _canDeleteEntry(SongLabEntry entry) {
    if (!mounted) return false;
    final user = ref.read(appUserProvider);
    return _canEditNow() ||
        (widget.bandId != null &&
            !user.isLoading &&
            !user.hasError &&
            user.value != null &&
            user.value!.accessRole != 'demo' &&
            user.value!.uid == entry.authorId);
  }

  static const _quickTypes = [
    LabEntryType.note,
    LabEntryType.decision,
    LabEntryType.experiment,
    LabEntryType.problem,
  ];

  static const _typeIcons = <LabEntryType, IconData>{
    LabEntryType.note: Icons.sticky_note_2_outlined,
    LabEntryType.idea: Icons.lightbulb_outline,
    LabEntryType.decision: Icons.gavel_outlined,
    LabEntryType.experiment: Icons.science_outlined,
    LabEntryType.problem: Icons.report_problem_outlined,
    LabEntryType.task: Icons.check_circle_outline,
    LabEntryType.rehearsalNote: Icons.event_note_outlined,
    LabEntryType.recording: Icons.mic_outlined,
    LabEntryType.versionChange: Icons.history,
    LabEntryType.reference: Icons.link,
  };

  static String _typeLabel(LabEntryType t) => switch (t) {
    LabEntryType.rehearsalNote => 'Rehearsal note',
    LabEntryType.versionChange => 'Version',
    _ => t.name[0].toUpperCase() + t.name.substring(1),
  };

  /// One-time lazy migration (#66): the song's free-text notes become the
  /// first timeline entry, so the Lab never opens empty on an annotated song.
  Future<void> _migrateNotesIfNeeded(List<SongLabEntry> entries) async {
    if (_migrated || entries.isNotEmpty || !_canEditNow()) return;
    final notes = widget.song.notes;
    if (notes == null || notes.trim().isEmpty) return;
    _migrated = true;
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    final now = DateTime.now();
    await ref
        .read(labRepositoryProvider)
        .saveEntry(
          SongLabEntry(
            id: _uuid.v4(),
            songId: widget.song.id,
            bandId: widget.bandId,
            type: LabEntryType.note,
            title: 'Imported notes',
            body: notes,
            authorId: uid,
            createdAt: now,
            updatedAt: now,
          ),
          bandId: widget.bandId,
        );
  }

  Future<void> _compose(LabEntryType type, {SongLabEntry? existing}) async {
    if (!_canEditNow()) return;
    final result = await showModalBottomSheet<_ComposeResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComposeEntrySheet(
        type: existing?.type ?? type,
        song: widget.song,
        existing: existing,
      ),
    );
    if (result == null || !mounted || !_canEditNow()) return;

    final repo = ref.read(labRepositoryProvider);
    if (existing != null) {
      await repo.saveEntry(
        existing.copyWith(title: result.title, body: result.body),
        bandId: widget.bandId,
      );
      return;
    }
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    final now = DateTime.now();
    await repo.saveEntry(
      SongLabEntry(
        id: _uuid.v4(),
        songId: widget.song.id,
        bandId: widget.bandId,
        type: type,
        title: result.title,
        body: result.body,
        sectionId: result.sectionId,
        status: switch (type) {
          LabEntryType.decision => 'active',
          LabEntryType.experiment => 'planned',
          _ => null,
        },
        authorId: uid,
        createdAt: now,
        updatedAt: now,
      ),
      bandId: widget.bandId,
    );
    unawaited(AnalyticsService.logLabEntryAdded(type: type.name));
  }

  bool get _canImportMidi => canImportMidi(ref, widget.bandId);

  Future<void> _importMidi() async {
    if (_importingMidi || !_canImportMidi) return;
    setState(() => _importingMidi = true);
    try {
      await pickAndImportMidi(
        context,
        ref,
        songId: widget.song.id,
        bandId: widget.bandId,
      );
    } finally {
      if (mounted) setState(() => _importingMidi = false);
    }
  }

  /// Links the take's named regions to the song's structure (building one
  /// when the song has none), so the drums and launchpad can share the map.
  Future<void> _useAsSongMap(SongLabEntry entry) async {
    if (!_canEditNow()) return;
    final song = widget.song;
    final result = linkToSongMap(entry.regions, song.sections, newId: _uuid.v4);
    try {
      if (result.created case final sections?) {
        final updated = song.copyWith(sections: sections);
        final repo = ref.read(songRepositoryProvider);
        if (widget.bandId case final b?) {
          await repo.updateBandSong(updated, b);
        } else {
          await repo.updateSong(
            updated,
            uid: ref.read(currentUserProvider).value?.uid,
          );
        }
      }
      await ref
          .read(labRepositoryProvider)
          .saveEntry(
            entry.copyWith(regions: result.regions),
            bandId: widget.bandId,
          );
      if (!mounted) return;
      showAppSnackBar(
        context,
        result.created != null
            ? 'Song map built from ${result.created!.length} regions'
            : result.unmatched == 0
            ? 'Regions linked to the song map'
            : result.unmatched == 1
            ? 'Linked; 1 region has no matching section'
            : 'Linked; ${result.unmatched} regions have no matching section',
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _delete(SongLabEntry entry) async {
    if (!_canDeleteEntry(entry)) return;
    final repo = ref.read(labRepositoryProvider);
    final pending = ref.read(pendingStorageDeletesProvider);
    final uid = ref.read(appUserProvider).value?.uid;
    final key = _key;
    bool canRestore() =>
        mounted &&
        _key == key &&
        _canEditNow() &&
        ref.read(appUserProvider).value?.uid == uid &&
        ref.read(firebaseAuthProvider).currentUser?.uid == uid;
    // A recording's audio has to outlive the snackbar for Undo's restored
    // entry to still play; delete it only once the undo window shuts.
    final url =
        entry.type == LabEntryType.recording && entry.attachmentIds.isNotEmpty
        ? entry.attachmentIds.first
        : null;
    if (url != null) await pending.enqueue(url);
    if (!_canDeleteEntry(entry)) {
      if (url != null) await pending.cancel(url);
      return;
    }
    try {
      await repo.deleteEntry(widget.song.id, entry.id, bandId: widget.bandId);
    } catch (_) {
      if (url != null) await pending.cancel(url);
      if (mounted)
        showAppSnackBar(context, 'Could not delete entry. Try again.');
      return;
    }
    if (url != null) unawaited(pending.flushAfter(url, undoGracePeriod));
    if (!mounted) return;
    Future<void> undo() async {
      if (!canRestore()) return;
      try {
        if (url != null) await pending.cancel(url);
        if (!canRestore()) return;
        await repo.saveEntry(entry, bandId: key.$2);
      } catch (_) {
        if (mounted) {
          showAppSnackBar(
            context,
            "Couldn't restore — try again",
            error: true,
            actionLabel: canRestore() ? 'Retry' : null,
            onAction: undo,
          );
        }
      }
    }

    showAppSnackBar(
      context,
      'Entry deleted',
      actionLabel: canRestore() ? 'Undo' : null,
      onAction: undo,
    );
  }

  Future<void> _setStatus(SongLabEntry entry, String status) async {
    if (!_canEditNow()) return;
    await ref
        .read(labRepositoryProvider)
        .saveEntry(entry.copyWith(status: status), bandId: widget.bandId);
  }

  // ---- Versions (#70) ----

  Future<void> _saveVersion() async {
    if (!_canEditNow()) return;
    final result = await showModalBottomSheet<(String, String?, bool)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SaveVersionSheet(),
    );
    if (result == null || !mounted || !_canEditNow()) return;
    final (name, notes, makeCurrent) = result;

    final repo = ref.read(labRepositoryProvider);
    final now = DateTime.now();
    final version = SongVersion(
      id: _uuid.v4(),
      songId: widget.song.id,
      bandId: widget.bandId,
      name: name,
      status: makeCurrent ? 'current' : 'archived',
      bpm: widget.song.ourBPM,
      key: widget.song.ourKey,
      structureSnapshot: songMapSummary(
        widget.song.sections.map((s) => s.name).toList(),
      ),
      lyricsSnapshot: songToChordPro(widget.song),
      notes: notes,
      createdAt: now,
    );
    await repo.saveVersion(version, bandId: widget.bandId);
    if (!_canEditNow()) return;
    if (makeCurrent) {
      await repo.setCurrentVersion(
        widget.song.id,
        version.id,
        bandId: widget.bandId,
      );
    }
    // The changelog lives in the timeline (never silently overwritten).
    if (!_canEditNow()) return;
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    await repo.saveEntry(
      SongLabEntry(
        id: _uuid.v4(),
        songId: widget.song.id,
        bandId: widget.bandId,
        type: LabEntryType.versionChange,
        title: 'Version: $name',
        body: notes,
        versionId: version.id,
        authorId: uid,
        createdAt: now,
        updatedAt: now,
      ),
      bandId: widget.bandId,
    );
    if (!mounted) return;
    showAppSnackBar(context, 'Version "$name" saved');
  }

  Future<void> _exportMarkdown() async {
    final entries = await ref.read(labEntriesProvider(_key).future);
    final tasks = await ref.read(labTasksProvider(_key).future);
    final versions = await ref.read(labVersionsProvider(_key).future);
    final md = buildLabMarkdown(
      song: widget.song,
      entries: entries,
      tasks: tasks,
      versions: versions,
    );
    final ok = await shareLabMarkdown(md, widget.song.title);
    if (!ok && mounted) showAppSnackBar(context, 'Export failed');
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _canEdit;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MonoPulseSpacing.lg,
            MonoPulseSpacing.md,
            MonoPulseSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Entries')),
                    ButtonSegment(value: true, label: Text('Tasks')),
                  ],
                  selected: {_showTasks},
                  onSelectionChanged: (s) =>
                      setState(() => _showTasks = s.first),
                ),
              ),
              // Embedded: the page's ⋮ is for song-wide tools, so the Lab's
              // own two actions live here instead of a menu sheet.
              if (widget.embedded) ...[
                IconButton(
                  onPressed: canEdit ? _saveVersion : null,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  tooltip: 'Save version',
                ),
                IconButton(
                  onPressed: _exportMarkdown,
                  icon: const Icon(Icons.description_outlined),
                  tooltip: 'Export history (Markdown)',
                ),
              ],
            ],
          ),
        ),
        Expanded(child: _showTasks ? _tasksTab() : _entriesTab()),
      ],
    );

    if (widget.embedded) return body;
    return StandardScreenScaffold(
      title: 'Lab — ${widget.song.title}',
      menuItems: [
        if (canEdit)
          AppMenuItem(
            icon: Icons.bookmark_add_outlined,
            label: 'Save version',
            onTap: _saveVersion,
          ),
        AppMenuItem(
          icon: Icons.description_outlined,
          label: 'Export history (Markdown)',
          onTap: _exportMarkdown,
        ),
      ],
      body: body,
    );
  }

  Widget _entriesTab() {
    final entriesAsync = ref.watch(labEntriesProvider(_key));
    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load Lab: $e')),
      data: (entries) {
        _migrateNotesIfNeeded(entries);
        final visible = _typeFilter == null
            ? entries
            : entries.where((e) => e.type == _typeFilter).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _quickAddRow(),
            if (entries.isNotEmpty) _filterRow(),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: EmptyState(
                            icon: Icons.science_outlined,
                            message: entries.isEmpty
                                ? 'The story of this song starts here'
                                : 'Nothing of this type yet',
                            hint: entries.isEmpty
                                ? 'Capture ideas, decisions ("why we play it '
                                      'this way"), experiments and problems — '
                                      'so the band never loses the context.'
                                : null,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: visible.length,
                      itemBuilder: (context, i) => _entryCard(visible[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  // ---- Tasks tab (#68) ----

  Widget _tasksTab() {
    final tasksAsync = ref.watch(labTasksProvider(_key));
    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load tasks: $e')),
      data: (tasks) {
        final open = tasks.where((t) => t.isOpen).toList();
        final closed = tasks.where((t) => !t.isOpen).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(MonoPulseSpacing.md),
              child: _canEdit
                  ? ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Add task'),
                      onPressed: _composeTask,
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? const EmptyState(
                      icon: Icons.check_circle_outline,
                      message: 'No homework yet',
                      hint:
                          'Tasks are song-scoped: "learn the solo", '
                          '"transcribe the bridge" — so everyone knows what '
                          'to prepare.',
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        for (final t in open) _taskCard(t),
                        if (closed.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(MonoPulseSpacing.md),
                            child: Text(
                              'Done',
                              style: MonoPulseTypography.bodySmall.copyWith(
                                color: context.mp.textSecondary,
                              ),
                            ),
                          ),
                        for (final t in closed) _taskCard(t),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  static const _statusOrder = [
    SongTaskStatus.todo,
    SongTaskStatus.doing,
    SongTaskStatus.done,
    SongTaskStatus.blocked,
    SongTaskStatus.skipped,
  ];

  Future<void> _cycleStatus(SongTask task) {
    if (!_canEditNow()) return Future.value();
    final next =
        _statusOrder[(_statusOrder.indexOf(task.status) + 1) %
            _statusOrder.length];
    return ref
        .read(labRepositoryProvider)
        .saveTask(task.copyWith(status: next), bandId: widget.bandId);
  }

  Widget _taskCard(SongTask t) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.lg,
        vertical: MonoPulseSpacing.xs,
      ),
      child: ListTile(
        dense: true,
        title: Text(
          t.title,
          style: t.isOpen
              ? null
              : TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: context.mp.textSecondary,
                ),
        ),
        subtitle: Text(
          [
            if (t.assignedToUserId != null) _memberName(t.assignedToUserId!),
            if (t.dueAt != null) 'due ${t.dueAt!.day}/${t.dueAt!.month}',
          ].join(' · '),
        ),
        // Tap the chip to cycle the status; long-press the row deletes.
        trailing: ActionChip(
          label: Text(t.status.name),
          onPressed: _canEdit ? () => _cycleStatus(t) : null,
        ),
        onLongPress: !_canEdit
            ? null
            : () async {
                if (!_canEditNow()) return;
                final repo = ref.read(labRepositoryProvider);
                await repo.deleteTask(
                  widget.song.id,
                  t.id,
                  bandId: widget.bandId,
                );
                if (!mounted) return;
                showAppSnackBar(
                  context,
                  'Task deleted',
                  actionLabel: 'Undo',
                  onAction: () {
                    if (!_canEditNow()) return;
                    repo.saveTask(t, bandId: widget.bandId);
                  },
                );
              },
      ),
    );
  }

  String _memberName(String uid) {
    final bands = ref.read(bandsProvider).value ?? [];
    for (final band in bands) {
      for (final m in band.members) {
        if (m.uid == uid) {
          return memberLabel(displayName: m.displayName, email: m.email);
        }
      }
    }
    return 'Member';
  }

  Future<void> _composeTask() async {
    if (!_canEditNow()) return;
    final band = widget.bandId == null
        ? null
        : (ref.read(bandsProvider).value ?? [])
              .where((b) => b.id == widget.bandId)
              .firstOrNull;
    final result = await showModalBottomSheet<SongTask>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComposeTaskSheet(
        songId: widget.song.id,
        bandId: widget.bandId,
        members: band?.members ?? const [],
      ),
    );
    if (result == null || !mounted || !_canEditNow()) return;
    await ref
        .read(labRepositoryProvider)
        .saveTask(result, bandId: widget.bandId);
  }

  Widget _quickAddRow() {
    final canEdit = _canEdit;
    if (!canEdit) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MonoPulseSpacing.lg,
        MonoPulseSpacing.md,
        MonoPulseSpacing.lg,
        0,
      ),
      child: Wrap(
        spacing: MonoPulseSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PopupMenuButton<LabEntryType>(
            tooltip: 'Add',
            onSelected: (t) =>
                t == LabEntryType.recording ? _composeRecording() : _compose(t),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: LabEntryType.recording,
                child: Text('Record'),
              ),
              for (final t in _quickTypes)
                PopupMenuItem(value: t, child: Text(_typeLabel(t))),
            ],
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.all(MonoPulseSpacing.sm),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: MonoPulseSpacing.sm),
                  Text('Add'),
                ],
              ),
            ),
          ),
          if (!kIsWeb && (widget.bandId != null || ref.watch(canEditProvider)))
            TextButton.icon(
              onPressed: _importingMidi ? null : _importMidi,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import MIDI'),
            ),
        ],
      ),
    );
  }

  /// Record/attach an audio idea (#69) — shared capture path (#145).
  Future<void> _composeRecording() async {
    if (!_canEditNow()) return;
    await captureIdea(
      context,
      ref,
      songId: widget.song.id,
      bandId: widget.bandId,
    );
  }

  Widget _filterRow() => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: MonoPulseSpacing.lg,
      vertical: MonoPulseSpacing.sm,
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          AppFilterChip(
            label: 'All',
            selected: _typeFilter == null,
            onSelected: (_) => setState(() => _typeFilter = null),
          ),
          const SizedBox(width: MonoPulseSpacing.sm),
          for (final t in _quickTypes) ...[
            AppFilterChip(
              label: _typeLabel(t),
              selected: _typeFilter == t,
              onSelected: (sel) => setState(() => _typeFilter = sel ? t : null),
            ),
            const SizedBox(width: MonoPulseSpacing.sm),
          ],
        ],
      ),
    ),
  );

  String _sectionName(String? sectionId) {
    if (sectionId == null) return '';
    final match = widget.song.sections.where((s) => s.id == sectionId);
    return match.isEmpty ? '' : match.first.name;
  }

  Widget _entryCard(SongLabEntry e) {
    final section = _sectionName(e.sectionId);
    final superseded = e.status == 'superseded';
    final canEdit = _canEdit;
    final user = ref.watch(appUserProvider);
    final canDelete =
        canEdit ||
        (widget.bandId != null &&
            !user.isLoading &&
            !user.hasError &&
            user.value != null &&
            user.value!.accessRole != 'demo' &&
            user.value!.uid == e.authorId);
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.lg,
        vertical: MonoPulseSpacing.xs,
      ),
      child: ListTile(
        onTap: !kIsWeb && e.type == LabEntryType.midi && e.midiSong != null
            ? () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => MidiSongPanel(entry: e, bandId: widget.bandId),
              )
            : e.type == LabEntryType.recording && e.attachmentIds.isNotEmpty
            ? () => context.goAudioNote(e, bandId: widget.bandId)
            : null,
        leading: Icon(
          _typeIcons[e.type],
          color: superseded
              ? context.mp.textSecondary
              : MonoPulseColors.accentOrange,
        ),
        title: Text(
          e.title?.isNotEmpty == true ? e.title! : _typeLabel(e.type),
          style: superseded
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: context.mp.textSecondary,
                )
              : null,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (e.body?.isNotEmpty == true)
              Text(e.body!, maxLines: 4, overflow: TextOverflow.ellipsis),
            if (e.type == LabEntryType.recording && e.attachmentIds.isNotEmpty)
              LabAudioPlayer(url: e.attachmentIds.first),
            Text(
              [
                _typeLabel(e.type),
                if (e.status != null) e.status!,
                if (section.isNotEmpty) section,
                if (e.regions.isNotEmpty)
                  '${e.regions.length} region${e.regions.length == 1 ? '' : 's'}',
                '${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}',
              ].join(' · '),
              style: MonoPulseTypography.bodySmall.copyWith(
                color: context.mp.textSecondary,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => switch (v) {
            'edit' => _compose(e.type, existing: e),
            'supersede' => _setStatus(e, 'superseded'),
            'accepted' || 'rejected' || 'tried' => _setStatus(e, v),
            'delete' => _delete(e),
            'practice' => context.goPracticeRegions(e, bandId: widget.bandId),
            'songmap' => _useAsSongMap(e),
            _ => null,
          },
          itemBuilder: (_) => [
            if (e.type == LabEntryType.recording && e.attachmentIds.isNotEmpty)
              const PopupMenuItem(
                value: 'practice',
                child: Text('Practice regions'),
              ),
            if (canEdit && e.regions.any((r) => r.name.trim().isNotEmpty))
              const PopupMenuItem(
                value: 'songmap',
                child: Text('Use as song map'),
              ),
            if (canEdit)
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (canEdit &&
                e.type == LabEntryType.decision &&
                e.status == 'active')
              const PopupMenuItem(
                value: 'supersede',
                child: Text('Mark superseded'),
              ),
            if (canEdit && e.type == LabEntryType.experiment) ...[
              const PopupMenuItem(value: 'tried', child: Text('Tried it')),
              const PopupMenuItem(value: 'accepted', child: Text('Accepted')),
              const PopupMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
            if (canDelete)
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _ComposeResult {
  _ComposeResult(this.title, this.body, this.sectionId);
  final String? title;
  final String? body;
  final String? sectionId;
}

class _ComposeEntrySheet extends StatefulWidget {
  const _ComposeEntrySheet({
    required this.type,
    required this.song,
    this.existing,
  });

  final LabEntryType type;
  final Song song;
  final SongLabEntry? existing;

  @override
  State<_ComposeEntrySheet> createState() => _ComposeEntrySheetState();
}

class _ComposeEntrySheetState extends State<_ComposeEntrySheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _body = TextEditingController(text: widget.existing?.body);
  String? _sectionId;

  @override
  void initState() {
    super.initState();
    _sectionId = widget.existing?.sectionId;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null
                  ? 'New ${widget.type.name}'
                  : 'Edit ${widget.type.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            TextField(
              controller: _body,
              maxLines: 5,
              minLines: 2,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.song.sections.isNotEmpty && widget.existing == null) ...[
              const SizedBox(height: MonoPulseSpacing.md),
              DropdownButtonFormField<String?>(
                initialValue: _sectionId,
                decoration: const InputDecoration(
                  labelText: 'Section (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(child: Text('—')),
                  for (final s in widget.song.sections)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _sectionId = v),
              ),
            ],
            const SizedBox(height: MonoPulseSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: MonoPulseSpacing.sm),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _ComposeResult(
                      _title.text.trim().isEmpty ? null : _title.text.trim(),
                      _body.text.trim().isEmpty ? null : _body.text.trim(),
                      _sectionId,
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add-task sheet (#68): title, optional due date, optional assignee (band
/// songs only — members come from the band).
class _ComposeTaskSheet extends StatefulWidget {
  const _ComposeTaskSheet({
    required this.songId,
    required this.bandId,
    required this.members,
  });

  final String songId;
  final String? bandId;
  final List<BandMember> members;

  @override
  State<_ComposeTaskSheet> createState() => _ComposeTaskSheetState();
}

class _ComposeTaskSheetState extends State<_ComposeTaskSheet> {
  static const _uuid = Uuid();
  final _title = TextEditingController();
  DateTime? _dueAt;
  String? _assignee;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New task', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: MonoPulseSpacing.md),
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'What needs to be prepared?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                      _dueAt == null
                          ? 'Due date (optional)'
                          : 'Due ${_dueAt!.day}/${_dueAt!.month}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _dueAt = picked);
                    },
                  ),
                ),
              ],
            ),
            if (widget.members.isNotEmpty) ...[
              const SizedBox(height: MonoPulseSpacing.md),
              DropdownButtonFormField<String?>(
                initialValue: _assignee,
                decoration: const InputDecoration(
                  labelText: 'Assignee (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(child: Text('—')),
                  for (final m in widget.members)
                    DropdownMenuItem(
                      value: m.uid,
                      child: Text(
                        memberLabel(displayName: m.displayName, email: m.email),
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _assignee = v),
              ),
            ],
            const SizedBox(height: MonoPulseSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: MonoPulseSpacing.sm),
                ElevatedButton(
                  onPressed: () {
                    final title = _title.text.trim();
                    if (title.isEmpty) return;
                    final now = DateTime.now();
                    Navigator.pop(
                      context,
                      SongTask(
                        id: _uuid.v4(),
                        songId: widget.songId,
                        bandId: widget.bandId,
                        title: title,
                        assignedToUserId: _assignee,
                        dueAt: _dueAt,
                        createdAt: now,
                        updatedAt: now,
                      ),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Save-version sheet (#70): name, optional notes, mark-current flag.
class _SaveVersionSheet extends StatefulWidget {
  const _SaveVersionSheet();

  @override
  State<_SaveVersionSheet> createState() => _SaveVersionSheetState();
}

class _SaveVersionSheetState extends State<_SaveVersionSheet> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  bool _makeCurrent = true;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Save version', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'A named snapshot of the song as it is right now — key, BPM, '
              'structure and the full chord chart.',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: context.mp.textSecondary,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name (e.g. v0.3, Live, Acoustic)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'What changed? (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mark as current version'),
              value: _makeCurrent,
              onChanged: (v) => setState(() => _makeCurrent = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: MonoPulseSpacing.sm),
                ElevatedButton(
                  onPressed: () {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(context, (
                      name,
                      _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                      _makeCurrent,
                    ));
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
