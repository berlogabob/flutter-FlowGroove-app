import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/band.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../services/export/pdf_service.dart';
import '../../services/export/setlist_export_sheet.dart';
import '../../services/export/setlist_share.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import '../../widgets/app_menu_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_banner.dart' show ErrorBanner, ErrorBannerStyle;
import '../../widgets/fab_variants.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/standard_screen_scaffold.dart';
import '../../widgets/unified_item/adapters/setlist_item_adapter.dart';
import '../../widgets/unified_item/setlist_card_actions.dart';
import '../../widgets/unified_item/unified_filter_sort_widget.dart';
import '../../widgets/unified_item/unified_item_list.dart';
import '../setlists/create_setlist_screen.dart';
import '../setlists/event_kit_editor_screen.dart';

class BandSetlistsScreen extends ConsumerStatefulWidget {
  const BandSetlistsScreen({required this.band, super.key});

  final Band band;

  @override
  ConsumerState<BandSetlistsScreen> createState() => _BandSetlistsScreenState();
}

class _BandSetlistsScreenState extends ConsumerState<BandSetlistsScreen> {
  String _searchQuery = '';
  SortOption _sortOption = SortOption.manual;
  List<Setlist>? _manualOrder;

  bool get _canEdit {
    if (ref.read(isDemoUserProvider)) return false;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return false;
    final member = widget.band.members.firstWhere(
      (m) => m.uid == user.uid,
      orElse: () => BandMember(uid: '', role: ''),
    );
    return member.role == BandMember.roleAdmin ||
        member.role == BandMember.roleEditor;
  }

  bool get _canDelete {
    if (ref.read(isDemoUserProvider)) return false;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return false;
    final member = widget.band.members.firstWhere(
      (m) => m.uid == user.uid,
      orElse: () => BandMember(uid: '', role: ''),
    );
    return member.role == BandMember.roleAdmin;
  }

  List<SetlistItemAdapter> _filterAndSortSetlists(List<Setlist> setlists) {
    List<Setlist> setlistsToUse = setlists;
    if (_sortOption == SortOption.manual && _manualOrder != null) {
      setlistsToUse = _manualOrder!;
    }

    var adapters = setlistsToUse.map(SetlistItemAdapter.new).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      adapters = adapters.where((adapter) {
        return adapter.title.toLowerCase().contains(query) ||
            (adapter.subtitle?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_sortOption != SortOption.manual) {
      switch (_sortOption) {
        case SortOption.alphabetical:
          adapters.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
        case SortOption.dateAdded:
          adapters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        case SortOption.dateModified:
          adapters.sort(
            (a, b) => (b.updatedAt ?? DateTime(0)).compareTo(
              a.updatedAt ?? DateTime(0),
            ),
          );
        case SortOption.manual:
          break;
      }
    }

    return adapters;
  }

  void _handleCreate() {
    context.goNamed(
      'create-setlist',
      queryParameters: {
        'bandId': widget.band.id,
        'scope': SetlistStorageScope.band.name,
      },
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    if (!_canEdit ||
        _manualOrder == null ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _manualOrder!.length ||
        newIndex >= _manualOrder!.length) {
      return;
    }

    final newOrder = List<Setlist>.from(_manualOrder!);
    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);

    setState(() {
      _manualOrder = newOrder;
    });

    _saveManualOrder(newOrder);
  }

  Future<void> _saveManualOrder(List<Setlist> order) async {
    if (!_canEdit) return;
    final service = ref.read(firestoreProvider);
    for (final setlist in order) {
      await service.saveBandSetlist(setlist, widget.band.id);
    }
  }

  Future<void> _deleteSetlist(Setlist setlist) async {
    if (!_canDelete) return;
    await ref
        .read(firestoreProvider)
        .deleteBandSetlist(widget.band.id, setlist.id);
    // Undo parity with the personal list (#128).
    if (mounted) {
      showAppSnackBar(
        context,
        'Setlist "${setlist.name}" deleted',
        actionLabel: 'Undo',
        analyticsAction: 'setlist_delete',
        onAction: () async {
          await ref
              .read(firestoreProvider)
              .saveBandSetlist(setlist, widget.band.id);
        },
      );
    }
  }

  void _viewSetlist(Setlist setlist) {
    // Read-only view on tap (P1-7). Use the band-scoped detail route so bandId
    // comes from the path (songs resolve against the BAND library) AND the
    // shell's pushed-bar title shows the setlist name, not the list title.
    context.pushNamed(
      'band-setlist-view',
      pathParameters: {'id': widget.band.id, 'setlistId': setlist.id},
      extra: setlist,
    );
  }

  void _openEventKit(Setlist setlist) {
    // rootNavigator so the editor's bar doesn't stack under the shell bar.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EventKitEditorScreen(setlist: setlist, bandId: widget.band.id),
      ),
    );
  }

  void _editSetlist(Setlist setlist) {
    if (!_canEdit) return;
    context.pushNamed(
      'edit-setlist',
      pathParameters: {'id': setlist.id},
      queryParameters: {
        'bandId': widget.band.id,
        'scope': SetlistStorageScope.band.name,
      },
      extra: setlist,
    );
  }

