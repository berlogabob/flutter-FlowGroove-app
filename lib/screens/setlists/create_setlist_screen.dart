import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/band.dart';
import '../../models/event_kit.dart';
import '../../models/lineup.dart';
import '../../models/setlist.dart';
import '../../models/setlist_break_type.dart';
import '../../models/song.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../services/analytics_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/confirmed_write.dart';
import '../../utils/snackbar.dart';
import '../../widgets/menu_items_scope.dart';
import '../../widgets/primary_action_bar.dart';
import '../../widgets/setlist_break_row.dart';
import '../../widgets/setlist_song_row.dart';
import 'performer_sheet.dart';

enum SetlistStorageScope { personal, band }

class CreateSetlistScreen extends ConsumerStatefulWidget {
  const CreateSetlistScreen({
    super.key,
    this.setlist,
    this.bandId,
    this.storageScope = SetlistStorageScope.personal,
  });

  final Setlist? setlist;
  final String? bandId;
  final SetlistStorageScope storageScope;

  @override
  ConsumerState<CreateSetlistScreen> createState() =>
      _CreateSetlistScreenState();
}

class _CreateSetlistScreenState extends ConsumerState<CreateSetlistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final String _setlistId;
  DateTime? _eventDate;
  final _eventLocationController = TextEditingController();
  List<SetlistItem> _selectedItems = [];
  // songId -> Song, from the last songs fetch. An item whose songId has no
  // entry here is an "unavailable song" — kept in _selectedItems and
  // rendered as a placeholder row instead of being dropped (see
  // _loadSongsForEditing / _reconcileItems).
  Map<String, Song> _songsById = {};
  // The Event Kit rides along with the setlist: it holds the lineup roster
  // that `SetlistItem.performerIds` point at, so the editor must carry it
  // through a save instead of dropping it.
  EventKit? _eventKit;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  bool _showEventDetails = false;

  /// False while an existing setlist's songs are still resolving; saving in
  /// that window would persist songIds: [] and wipe the setlist (#80).
  bool _songsLoaded = true;

  bool get _isEditing => widget.setlist != null;

  /// Band scope is *derived*, not just taken from the caller: a setlist that
  /// carries a bandId is a band setlist, and saving one into the personal
  /// collection is never right — it writes a document nothing reads, since the
  /// personal list filters out anything with a bandId. A caller that forgets to
  /// pass `scope` should not be able to lose the user's edit.
  bool get _isBandScope =>
      widget.storageScope == SetlistStorageScope.band || _effectiveBandId != null;

  String? get _effectiveBandId {
    final rawBandId = _isEditing ? widget.setlist!.bandId : widget.bandId;
    final bandId = rawBandId?.trim();
    return bandId == null || bandId.isEmpty ? null : bandId;
  }

  AsyncValue<List<Song>> _watchAvailableSongs() {
    final bandId = _effectiveBandId;
    return bandId == null
        ? ref.watch(songsProvider)
        : ref.watch(bandSongsProvider(bandId));
  }

  /// Waits for the first emission instead of a one-shot `.value` read:
  /// bandSongsProvider is autoDispose, so a cold read is always `loading`
  /// and used to resolve 0 songs here (#80).
  Future<List<Song>> _fetchAvailableSongs() {
    final bandId = _effectiveBandId;
    return bandId == null
        ? ref.read(songsProvider.future)
        : ref.read(bandSongsProvider(bandId).future);
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _setlistId = widget.setlist?.id ?? const Uuid().v4();
    if (_isEditing) {
      final setlist = widget.setlist!;
      _nameController.text = setlist.name;
      _descriptionController.text = setlist.description ?? '';
      _eventDate = setlist.eventDateTime;
      _eventLocationController.text = setlist.eventLocation ?? '';
      _eventKit = setlist.eventKit;
      // Populate the rows now, not when the songs finish resolving: the items
      // come from the setlist and have nothing to wait for. Assigning them
      // after the await would overwrite anything the user added in the
      // meantime — "Add break" is reachable immediately, so that edit used to
      // disappear the moment the song list arrived.
      _selectedItems = List<SetlistItem>.from(setlist.effectiveItems);
      _songsLoaded = setlist.effectiveItems.isEmpty;
      _loadSongsForEditing(setlist);
    }
  }

  Future<void> _loadSongsForEditing(Setlist setlist) async {
    List<Song> allSongs;
    try {
      allSongs = await _fetchAvailableSongs();
    } catch (_) {
      allSongs = [];
    }
    final songsById = <String, Song>{
      for (final song in allSongs) song.id: song,
    };
    final items = setlist.effectiveItems;
    if (!mounted) return;
    setState(() {
      _songsLoaded =
          allSongs.isNotEmpty ||
          items.isEmpty; // a failed load never counts as "loaded empty"
      // Only the lookup used to render a row — `_selectedItems` was already
      // populated in initState and may since have been edited, so it must not
      // be reassigned here.
      //
      // Every entry is kept, resolvable or not: an unresolvable songId is
      // still an entry, and renders as an "unavailable song" placeholder row
      // (see build()'s itemBuilder) instead of being silently dropped, which
      // used to permanently delete it on save.
      // ponytail: orphan cleanup is manual-by-design here (the user removes
      // a stale row via the same swipe-to-delete flow as any other row);
      // server-side/automatic cleanup is out of scope.
      _songsById = songsById;
    });
  }

  /// Reconciles the picker's chosen [songs] against `_selectedItems` while
  /// preserving order and non-song items IN PLACE. Break/divider items and
  /// unresolvable ("unavailable") song placeholders are kept where they are —
  /// the picker can't display them, so it never moves or removes them. Existing
  /// selected songs keep their id/tuningPresetId/position; deselected songs are
  /// dropped; newly picked songs are appended.
  List<SetlistItem> _reconcileItems(List<Song> songs) {
    final selectedIds = songs.map((s) => s.id).toSet();
    final keptSongIds = <String>{};
    final kept = <SetlistItem>[];
    for (final item in _selectedItems) {
      if (item.isBreak) {
        kept.add(item); // divider — always kept in place
      } else if (!_songsById.containsKey(item.songId)) {
        kept.add(item); // orphan/unavailable — kept in place
      } else if (selectedIds.contains(item.songId)) {
        kept.add(item);
        keptSongIds.add(item.songId);
      }
      // else: song was deselected in the picker — drop it.
    }
    for (final song in songs) {
      if (!keptSongIds.contains(song.id)) {
        kept.add(SetlistItem(id: const Uuid().v4(), songId: song.id));
      }
    }
    return kept;
  }

  Future<void> _addBreak() async {
    final result = await _pickBreak();
    if (result == null) return;
    setState(() {
      _selectedItems.add(
        SetlistItem.breakItem(
          id: const Uuid().v4(),
          breakType: result.type,
          label: result.label,
        ),
      );
      _markAsChanged();
    });
  }

  Future<void> _editBreak(int index) async {
    final item = _selectedItems[index];
    final result = await _pickBreak(
      initialType: item.breakType,
      initialLabel: item.breakLabel,
    );
    if (result == null) return;
    setState(() {
      _selectedItems[index] = item.copyWith(
        breakType: result.type,
        breakLabel: result.label,
        // The picker returns null for an emptied label; say so explicitly or
        // copyWith reads it as "unchanged" and puts the old label back.
        clearBreakLabel: result.label == null,
      );
      _markAsChanged();
    });
  }

  /// Break-type picker: a chip per [SetlistBreakType] plus an optional custom
  /// label (e.g. a guest name). Returns null if dismissed.
  Future<({String type, String? label})?> _pickBreak({
    String? initialType,
    String? initialLabel,
  }) {
    var selectedType = initialType ?? SetlistBreakType.breakPause.id;
    final labelController = TextEditingController(text: initialLabel ?? '');
    return showModalBottomSheet<({String type, String? label})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: MonoPulseSpacing.lg,
            right: MonoPulseSpacing.lg,
            top: MonoPulseSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + MonoPulseSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Break', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in SetlistBreakType.all)
                    ChoiceChip(
                      avatar: Icon(t.icon, size: 16),
                      label: Text(t.defaultLabel),
                      selected: selectedType == t.id,
                      onSelected: (_) => setSheet(() => selectedType = t.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Custom label (optional)',
                  hintText: 'e.g. EUSTACE',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () {
                    final label = labelController.text.trim();
                    Navigator.pop(context, (
                      type: selectedType,
                      label: label.isEmpty ? null : label,
                    ));
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(labelController.dispose);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _eventLocationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: MonoPulseColors.accentOrange,
              onPrimary: Colors.white,
              onSurface: context.mp.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _eventDate = picked;
        _markAsChanged();
      });
    }
  }

  void _clearDate() {
    setState(() {
      _eventDate = null;
      _markAsChanged();
    });
  }

  Future<void> _showSongPicker() async {
    final songs = await _fetchAvailableSongs();
    if (!mounted) return;

    setState(() {
      // Freshen resolution with the latest fetch without forgetting songs
      // seen earlier this session.
      _songsById = {..._songsById, for (final song in songs) song.id: song};
    });

    final currentlySelected = [
      for (final item in _selectedItems)
        if (_songsById[item.songId] case final song?) song,
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _SongPickerSheet(
          songs: songs,
          selectedSongs: currentlySelected,
          scrollController: scrollController,
          onConfirm: (selected) {
            setState(() {
              _selectedItems = _reconcileItems(selected);
              _markAsChanged();
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  /// Band members of the setlist's band, so they can be assigned alongside
  /// guest placeholders. Empty for a personal setlist.
  List<BandMember> get _bandMembers {
    final bandId = _effectiveBandId;
    if (bandId == null) return const [];
    final bands = ref.read(bandsProvider).value ?? const [];
    for (final band in bands) {
      if (band.id == bandId) return band.members;
    }
    return const [];
  }

  /// Assigns people to the song at [index]. "Plays every song" ids are added
  /// to every song item, so a pianist who plays the whole set is one tap.
  Future<void> _assignPerformers(int index, int songNumber) async {
    final item = _selectedItems[index];
    final result = await showPerformerSheet(
      context: context,
      selected: item.performerIds,
      kit: _eventKit ?? const EventKit(),
      members: _bandMembers,
      songNumber: songNumber + 1,
      songTitle: _songsById[item.songId]?.title ?? 'Unavailable song',
    );
    if (result == null || !mounted) return;
    setState(() {
      _eventKit = result.kit;
      _selectedItems[index] = item.copyWith(performerIds: result.performerIds);
      if (result.allSongIds.isNotEmpty) {
        for (var i = 0; i < _selectedItems.length; i++) {
          final other = _selectedItems[i];
          if (other.isBreak) continue;
          final ids = {...other.performerIds, ...result.allSongIds};
          _selectedItems[i] = other.copyWith(performerIds: ids.toList());
        }
      }
      _markAsChanged();
    });
  }

  Future<void> _saveSetlist() async {
    if (_isSaving) return;
    if (!_songsLoaded) {
      showAppSnackBar(
        context,
        'Songs are still loading — try again in a moment',
      );
      return;
    }
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user == null) {
      showAppSnackBar(context, 'Please login first');
      return;
    }

    final bandId = _effectiveBandId;
    if (_isBandScope && bandId == null) {
      showAppSnackBar(context, 'Band is required for shared setlists');
      return;
    }

    // _selectedItems is already the source of truth (kept in sync by
    // reorder/add/remove below) — no need to reconcile against a resolved
    // song list here. This is what makes the save round-trip unresolved
    // ("unavailable song") entries unchanged instead of dropping them.
    final items = List<SetlistItem>.from(_selectedItems);
    final setlist = Setlist(
      id: _setlistId,
      bandId: bandId ?? '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      eventDateTime: _eventDate,
      eventLocation: _eventLocationController.text.trim().isNotEmpty
          ? _eventLocationController.text.trim()
          : null,
      songIds: items
          .where((item) => !item.isBreak && item.songId.isNotEmpty)
          .map((item) => item.songId)
          .toList(),
      items: items,
      totalDuration: widget.setlist?.totalDuration,
      assignments: widget.setlist?.assignments ?? const {},
      eventKit: _eventKit,
      createdAt: _isEditing ? widget.setlist!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      // Await the backend ack with a deadline: on a flaky network the write
      // future can hang while the write sits in the local queue — say
      // "queued", never a false "saved".
      final ack = await awaitServerAck(
        _isBandScope
            ? ref.read(firestoreProvider).saveBandSetlist(setlist, bandId!)
            : ref.read(firestoreProvider).saveSetlist(setlist, uid: user.uid),
      );

      await AnalyticsService.logSetlistCreatedFromSetlist(setlist);
      await AnalyticsService.logSetlistSaved(isBand: _isBandScope);

      if (!mounted) return;
      // Invalidate the setlists provider to ensure UI refresh
      if (_isBandScope) {
        ref.invalidate(bandSetlistsProvider(bandId!));
      } else {
        ref.invalidate(setlistsProvider);
      }

      // Show snackbar
      showAppSnackBar(
        context,
        ack == WriteAck.queued
            ? 'No connection — "${setlist.name}" is queued and will sync '
                  "when you're back online"
            : '${_isBandScope ? 'Band setlist' : 'Setlist'} '
                  '"${setlist.name}" ${_isEditing ? 'updated' : 'created'}',
      );

      // Clear unsaved changes flag after successful save
      setState(() => _hasUnsavedChanges = false);

      // Small delay to allow provider to refresh before navigating back
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        _isBandScope
            ? 'Could not save the shared setlist. Check your band permissions and try again.'
            : 'Could not save the setlist. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _showDiscardChangesDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
              'You have unsaved changes. Are you sure you want to discard them?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final availableSongsAsync = _watchAvailableSongs();

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // Already popped

        if (_hasUnsavedChanges) {
          final confirm = await _showDiscardChangesDialog();
          if (confirm && context.mounted) {
            if (context.mounted) {
              Navigator.pop(context); // Allow pop
            }
          }
        }
      },
      child: MenuScopePublisher(
        data: MenuScopeData(
          title: _isEditing
              ? (_isBandScope ? 'Edit Band Setlist' : 'Edit Setlist')
              : (_isBandScope ? 'Create Band Setlist' : 'Create Setlist'),
        ),
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(MonoPulseSpacing.lg),
                children: [
                  // Name + the expand/collapse arrow share one row; event details
                  // (date/place/description) reveal below when expanded.
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Setlist Name *',
                            prefixIcon: Icon(Icons.queue_music),
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _markAsChanged(),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      IconButton(
                        tooltip: _showEventDetails
                            ? 'Hide event details'
                            : 'Show event details',
                        icon: Icon(
                          _showEventDetails
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: context.mp.textSecondary,
                        ),
                        onPressed: () => setState(
                          () => _showEventDetails = !_showEventDetails,
                        ),
                      ),
                    ],
                  ),
                  if (_showEventDetails) ...[
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: context.mp.surfaceRaised,
                          borderRadius: BorderRadius.circular(
                            MonoPulseRadius.large,
                          ),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: context.mp.textSecondary,
                        ),
                      ),
                      title: Text(
                        'Event Date',
                        style: MonoPulseTypography.bodySmall.copyWith(
                          color: context.mp.textSecondary,
                        ),
                      ),
                      subtitle: Text(
                        _eventDate != null
                            ? '${_eventDate!.day.toString().padLeft(2, '0')}.${_eventDate!.month.toString().padLeft(2, '0')}.${_eventDate!.year}'
                            : 'Tap to select date',
                        style: MonoPulseTypography.bodyLarge.copyWith(
                          color: _eventDate != null
                              ? context.mp.textPrimary
                              : context.mp.textTertiary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_eventDate != null)
                            IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: context.mp.textSecondary,
                              ),
                              onPressed: _clearDate,
                            ),
                          Icon(
                            Icons.chevron_right,
                            color: context.mp.textSecondary,
                          ),
                        ],
                      ),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _eventLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Event Location',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _markAsChanged(),
                      onFieldSubmitted: (_) => _saveSetlist(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 2,
                      onChanged: (_) => _markAsChanged(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Songs (${_selectedItems.where((i) => !i.isBreak).length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: _addBreak,
                            icon: const Icon(Icons.horizontal_rule),
                            label: const Text('Break'),
                          ),
                          TextButton.icon(
                            onPressed: availableSongsAsync.isLoading
                                ? null
                                : _showSongPicker,
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (availableSongsAsync.hasError) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Band songs could not be loaded.',
                            style: TextStyle(color: MonoPulseColors.error),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(
                            bandSongsProvider(_effectiveBandId!),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_selectedItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(MonoPulseSpacing.xxxl),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.mp.borderDefault),
                        borderRadius: BorderRadius.circular(
                          MonoPulseRadius.medium,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.music_note,
                            size: 48,
                            color: context.mp.textTertiary,
                          ),
                          const SizedBox(height: MonoPulseSpacing.md),
                          Text(
                            'No songs added',
                            style: TextStyle(color: context.mp.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // No drag-handle column (it squeezed the song name):
                      // reorder by long-press, matching the list screens.
                      buildDefaultDragHandles: false,
                      itemCount: _selectedItems.length,
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = _selectedItems.removeAt(oldIndex);
                          _selectedItems.insert(newIndex, item);
                          _markAsChanged();
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = _selectedItems[index];
                        if (item.isBreak) {
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey(item.id),
                            index: index,
                            child: Dismissible(
                              key: ValueKey('dismiss_${item.id}'),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) {
                                final removed = _selectedItems[index];
                                setState(() {
                                  _selectedItems.removeAt(index);
                                  _markAsChanged();
                                });
                                showAppSnackBar(
                                  context,
                                  'Removed break',
                                  actionLabel: 'Undo',
                                  analyticsAction: 'setlist_break_removed',
                                  onAction: () => setState(() {
                                    _selectedItems.insert(index, removed);
                                    _markAsChanged();
                                  }),
                                );
                              },
                              child: InkWell(
                                onTap: () => _editBreak(index),
                                child: SetlistBreakRow(
                                  breakType: item.breakType,
                                  label: item.breakLabel,
                                ),
                              ),
                            ),
                          );
                        }
                        final song = _songsById[item.songId];
                        // Songs number per section (reset after each break).
                        var songNumber = 0;
                        for (var i = 0; i < index; i++) {
                          if (_selectedItems[i].isBreak) {
                            songNumber = 0;
                          } else {
                            songNumber++;
                          }
                        }
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(item.id),
                          index: index,
                          child: Dismissible(
                          key: ValueKey('dismiss_${item.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            margin: const EdgeInsets.only(
                              bottom: MonoPulseSpacing.md,
                            ),
                            padding: const EdgeInsets.only(
                              right: MonoPulseSpacing.xl,
                            ),
                            decoration: BoxDecoration(
                              color: MonoPulseColors.error,
                              borderRadius: BorderRadius.circular(
                                MonoPulseRadius.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.delete,
                              color: context.mp.textPrimary,
                            ),
                          ),
                          onDismissed: (_) {
                            final removedItem = _selectedItems[index];
                            final removedSong = _songsById[removedItem.songId];
                            setState(() {
                              _selectedItems.removeAt(index);
                              _markAsChanged();
                            });

                            // Show snackbar with undo action
                            showAppSnackBar(
                              context,
                              'Removed "${removedSong?.title ?? 'Unavailable song'}"',
                              actionLabel: 'Undo',
                              analyticsAction: 'song_removed',
                              onAction: () {
                                setState(() {
                                  _selectedItems.insert(index, removedItem);
                                  _markAsChanged();
                                });
                              },
                            );
                          },
                          child: SetlistSongRow(
                            index: songNumber,
                            song: song,
                            // Assigned people are always materialised into the
                            // kit roster, so it alone resolves the labels.
                            performers: performerLabel(
                              item.performerIds,
                              peopleById(_eventKit?.people ?? const []),
                            ),
                            trailing: song == null
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Who plays this',
                                        icon: Badge(
                                          isLabelVisible:
                                              item.performerIds.isNotEmpty,
                                          label: Text(
                                            '${item.performerIds.length}',
                                          ),
                                          child: const Icon(
                                            Icons.person_outline,
                                          ),
                                        ),
                                        onPressed: () => _assignPerformers(
                                          index,
                                          songNumber,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: MonoPulseSpacing.md,
                                          vertical: MonoPulseSpacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: MonoPulseColors.accentOrange10,
                                          borderRadius: BorderRadius.circular(
                                            MonoPulseRadius.small,
                                          ),
                                        ),
                                        child: Text(
                                          song.ourKey ?? '-',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: MonoPulseColors.accentOrange,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (song.ourBPM != null)
                                        Text(
                                          '${song.ourBPM}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      if (song.spotifyUrl != null) ...[
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () async {
                                            final uri = Uri.parse(
                                              song.spotifyUrl!,
                                            );
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(
                                                uri,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          },
                                          child: const Icon(
                                            Icons.play_circle_fill,
                                            color:
                                                MonoPulseColors.beatModeAccent,
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: PrimaryActionBar(
            label: _isSaving
                ? 'Saving...'
                : (_isEditing ? 'Save Changes' : 'Create Setlist'),
            onPressed: !_isSaving ? _saveSetlist : null,
            isLoading: _isSaving,
          ),
        ),
      ),
    );
  }
}

class _SongPickerSheet extends StatefulWidget {
  const _SongPickerSheet({
    required this.songs,
    required this.selectedSongs,
    required this.scrollController,
    required this.onConfirm,
  });

  final List<Song> songs;
  final List<Song> selectedSongs;
  final ScrollController scrollController;
  final ValueChanged<List<Song>> onConfirm;

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  late List<Song> _tempSelected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.selectedSongs);
  }

  @override
  Widget build(BuildContext context) {
    final filteredSongs = widget.songs
        .where(
          (s) =>
              _searchQuery.isEmpty ||
              s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.artist.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Songs (${_tempSelected.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton(
                onPressed: () => widget.onConfirm(_tempSelected),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: filteredSongs.length,
            itemBuilder: (context, index) {
              final song = filteredSongs[index];
              final isSelected = _tempSelected.any((s) => s.id == song.id);
              return CheckboxListTile(
                value: isSelected,
                onChanged: (v) => setState(
                  () => v == true
                      ? _tempSelected.add(song)
                      : _tempSelected.removeWhere((s) => s.id == song.id),
                ),
                title: Text(song.title),
                subtitle: Text(song.artist),
              );
            },
          ),
        ),
      ],
    );
  }
}
