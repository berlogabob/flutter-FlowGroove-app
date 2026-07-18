import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../models/tuner_launch_context.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../services/analytics_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import '../../widgets/menu_items_scope.dart';
import '../../widgets/primary_action_bar.dart';
import '../../widgets/setlist_song_row.dart';

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
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  bool _showEventDetails = false;

  /// False while an existing setlist's songs are still resolving; saving in
  /// that window would persist songIds: [] and wipe the setlist (#80).
  bool _songsLoaded = true;

  bool get _isEditing => widget.setlist != null;
  bool get _isBandScope => widget.storageScope == SetlistStorageScope.band;

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
      _songsById = songsById;
      // Keep every entry, resolvable or not — an unresolvable songId is
      // still an entry. Unresolved items render as "unavailable song"
      // placeholder rows (see build()'s itemBuilder) instead of being
      // silently dropped, which used to permanently delete them on save.
      // ponytail: orphan cleanup is manual-by-design here (the user removes
      // a stale row via the same swipe-to-delete flow as any other row);
      // server-side/automatic cleanup is out of scope.
      _selectedItems = List<SetlistItem>.from(items);
    });
  }

  /// Reconciles the picker's chosen (always-resolvable) [songs] against
  /// `_selectedItems`, reusing each existing item's id/tuningPresetId where
  /// the song was already selected. Any item that doesn't resolve against
  /// `_songsById` (an "unavailable song" placeholder) is preserved verbatim
  /// and appended after the resolved items — the song picker has no way to
  /// display or deselect an entry it can't resolve, so it never removes one.
  List<SetlistItem> _reconcileItems(List<Song> songs) {
    final available = List<SetlistItem>.from(_selectedItems);
    final resolved = [
      for (final song in songs)
        if (available.indexWhere((item) => item.songId == song.id)
            case final index when index >= 0)
          available.removeAt(index)
        else
          SetlistItem(id: const Uuid().v4(), songId: song.id),
    ];
    final orphans = available.where(
      (item) => !_songsById.containsKey(item.songId),
    );
    return [...resolved, ...orphans];
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
      songIds: items.map((item) => item.songId).toList(),
      items: items,
      totalDuration: widget.setlist?.totalDuration,
      assignments: widget.setlist?.assignments ?? const {},
      createdAt: _isEditing ? widget.setlist!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      if (_isBandScope) {
        await ref.read(firestoreProvider).saveBandSetlist(setlist, bandId!);
      } else {
        await ref.read(firestoreProvider).saveSetlist(setlist, uid: user.uid);
      }

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
        '${_isBandScope ? 'Band setlist' : 'Setlist'} "${setlist.name}" ${_isEditing ? 'updated' : 'created'}',
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
                        'Songs (${_selectedItems.length})',
                        style: Theme.of(context).textTheme.titleMedium,
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
                        final song = _songsById[item.songId];
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
                            index: index,
                            song: song,
                            trailing: song == null
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                      IconButton(
                                        icon: const Icon(Icons.tune, size: 20),
                                        tooltip: 'Open in Tuner',
                                        onPressed: () =>
                                            _openTunerForItem(index),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.av_timer,
                                          size: 20,
                                        ),
                                        tooltip: 'Open in metronome',
                                        onPressed: () =>
                                            _openInMetronome(index),
                                      ),
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

  void _openInMetronome(int index) {
    if (index < 0 || index >= _selectedItems.length) return;
    final targetSong = _songsById[_selectedItems[index].songId];
    if (targetSong == null) {
      return; // Unavailable-song rows hide this action; defensive no-op.
    }
    // Build a draft from current (possibly unsaved) state so the metronome
    // loads exactly what's on screen. availableSongs only carries the
    // entries that currently resolve — MetronomeNotifier._resolveQueue skips
    // the rest instead of refusing to load the whole queue.
    final resolvedSongs = [
      for (final item in _selectedItems)
        if (_songsById[item.songId] case final song?) song,
    ];
    final draft = Setlist(
      id: _setlistId,
      bandId: _effectiveBandId ?? '',
      name: _nameController.text.trim(),
      songIds: _selectedItems.map((item) => item.songId).toList(),
      items: List<SetlistItem>.from(_selectedItems),
      createdAt: widget.setlist?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final loaded = ref
        .read(metronomeProvider.notifier)
        .loadSetlistQueue(
          draft,
          availableSongs: resolvedSongs,
          sourceBandId: _effectiveBandId,
          startIndex: resolvedSongs.indexWhere(
            (song) => song.id == targetSong.id,
          ),
        );
    if (loaded) context.pushNamed('metronome');
  }

  Future<void> _openTunerForItem(int index) async {
    if (index < 0 || index >= _selectedItems.length) return;
    final item = _selectedItems[index];
    final song = _songsById[item.songId];
    if (song == null) {
      return; // Unavailable-song rows hide this action; defensive no-op.
    }
    final draft = Setlist(
      id: _setlistId,
      bandId: _effectiveBandId ?? '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      eventDateTime: _eventDate,
      eventLocation: _eventLocationController.text.trim().isEmpty
          ? null
          : _eventLocationController.text.trim(),
      songIds: _selectedItems.map((value) => value.songId).toList(),
      items: List<SetlistItem>.from(_selectedItems),
      totalDuration: widget.setlist?.totalDuration,
      assignments: widget.setlist?.assignments ?? const {},
      createdAt: widget.setlist?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await context.pushNamed<void>(
      'tuner',
      extra: TunerLaunchContext(
        song: song,
        setlist: draft,
        setlistItemId: item.id,
        bandId: _effectiveBandId,
        saveSetlist: (updatedSetlist) async {
          if (!mounted) return;
          setState(() {
            _selectedItems = updatedSetlist.effectiveItems;
            _hasUnsavedChanges = true;
          });
        },
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
