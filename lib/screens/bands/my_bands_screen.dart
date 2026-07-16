import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/api_error.dart';
import '../../models/band.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/error_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_banner.dart' show ErrorBanner, ErrorBannerStyle;
import '../../widgets/fab_variants.dart';
import '../../widgets/invite_code_field.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/share_sheet.dart';
import '../../widgets/standard_screen_scaffold.dart';
import '../../widgets/unified_item/adapters/band_item_adapter.dart';
import '../../widgets/unified_item/unified_filter_sort_widget.dart';
import '../../widgets/unified_item/unified_item_list.dart';
import '../../widgets/unified_item/unified_item_model.dart';

/// Screen for displaying the user's bands with search, filter, sort,
/// swipe-to-delete, and drag-and-drop reordering.
class MyBandsScreen extends ConsumerStatefulWidget {
  const MyBandsScreen({super.key});

  @override
  ConsumerState<MyBandsScreen> createState() => _MyBandsScreenState();
}

class _MyBandsScreenState extends ConsumerState<MyBandsScreen> {
  String _searchQuery = '';
  SortOption _sortOption = SortOption.manual;
  ApiError? _currentError;

  // Store manual order as list (same as songs_list_screen.dart)
  List<Band>? _manualOrder;

  /// Filter and sort bands based on search query and sort option.
  /// Manual order reconciled with the live band list: saved order first (using
  /// the live band objects), newly created bands appended, and left/deleted
  /// bands dropped. Without this the saved snapshot drifts from the live stream
  /// — a created band wouldn't appear and a left band wouldn't disappear, even
  /// though the home count (which reads the live stream) already changed.
  List<Band> _orderedBands(List<Band> bands) {
    if (_manualOrder == null) return List<Band>.from(bands);
    final byId = {for (final b in bands) b.id: b};
    final ordered = <Band>[];
    for (final saved in _manualOrder!) {
      final live = byId.remove(saved.id);
      if (live != null) ordered.add(live);
    }
    ordered.addAll(byId.values); // bands created since the order was saved
    return ordered;
  }

