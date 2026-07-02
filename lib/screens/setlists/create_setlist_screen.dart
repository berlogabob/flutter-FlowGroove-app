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
import '../../widgets/custom_app_bar.dart';
import '../../widgets/primary_action_bar.dart';
import '../../utils/snackbar.dart';

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
  List<Song> _selectedSongs = [];
  List<SetlistItem> _selectedItems = [];
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  bool _showEventDetails = false;

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

  AsyncValue<List<Song>> _readAvailableSongs() {
    final bandId = _effectiveBandId;
    return bandId == null
        ? ref.read(songsProvider)
        : ref.read(bandSongsProvider(bandId));
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
      _loadSongsForEditing(setlist);
    }
  }

  void _loadSongsForEditing(Setlist setlist) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final songsAsync = _readAvailableSongs();
      final allSongs = songsAsync.value ?? [];
      final songsById = <String, Song>{
        for (final song in allSongs) song.id: song,
      };
      final items = setlist.effectiveItems;
      if (!mounted) return;
      setState(() {
        _selectedSongs = [
          for (final item in items)
            ?songsById[item.songId],
        ];
        _selectedItems = [
          for (final item in items)
            if (songsById.containsKey(item.songId)) item,
        ];
      });
    });
  }

  List<SetlistItem> _reconcileItems(List<Song> songs) {
    final available = List<SetlistItem>.from(_selectedItems);
    return [
      for (final song in songs)
        if (available.indexWhere((item) => item.songId == song.id)
            case final index when index >= 0)
          available.removeAt(index)
        else
          SetlistItem(id: const Uuid().v4(), songId: song.id),
    ];
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
            colorScheme: const ColorScheme.dark(
              primary: MonoPulseColors.accentOrange,
              onPrimary: Colors.white,
              onSurface: MonoPulseColors.textPrimary,
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
    final songsAsync = _readAvailableSongs();
    final songs = songsAsync.value ?? [];

    final result = await showModalBottomSheet<List<Song>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _SongPickerSheet(
          songs: songs,
          selectedSongs: _selectedSongs,
          scrollController: scrollController,
          onConfirm: (selected) {
            setState(() {
              _selectedItems = _reconcileItems(selected);
              _selectedSongs = selected;
              _markAsChanged();
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedItems = _reconcileItems(result);
        _selectedSongs = result;
      });
    }
  }

  Future<void> _saveSetlist() async {
    if (_isSaving) return;
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

    final items = _reconcileItems(_selectedSongs);
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
      songIds: _selectedSongs.map((s) => s.id).toList(),
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

      if (!mounted) return;
      // Invalidate the setlists provider to ensure UI refresh
      if (_isBandScope) {
        ref.invalidate(bandSetlistsProvider(bandId!));
      } else {
        ref.invalidate(setlistsProvider);
      }

      // Show snackbar
      showAppSnackBar(context, '${_isBandScope ? 'Band setlist' : 'Setlist'} "${setlist.name}" ${_isEditing ? 'updated' : 'created'}');

      // Clear unsaved changes flag after successful save
      setState(() => _hasUnsavedChanges = false);

      // Small delay to allow provider to refresh before navigating back
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, _isBandScope
                ? 'Could not save the shared setlist. Check your band permissions and try again.'
                : 'Could not save the setlist. Please try again.');
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
      child: Scaffold(
        appBar: CustomAppBar.build(
          context,
          title: _isEditing
              ? (_isBandScope ? 'Edit Band Setlist' : 'Edit Setlist')
              : (_isBandScope ? 'Create Band Setlist' : 'Create Setlist'),
        ),
        body: Form(
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
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  IconButton(
                    tooltip: _showEventDetails
                        ? 'Hide event details'
                        : 'Show event details',
                    icon: Icon(
                      _showEventDetails ? Icons.expand_less : Icons.expand_more,
                      color: MonoPulseColors.textSecondary,
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
                    color: MonoPulseColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(MonoPulseRadius.large),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: MonoPulseColors.textSecondary,
                  ),
                ),
                title: Text(
                  'Event Date',
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: MonoPulseColors.textSecondary,
                  ),
                ),
                subtitle: Text(
                  _eventDate != null
                      ? '${_eventDate!.day.toString().padLeft(2, '0')}.${_eventDate!.month.toString().padLeft(2, '0')}.${_eventDate!.year}'
                      : 'Tap to select date',
                  style: MonoPulseTypography.bodyLarge.copyWith(
                    color: _eventDate != null
                        ? MonoPulseColors.textPrimary
                        : MonoPulseColors.textTertiary,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_eventDate != null)
                      IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: MonoPulseColors.textSecondary,
                        ),
                        onPressed: _clearDate,
                      ),
                    const Icon(
                      Icons.chevron_right,
                      color: MonoPulseColors.textSecondary,
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
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
                onChanged: (_) => _markAsChanged(),
              ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Songs (${_selectedSongs.length})',
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
                      onPressed: () =>
                          ref.invalidate(bandSongsProvider(_effectiveBandId!)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (_selectedSongs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(MonoPulseSpacing.xxxl),
                  decoration: BoxDecoration(
                    border: Border.all(color: MonoPulseColors.borderDefault),
                    borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 48,
                        color: MonoPulseColors.textTertiary,
                      ),
                      SizedBox(height: MonoPulseSpacing.md),
                      Text(
                        'No songs added',
                        style: TextStyle(color: MonoPulseColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedSongs.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final song = _selectedSongs.removeAt(oldIndex);
                      final item = _selectedItems.removeAt(oldIndex);
                      _selectedSongs.insert(newIndex, song);
                      _selectedItems.insert(newIndex, item);
                      _markAsChanged();
                    });
                  },
                  itemBuilder: (context, index) {
                    final song = _selectedSongs[index];
                    return Dismissible(
                      key: ValueKey(song.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        margin: const EdgeInsets.only(bottom: MonoPulseSpacing.md),
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: MonoPulseColors.error,
                          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                        ),
                        child: const Icon(Icons.delete, color: MonoPulseColors.textPrimary),
                      ),
                      onDismissed: (_) => setState(() {
                        _selectedSongs.removeAt(index);
                        _selectedItems.removeAt(index);
                        _markAsChanged();
                      }),
                      child: Card(
                      margin: const EdgeInsets.only(
                        bottom: MonoPulseSpacing.md,
                      ),
                      child: ListTile(
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(
                            Icons.drag_handle,
                            color: MonoPulseColors.textTertiary,
                          ),
                        ),
                        title: Text(
                          song.title,
                          style: const TextStyle(
                            color: MonoPulseColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          style: const TextStyle(
                            color: MonoPulseColors.textSecondary,
                          ),
                        ),
                        trailing: Row(
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
                                  final uri = Uri.parse(song.spotifyUrl!);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                                child: const Icon(
                                  Icons.play_circle_fill,
                                  color: MonoPulseColors.beatModeAccent,
                                  size: 24,
                                ),
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.tune, size: 20),
                              tooltip: 'Open in Tuner',
                              onPressed: () => _openTunerForItem(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.av_timer, size: 20),
                              tooltip: 'Open in metronome',
                              onPressed: () => _openInMetronome(index),
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
        bottomNavigationBar: PrimaryActionBar(
          label: _isSaving
              ? 'Saving...'
              : (_isEditing ? 'Save Changes' : 'Create Setlist'),
          onPressed: !_isSaving ? _saveSetlist : null,
          isLoading: _isSaving,
        ),
      ),
    );
  }

  void _openInMetronome(int index) {
    if (index < 0 || index >= _selectedSongs.length) return;
    // Build a draft from current (possibly unsaved) state so the metronome
    // loads exactly what's on screen, positioned at the tapped song.
    final draft = Setlist(
      id: _setlistId,
      bandId: _effectiveBandId ?? '',
      name: _nameController.text.trim(),
      songIds: _selectedSongs.map((value) => value.id).toList(),
      items: _selectedItems,
      createdAt: widget.setlist?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final loaded = ref.read(metronomeProvider.notifier).loadSetlistQueue(
          draft,
          availableSongs: _selectedSongs,
          sourceBandId: _effectiveBandId,
          startIndex: index,
        );
    if (loaded) context.goNamed('metronome');
  }

  Future<void> _openTunerForItem(int index) async {
    if (index < 0 ||
        index >= _selectedSongs.length ||
        index >= _selectedItems.length) {
      return;
    }
    final song = _selectedSongs[index];
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
      songIds: _selectedSongs.map((value) => value.id).toList(),
      items: _selectedItems,
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
        setlistItemId: _selectedItems[index].id,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