  @override
  Widget build(BuildContext context) {
    final setlistsAsync = ref.watch(bandSetlistsProvider(widget.band.id));
    // Keep the autoDispose band-songs provider alive for this screen:
    // _songsForSetlist awaits its .future, and without an active listener
    // Riverpod disposes it mid-load ("disposed during loading state", #80).
    ref.watch(bandSongsProvider(widget.band.id));
    final canEdit = _canEdit;
    // When the band has exactly one setlist, offer to edit it straight from the
    // screen menu (with several, per-setlist edit lives on the cards).
    final onlySetlist = setlistsAsync.value?.length == 1
        ? setlistsAsync.value!.first
        : null;

    return StandardScreenScaffold(
      title: '${widget.band.name} Setlists',
      menuItems: canEdit
          ? [
              AppMenuItem(
                icon: Icons.playlist_add,
                label: 'Create Band Setlist',
                onTap: _handleCreate,
              ),
              if (onlySetlist != null)
                AppMenuItem(
                  icon: Icons.edit_outlined,
                  label: 'Edit setlist',
                  onTap: () => _editSetlist(onlySetlist),
                ),
            ]
          : null,
      floatingActionButton: canEdit
          ? SingleFab(
              icon: Icons.add,
              onPressed: _handleCreate,
              heroTag: 'band_setlists_fab_${widget.band.id}',
            )
          : null,
      body: _buildBody(setlistsAsync),
    );
  }

  Widget _buildBody(AsyncValue<List<Setlist>> setlistsAsync) {
    return setlistsAsync.when(
      data: _buildContent,
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(
        child: ErrorBanner(
          message: e.toString(),
          onRetry: () => ref.invalidate(bandSetlistsProvider(widget.band.id)),
          showRetry: true,
          style: ErrorBannerStyle.card,
        ),
      ),
    );
  }

  Widget _buildContent(List<Setlist> setlists) {
    final filteredSetlists = _filterAndSortSetlists(setlists);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: UnifiedFilterSortWidget(
            currentSort: _sortOption,
            hintText: 'Search band setlists...',
            onSortChanged: (option) {
              if (option != null) setState(() => _sortOption = option);
            },
            filterText: _searchQuery.isEmpty ? null : _searchQuery,
            onFilterChanged: (value) =>
                setState(() => _searchQuery = value ?? ''),
          ),
        ),
        Expanded(
          child: filteredSetlists.isEmpty
              ? _buildEmptyState(setlists.isEmpty)
              : _buildSetlistList(filteredSetlists),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    if (!isEmpty) {
      return EmptyState.search(query: _searchQuery);
    }

    return EmptyState(
      icon: Icons.playlist_play,
      message: 'No band setlists yet',
      hint: _canEdit
          ? 'Create a shared setlist for this band'
          : 'Shared setlists will appear here',
      actionLabel: _canEdit ? 'Create Band Setlist' : null,
      onAction: _canEdit ? _handleCreate : null,
    );
  }

  Widget _buildSetlistList(List<SetlistItemAdapter> adapters) {
    final quick = ref.watch(setlistQuickActionProvider);
    return UnifiedItemList<SetlistItemAdapter>(
      items: adapters,
      enableReorder: _canEdit && _sortOption == SortOption.manual,
      onReorder: _canEdit && _sortOption == SortOption.manual
          ? _handleReorder
          : null,
      onDelete: _canDelete
          ? (index) => _deleteSetlist(adapters[index].setlist)
          : null,
      onTap: (index) => _viewSetlist(adapters[index].setlist),
      onEdit: _canEdit
          ? (index) => _editSetlist(adapters[index].setlist)
          : null,
      additionalActionsBuilder: (index) {
        final setlist = adapters[index].setlist;
        return buildSetlistActions(
          quick: quick,
          canEdit: _canEdit,
          onMetronome: () => _openInMetronome(setlist),
          onEdit: () => _editSetlist(setlist),
          onEventKit: () => _openEventKit(setlist),
          onShare: () => _shareSetlist(setlist),
          onCopyLinks: () => _shareAsLinks(setlist),
          onExportPdf: () => _exportPdf(setlist),
          onPickQuickAction: () => showSetlistQuickActionPicker(context, ref),
        );
      },
    );
  }

  /// Awaits the first emission: bandSongsProvider is autoDispose, so a cold
  /// `.value` read here was always `loading` → 0 songs → blank exports (#80).
  Future<List<Song>> _songsForSetlist(Setlist setlist) async {
    final allSongs = await ref.read(bandSongsProvider(widget.band.id).future);
    final songsById = {for (final song in allSongs) song.id: song};
    return setlist.songIds
        .map((songId) => songsById[songId])
        .whereType<Song>()
        .toList();
  }

  Future<void> _openInMetronome(Setlist setlist) async {
    final songs = await _songsForSetlist(setlist);
    if (!mounted) return;
    final loaded = ref
        .read(metronomeProvider.notifier)
        .loadSetlistQueue(
          setlist,
          availableSongs: songs,
          sourceBandId: widget.band.id,
        );
    if (!loaded) {
      showAppSnackBar(
        context,
        'This setlist is empty or has unavailable songs.',
      );
      return;
    }
    await context.pushNamed('metronome');
  }

  Future<void> _exportPdf(Setlist setlist) async {
    final layout = await pickSetlistPdfLayout(
      context,
      withEventGuide: setlist.eventKit?.isEmpty == false,
    );
    if (layout == null) return;
    try {
      await PdfService.exportSetlist(
        setlist,
        await _songsForSetlist(setlist),
        layout: layout,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Error: $e');
    }
  }

  Future<void> _shareSetlist(Setlist setlist) async {
    final songs = await _songsForSetlist(setlist);
    if (!mounted) return;
    shareSetlistLinks(context, setlist, songs);
  }

  Future<void> _shareAsLinks(Setlist setlist) async {
    final songs = await _songsForSetlist(setlist);
    if (!mounted) return;
    await copySetlistLinks(context, setlist, songs);
  }
}