  List<BandItemAdapter> _filterAndSortBands(List<Band> bands) {
    // Apply manual order if in manual sort mode
    List<Band> bandsToUse = bands;
    if (_sortOption == SortOption.manual && _manualOrder != null) {
      bandsToUse = _orderedBands(bands);
    }

    // Convert bands to adapters
    var adapters = bandsToUse.map(BandItemAdapter.new).toList();

    // Apply search filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      adapters = adapters.where((adapter) {
        return adapter.title.toLowerCase().contains(query) ||
            (adapter.subtitle?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply sorting (only for non-manual modes)
    if (_sortOption != SortOption.manual) {
      switch (_sortOption) {
        case SortOption.alphabetical:
          adapters.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
        case SortOption.dateAdded:
          adapters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        case SortOption.dateModified:
          // Band model doesn't have updatedAt, fallback to createdAt
          adapters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        case SortOption.manual:
          break; // Already handled above
      }
    }

    return adapters;
  }

  /// Clears the current error.
  void _clearError() {
    setState(() {
      _currentError = null;
    });
  }

  /// Handles an error from a stream.
  void _handleStreamError(Object error, StackTrace stackTrace) {
    final apiError = ApiError.fromException(error, stackTrace: stackTrace);
    setState(() {
      _currentError = apiError;
    });
    ref.read(errorStateProvider.notifier).handleError(apiError);
  }

  /// Handle band reordering (manual sort mode).
  void _handleReorder(int oldIndex, int newIndex) {
    // Displayed indices only map onto _manualOrder in manual mode with no
    // active search filter; otherwise a reorder would corrupt the saved order.
    if (_sortOption != SortOption.manual || _searchQuery.trim().isNotEmpty) {
      return;
    }
    // Update manual order when reordering (same as songs_list_screen.dart)
    if (_manualOrder != null &&
        oldIndex >= 0 &&
        newIndex >= 0 &&
        oldIndex < _manualOrder!.length &&
        newIndex < _manualOrder!.length) {
      // Create a copy to avoid modifying the original list directly
      final newOrder = List<Band>.from(_manualOrder!);

      // Move item from oldIndex to newIndex
      final item = newOrder.removeAt(oldIndex);
      newOrder.insert(newIndex, item);

      setState(() {
        _manualOrder = newOrder;
      });
    }
  }

  /// Handle band deletion with confirmation.
  Future<bool> _handleDelete(int index) async {
    final bands = ref.read(bandsProvider).value;
    if (bands == null) return false;
    // Resolve via the same filtered/sorted list the UI shows, not the raw list.
    final adapters = _filterAndSortBands(bands);
    if (index >= adapters.length) return false;

    final band = adapters[index].band;
    final confirmed = await ConfirmationDialog.showDeleteDialog(
      context,
      title: 'Leave Band',
      message: 'Are you sure you want to leave this band?',
      confirmLabel: 'Leave',
    );

    if (confirmed) {
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.value;
      if (user != null) {
        try {
          // Leaving is server-authoritative: updateBandMember rewrites the
          // band's memberUids and deletes the personal band ref atomically, so
          // the bands stream (which watches global memberUids) updates the list
          // and home count in lockstep. A direct client write to the global
          // band doc is admin-gated and would be denied for ordinary members.
          await ref
              .read(bandFunctionServiceProvider)
              .removeMember(bandId: band.id, targetUid: user.uid);

          if (mounted) {
            showAppSnackBar(context, 'Successfully left the band');
          }
          return true;
        } on ApiError catch (e) {
          _handleStreamError(e, StackTrace.current);
          if (mounted) {
            showAppSnackBar(context, e.message);
          }
          return false; // Don't dismiss on error
        } catch (e, stackTrace) {
          final error = ApiError.fromException(e, stackTrace: stackTrace);
          _handleStreamError(error, stackTrace);
          if (mounted) {
            showAppSnackBar(context, error.message);
          }
          return false; // Don't dismiss on error
        }
      }
    }
    return confirmed;
  }

  /// Handle band edit - navigate to edit screen.
  void _handleEdit(int index) {
    final bands = ref.read(bandsProvider).value;
    if (bands == null) return;
    final adapters = _filterAndSortBands(bands);
    if (index >= adapters.length) return;

    final band = adapters[index].band;
    context.pushNamed(
      'edit-band',
      pathParameters: {'id': band.id},
      extra: band,
    );
  }

  /// Handle band tap - navigate to the band screen.
  void _handleTap(int index) {
    final bands = ref.read(bandsProvider).value;
    if (bands == null) return;
    final adapters = _filterAndSortBands(bands);
    if (index >= adapters.length) return;

    final band = adapters[index].band;
    context.goNamed('the-band', pathParameters: {'id': band.id}, extra: band);
  }

  @override
  Widget build(BuildContext context) {
    final bandsAsync = ref.watch(bandsProvider);

    return StandardScreenScaffold(
      title: 'My Bands',
      showBackButton: false, // Hide back button for main tabs
      menuItems: [
        PopupMenuItem<void>(
          child: const Text('Create Band'),
          onTap: () => context.goNamed('create-band'),
        ),
        PopupMenuItem<void>(
          child: const Text('Join band'),
          onTap: () => context.pushNamed('join-band'),
        ),
      ],
      floatingActionButton: SingleFab(
        icon: Icons.add,
        tooltip: 'Create band',
        heroTag: 'bands_fab',
        onPressed: () => context.goNamed('create-band'),
      ),
      body: _buildBody(bandsAsync),
    );
  }

  Widget _buildBody(AsyncValue<List<Band>> bandsAsync) {
    return bandsAsync.when(
      data: (bands) {
        // Clear error when data loads successfully
        if (_currentError != null) {
          _clearError();
        }
        return _buildContent(context, ref, bands);
      },
      loading: () => const LoadingIndicator(),
      error: (e, stack) {
        _handleStreamError(e, stack);
        return _buildErrorState();
      },
    );
  }

  Widget _buildErrorState() {
    if (_currentError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
          child: ErrorBanner(
            message: _currentError?.message ?? 'An unexpected error occurred',
            onRetry: () {
              _clearError();
              ref.invalidate(bandsProvider);
            },
            showRetry: _currentError!.isNetwork,
            style: ErrorBannerStyle.card,
          ),
        ),
      );
    }
    return const Center(child: Text('An error occurred'));
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<Band> bands) {
    final filteredBands = _filterAndSortBands(bands);

    // Keep the manual-order hint aligned with the live set (first build, plus
    // whenever a band was created or left) so reorder indices match what's
    // shown. Reconcile after the frame to avoid setState during build.
    if (_sortOption == SortOption.manual &&
        (_manualOrder == null || _manualOrder!.length != bands.length)) {
      final reconciled = _orderedBands(bands);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _manualOrder = reconciled);
      });
    }

    return Column(
      children: [
        // Inline error banner if there's an error but we have cached data
        if (_currentError != null && filteredBands.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            child: ErrorBanner(
              message: _currentError?.message ?? 'An unexpected error occurred',
              onRetry: () {
                _clearError();
                ref.invalidate(bandsProvider);
              },
              showRetry: _currentError!.isNetwork,
              style: ErrorBannerStyle.inline,
            ),
          ),
        ],
        // Unified filter/sort widget
        Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: UnifiedFilterSortWidget(
            currentSort: _sortOption,
            hintText: 'Search bands...',
            onSortChanged: (option) {
              if (option != null) {
                setState(() => _sortOption = option);

                // Reset manual order when switching away from manual sort
                if (option != SortOption.manual && _manualOrder != null) {
                  setState(() {
                    _manualOrder = null;
                  });
                }
              }
            },
            filterText: _searchQuery.isEmpty ? null : _searchQuery,
            onFilterChanged: (value) =>
                setState(() => _searchQuery = value ?? ''),
          ),
        ),
        Expanded(
          child: filteredBands.isEmpty
              ? _buildEmptyState(bands.isEmpty)
              : _buildBandList(filteredBands),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    if (isEmpty) {
      return EmptyState.bands(
        onCreate: () => context.goNamed('create-band'),
        onJoin: () => context.pushNamed('join-band'),
      );
    }
    return EmptyState.search(query: _searchQuery);
  }

  Widget _buildBandList(List<BandItemAdapter> adapters) {
    return UnifiedItemList<BandItemAdapter>(
      items: adapters,
      padding: const EdgeInsets.only(bottom: 96),
      enableReorder: _sortOption == SortOption.manual,
      onReorder: _sortOption == SortOption.manual ? _handleReorder : null,
      onDelete: _handleDelete,
      onEdit: _handleEdit,
      onTap: _handleTap,
      additionalActionsBuilder: (index) {
        if (index >= adapters.length) return [];
        final adapter = adapters[index];
        return [
          // View Band Songs button - using inline action
          _ViewSongsAction(band: adapter.band, onNavigate: _handleViewSongs),
        ];
      },
    );
  }

  /// Handle view band songs
  void _handleViewSongs(Band band) {
    context.pushNamed(
      'band-songs',
      pathParameters: {'id': band.id},
      extra: band,
    );
  }
}

