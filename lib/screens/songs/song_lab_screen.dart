import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/band.dart';
import '../../models/song.dart';
import '../../models/song_lab.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/export/lab_markdown.dart';
import '../../services/storage_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/chordpro.dart';
import '../../utils/member_label.dart';
import '../../utils/snackbar.dart';
import '../../widgets/app_filter_chip.dart';
import '../../widgets/app_menu_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/standard_screen_scaffold.dart';
import 'components/lab_recording_sheet.dart';

/// Song Lab timeline (#67): a reverse-chronological journal of typed entries
/// for one song — the history of "our version" (notes, decisions,
/// experiments, problems). Quick-add covers 4 types; the model carries more.
class SongLabScreen extends ConsumerStatefulWidget {
  const SongLabScreen({required this.song, this.bandId, super.key});

  final Song song;
  final String? bandId;

  @override
  ConsumerState<SongLabScreen> createState() => _SongLabScreenState();
}

class _SongLabScreenState extends ConsumerState<SongLabScreen> {
  static const _uuid = Uuid();

  /// null = all types.
  LabEntryType? _typeFilter;
  bool _showTasks = false;
  bool _migrated = false;

  (String, String?) get _key => (widget.song.id, widget.bandId);

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
    if (_migrated || entries.isNotEmpty) return;
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
    final result = await showModalBottomSheet<_ComposeResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComposeEntrySheet(
        type: existing?.type ?? type,
        song: widget.song,
        existing: existing,
      ),
    );
    if (result == null || !mounted) return;

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

  Future<void> _delete(SongLabEntry entry) async {
    final repo = ref.read(labRepositoryProvider);
    await repo.deleteEntry(widget.song.id, entry.id, bandId: widget.bandId);
    if (!mounted) return;
    showAppSnackBar(
      context,
      'Entry deleted',
      actionLabel: 'Undo',
      onAction: () => repo.saveEntry(entry, bandId: widget.bandId),
    );
  }

  Future<void> _setStatus(SongLabEntry entry, String status) => ref
      .read(labRepositoryProvider)
      .saveEntry(entry.copyWith(status: status), bandId: widget.bandId);

  // ---- Versions (#70) ----

  Future<void> _saveVersion() async {
    final result = await showModalBottomSheet<(String, String?, bool)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SaveVersionSheet(),
    );
    if (result == null || !mounted) return;
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
    if (makeCurrent) {
      await repo.setCurrentVersion(
        widget.song.id,
        version.id,
        bandId: widget.bandId,
      );
    }
    // The changelog lives in the timeline (never silently overwritten).
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
    return StandardScreenScaffold(
      title: 'Lab — ${widget.song.title}',
      menuItems: [
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MonoPulseSpacing.lg,
              MonoPulseSpacing.md,
              MonoPulseSpacing.lg,
              0,
            ),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Entries')),
                ButtonSegment(value: true, label: Text('Tasks')),
              ],
              selected: {_showTasks},
              onSelectionChanged: (s) => setState(() => _showTasks = s.first),
            ),
          ),
          Expanded(child: _showTasks ? _tasksTab() : _entriesTab()),
        ],
      ),
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
                  ? EmptyState(
                      icon: Icons.science_outlined,
                      message: entries.isEmpty
                          ? 'The story of this song starts here'
                          : 'Nothing of this type yet',
                      hint: entries.isEmpty
                          ? 'Capture ideas, decisions ("why we play it '
                                'this way"), experiments and problems — '
                                'so the band never loses the context.'
                          : null,
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
              child: ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add task'),
                onPressed: _composeTask,
              ),
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
                                color: MonoPulseColors.textSecondary,
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
              : const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: MonoPulseColors.textSecondary,
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
          onPressed: () => _cycleStatus(t),
        ),
        onLongPress: () async {
          final repo = ref.read(labRepositoryProvider);
          await repo.deleteTask(widget.song.id, t.id, bandId: widget.bandId);
          if (!mounted) return;
          showAppSnackBar(
            context,
            'Task deleted',
            actionLabel: 'Undo',
            onAction: () => repo.saveTask(t, bandId: widget.bandId),
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
    if (result == null || !mounted) return;
    await ref
        .read(labRepositoryProvider)
        .saveTask(result, bandId: widget.bandId);
  }

  Widget _quickAddRow() => Padding(
    padding: const EdgeInsets.fromLTRB(
      MonoPulseSpacing.lg,
      MonoPulseSpacing.md,
      MonoPulseSpacing.lg,
      0,
    ),
    child: Wrap(
      spacing: MonoPulseSpacing.sm,
      children: [
        for (final t in _quickTypes)
          ActionChip(
            avatar: Icon(_typeIcons[t], size: 18),
            label: Text('+ ${_typeLabel(t)}'),
            onPressed: () => _compose(t),
          ),
        ActionChip(
          avatar: Icon(_typeIcons[LabEntryType.recording], size: 18),
          label: const Text('+ Recording'),
          onPressed: _composeRecording,
        ),
      ],
    ),
  );

  /// Record/attach an audio idea (#69): upload to Storage, then a
  /// `recording` entry with the download URL as its attachment.
  Future<void> _composeRecording() async {
    final result = await showModalBottomSheet<LabRecordingResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LabRecordingSheet(),
    );
    if (result == null || !mounted) return;

    final entryId = _uuid.v4();
    try {
      final url = await StorageService().uploadLabAudio(
        result.bytes,
        bandId: widget.bandId,
        songId: widget.song.id,
        entryId: entryId,
        ext: result.ext,
      );
      final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
      final now = DateTime.now();
      await ref
          .read(labRepositoryProvider)
          .saveEntry(
            SongLabEntry(
              id: entryId,
              songId: widget.song.id,
              bandId: widget.bandId,
              type: LabEntryType.recording,
              title: result.title,
              body: result.notes,
              authorId: uid,
              createdAt: now,
              updatedAt: now,
              attachmentIds: [url],
            ),
            bandId: widget.bandId,
          );
      unawaited(
        AnalyticsService.logLabEntryAdded(type: LabEntryType.recording.name),
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Upload failed: $e');
    }
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
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.lg,
        vertical: MonoPulseSpacing.xs,
      ),
      child: ListTile(
        leading: Icon(
          _typeIcons[e.type],
          color: superseded
              ? MonoPulseColors.textSecondary
              : MonoPulseColors.accentOrange,
        ),
        title: Text(
          e.title?.isNotEmpty == true ? e.title! : _typeLabel(e.type),
          style: superseded
              ? const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: MonoPulseColors.textSecondary,
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
                '${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}',
              ].join(' · '),
              style: MonoPulseTypography.bodySmall.copyWith(
                color: MonoPulseColors.textSecondary,
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
            _ => null,
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (e.type == LabEntryType.decision && e.status == 'active')
              const PopupMenuItem(
                value: 'supersede',
                child: Text('Mark superseded'),
              ),
            if (e.type == LabEntryType.experiment) ...[
              const PopupMenuItem(value: 'tried', child: Text('Tried it')),
              const PopupMenuItem(value: 'accepted', child: Text('Accepted')),
              const PopupMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
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
                color: MonoPulseColors.textSecondary,
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