class _InviteMemberDialog extends ConsumerStatefulWidget {

  const _InviteMemberDialog({required this.band, required this.currentUserId});
  final Band band;
  final String currentUserId;

  @override
  ConsumerState<_InviteMemberDialog> createState() =>
      _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<_InviteMemberDialog> {
  late String _inviteCode;
  bool _isRegenerating = false;
  ApiError? _currentError;

  @override
  void initState() {
    super.initState();
    _inviteCode = widget.band.inviteCode ?? '';
    if (_inviteCode.isEmpty) {
      _generateNewCode();
    }
  }

  void _handleError(ApiError error) {
    setState(() {
      _currentError = error;
    });
    ref.read(errorStateProvider.notifier).handleError(error);
  }

  Future<void> _generateNewCode() async {
    setState(() {
      _isRegenerating = true;
      _currentError = null;
    });

    try {
      final newCode = Band.generateUniqueInviteCode();

      final updatedBand = widget.band.copyWith(inviteCode: newCode);

      final bandRepo = ref.read(bandRepositoryProvider);

      // Save to global collection
      await bandRepo.saveBandToGlobal(updatedBand);

      // Save to user's collection
      await bandRepo.saveBand(updatedBand, uid: widget.currentUserId);

      setState(() {
        _inviteCode = newCode;
        _isRegenerating = false;
      });
    } on ApiError catch (e) {
      _handleError(e);
      setState(() {
        _isRegenerating = false;
      });
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      _handleError(error);
      setState(() {
        _isRegenerating = false;
      });
    }
  }

  Future<void> _shareInvite() async {
    const String domain = 'flowgroove.app';

    // Path-based join link: opens the installed app directly via Android App
    // Links (intent-filter pathPrefix /join + /.well-known/assetlinks.json),
    // and in a browser the /join/ page redirects into the web app. A hash-
    // fragment URL can't be used here because Android App Links never receive
    // the URL fragment.
    final joinLink = 'https://$domain/join/?code=$_inviteCode';

    final message =
        '🎸 Join my band "${widget.band.name}" on FlowGroove!\n\n'
        'Use code: $_inviteCode\n'
        'Or click the link to join: $joinLink\n\n'
        'Download FlowGroove: https://$domain';

    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showShareOptions(message);
    }
  }

  void _showShareOptions(String message) {
    showShareSheet(
      context,
      message,
      subject: 'Join my band "${widget.band.name}"',
    );
  }

  Future<void> _copyToClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: _inviteCode));
      if (mounted) {
        showAppSnackBar(context, 'Code copied!');
      }
    } on ApiError catch (e) {
      _handleError(e);
      if (mounted) {
        showAppSnackBar(context, e.message);
      }
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      _handleError(error);
      if (mounted) {
        showAppSnackBar(context, error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Invite to ${widget.band.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error banner
          if (_currentError != null) ...[
            Container(
              padding: const EdgeInsets.all(MonoPulseSpacing.md),
              decoration: BoxDecoration(
                color: MonoPulseColors.error10,
                borderRadius: BorderRadius.circular(MonoPulseRadius.small),
                border: Border.all(color: MonoPulseColors.error20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: MonoPulseColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentError?.message ?? 'An unexpected error occurred',
                      style: MonoPulseTypography.bodySmall.copyWith(
                        color: MonoPulseColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text('Share this code with band members:'),
          const SizedBox(height: 16),
          InviteCodeField(
            code: _isRegenerating ? '' : _inviteCode,
            placeholder: 'Generating…',
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _isRegenerating ? null : _generateNewCode,
                icon: const Icon(Icons.refresh),
                label: const Text('New Code'),
              ),
              TextButton.icon(
                onPressed: _isRegenerating ? null : _copyToClipboard,
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              TextButton.icon(
                onPressed: _isRegenerating ? null : _shareInvite,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Action class for View Songs button
class _ViewSongsAction implements UnifiedItemAction {

  _ViewSongsAction({required this.band, required this.onNavigate});
  final Band band;
  final void Function(Band) onNavigate;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.music_note, size: 20),
      onPressed: () => onNavigate(band),
      tooltip: 'View Songs',
    );
  }
}
