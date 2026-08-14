import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/band.dart';
import '../../models/user.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/avatar_function_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/responsive_breakpoints.dart';
import '../../utils/snackbar.dart';
import '../../widgets/app_menu_sheet.dart';
import '../../widgets/dashboard_grid.dart';
import '../../widgets/quick_action_button.dart';
import '../../widgets/standard_screen_scaffold.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/user_avatar.dart';
import '../setlists/create_setlist_screen.dart';

/// The Band Screen - displays band dashboard similar to personal page, but
/// clearly labeled as the band's data (not the signed-in user's).
///
/// Features (per Issue #13, #21, and #22):
/// - Compact band header: avatar, band name, member count (no personal
///   "Hello, `<band>`!" greeting copy - that belongs to the Home screen)
/// - 3-dots menu with: Edit name, Edit description, Add song, Add setlist, Edit tags, Edit members
/// - Dashboard with band-specific statistics (songs, setlists, members)
/// - Quick actions: Add Song (to band), Add Setlist (to band), Band Bank, Add Member, Rehearsals
/// - Collapsible/expandable widgets with autosave (via BandAboutScreen for editing)
class TheBandScreen extends ConsumerStatefulWidget {
  const TheBandScreen({required this.band, super.key});
  final Band band;

  @override
  ConsumerState<TheBandScreen> createState() => _TheBandScreenState();
}

class _TheBandScreenState extends ConsumerState<TheBandScreen> {
  late Band _band;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _band = widget.band;
    _nameController = TextEditingController(text: widget.band.name);
    _descriptionController = TextEditingController(
      text: widget.band.description ?? '',
    );
    // screen_view comes from the router's FirebaseAnalyticsObserver (main.dart).
    // HEART "adoption" fallback: cheaply detecting "first open after join"
    // isn't available here, so this fires on every open — see report.
    AnalyticsService.logBandOpened(bandId: widget.band.id);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Permission gates live in canEditBandProvider/isBandAdminProvider (the
  // adminUids/editorUids arrays Firestore rules read), watched in build —
  // not the widget.band.members navigation snapshot.

  /// The band as currently stored (from the live bands stream), falling back to
  /// the optimistic local copy then the passed-in band. Reading from the stream
  /// keeps the avatar (and other live fields) correct after tab switches, since
  /// the passed-in widget.band is only a snapshot from navigation time.
  Band _liveBand() {
    final bands = ref.watch(bandsProvider).asData?.value;
    if (bands != null) {
      for (final b in bands) {
        if (b.id == widget.band.id) return b;
      }
    }
    return _band;
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(canEditBandProvider(widget.band.id));
    final isAdmin = ref.watch(isBandAdminProvider(widget.band.id));
    return StandardScreenScaffold(
      title: widget.band.name,
      body: _buildBandDashboard(canEdit, isAdmin),
      menuItems: _buildMenuItems(canEdit, isAdmin),
    );
  }

  /// Build items for the bottom-bar Menu sheet. Rows with a null onTap render
  /// disabled (editor-gated actions for viewers); actions Firestore rules
  /// reserve for band admins (band-doc writes, member management, avatar) are
  /// dropped entirely for non-admins — showing them would only produce
  /// permission-denied errors.
  List<AppMenuItem> _buildMenuItems(bool canEdit, bool isAdmin) {
    return [
      if (isAdmin)
        AppMenuItem(
          icon: Icons.edit,
          label: 'Edit Band Name',
          onTap: _showEditNameDialog,
        ),
      if (isAdmin)
        AppMenuItem(
          icon: Icons.description,
          label: 'Edit Description',
          onTap: _showEditDescriptionDialog,
        ),
      AppMenuItem(
        icon: Icons.add,
        label: 'Add Song',
        // Band-song create needs editor/admin per rules.
        onTap: canEdit ? _handleAddSong : null,
      ),
      AppMenuItem(
        icon: Icons.playlist_add,
        label: 'Add Setlist',
        onTap: canEdit ? _handleAddSetlist : null,
      ),
      if (isAdmin)
        AppMenuItem(
          icon: Icons.label_outline,
          label: 'Edit Tags',
          onTap: _handleEditTags,
        ),
      if (isAdmin)
        AppMenuItem(
          icon: Icons.people,
          label: 'Edit Members',
          onTap: _handleEditMembers,
        ),
      if (isAdmin)
        AppMenuItem(
          icon: Icons.image,
          label: 'Change Band Avatar',
          onTap: _handleChangeBandAvatar,
        ),
      // Remove Band Avatar (admin only, shown only when avatar exists)
      if (_liveBand().photoURL != null && isAdmin)
        AppMenuItem(
          icon: Icons.delete_outline,
          label: 'Remove Band Avatar',
          onTap: _handleRemoveBandAvatar,
        ),
    ];
  }

  Widget _buildBandDashboard(bool canEdit, bool isAdmin) {
    final userAsync = ref.watch(appUserProvider);
    final songCountAsync = ref.watch(bandSongsProvider(widget.band.id));
    final setlistCount = ref
        .watch(bandSetlistCountProvider(widget.band.id))
        .toString();

    return DashboardGrid(
      greetingCard: _buildBandHeader(),
      statisticsTitle: 'Band library',
      statistics: _buildStatistics(userAsync, songCountAsync, setlistCount),
      quickActions: _buildQuickActions(canEdit, isAdmin),
      tools: const [],
    );
  }

  /// Build statistics cards for band dashboard
  List<StatCard> _buildStatistics(
    AsyncValue<AppUser?> userAsync,
    AsyncValue<List<dynamic>> songCountAsync,
    String setlistCount,
  ) {
    final songCount = songCountAsync.value?.length.toString() ?? '0';
    final memberCount = widget.band.members.length.toString();

    return [
      StatCard(
        icon: Icons.music_note,
        label: 'Songs',
        value: songCount,
        color: MonoPulseColors.accentOrange,
        onTap: () => context.pushNamed(
          'band-songs',
          pathParameters: {'id': widget.band.id},
          extra: widget.band,
        ),
      ),
      StatCard(
        icon: Icons.queue_music,
        label: 'Setlists',
        value: setlistCount,
        color: context.mp.textSecondary,
        onTap: () => context.pushNamed(
          'band-setlists',
          pathParameters: {'id': widget.band.id},
          extra: widget.band,
        ),
      ),
      StatCard(
        icon: Icons.people,
        label: 'Members',
        value: memberCount,
        color: context.mp.textSecondary,
        onTap: _handleEditMembers,
      ),
    ];
  }

  /// Build quick action buttons for band dashboard. Band-scoped only - Tuner
  /// and Metronome are personal tools that live on the Home screen, not here.
  /// Rehearsals is band-scoped, so it lives here instead of a single-item
  /// Tools section.
  List<QuickActionButton> _buildQuickActions(bool canEdit, bool isAdmin) {
    return [
      if (canEdit)
        QuickActionButton(
          icon: Icons.add,
          label: 'Song',
          onTap: _handleAddSong,
        ),
      // Member management is admin-only per Cloud Functions/rules.
      if (isAdmin)
        QuickActionButton(
          icon: Icons.person_add,
          label: 'Member',
          onTap: _handleAddMember,
        ),
      if (canEdit)
        QuickActionButton(
          icon: Icons.playlist_add,
          label: 'Setlist',
          onTap: _handleAddSetlist,
        ),
      QuickActionButton(
        icon: Icons.library_music,
        label: 'Band songs',
        onTap: _handleBandBank,
      ),
      QuickActionButton(
        icon: Icons.event,
        label: 'Rehearsals',
        onTap: () => context.pushNamed(
          'band-rehearsals',
          pathParameters: {'id': widget.band.id},
          extra: widget.band,
        ),
      ),
    ];
  }

  /// Compact band header: avatar, band name, member count on one row. No
  /// personal-style greeting copy ("Hello, `<band>`! Ready to rock?") - this is
  /// the band's data, not the signed-in user's, and the greeting made that
  /// ambiguous (P1-4).
  Widget _buildBandHeader() {
    final band = _liveBand();
    final breakpoint = context.breakpoint;
    final avatarRadius = ResponsiveSizes.avatarRadius(breakpoint);
    final memberCount = band.members.length;

    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrange10,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: context.mp.borderSubtle),
      ),
      child: Row(
        children: [
          UserAvatar(
            photoURL: band.photoURL,
            displayName: band.name,
            radius: avatarRadius,
          ),
          const SizedBox(width: MonoPulseSpacing.lg),
          Expanded(
            child: Text(
              band.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.mp.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: MonoPulseSpacing.md),
          Text(
            memberCount == 1 ? '1 member' : '$memberCount members',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.mp.textTertiary),
          ),
        ],
      ),
    );
  }

  // ==================== Menu Actions ====================
  // (The app menu sheet already closes itself and defers each action to the
  // next frame, so the old _runAfterMenuCloses wrapper is gone.)

  /// Show dialog to edit band name
  Future<void> _showEditNameDialog() async {
    _nameController.text = widget.band.name;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Band Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Band Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSaving ? null : _saveBandName,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Save band name
  Future<void> _saveBandName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == widget.band.name) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.value;
      if (user == null) return;

      final updatedBand = widget.band.copyWith(name: newName);
      final bandRepo = ref.read(firestoreProvider);
      await bandRepo.saveBand(updatedBand, uid: user.uid);

      if (mounted) {
        Navigator.pop(context);
        showAppSnackBar(context, 'Band name updated successfully');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Error updating band name: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Show dialog to edit description
  Future<void> _showEditDescriptionDialog() async {
    _descriptionController.text = widget.band.description ?? '';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Description'),
        content: TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
            hintText: 'Enter band description...',
          ),
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSaving ? null : _saveDescription,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Save description
  Future<void> _saveDescription() async {
    final newDescription = _descriptionController.text.trim();
    if (newDescription == widget.band.description) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.value;
      if (user == null) return;

      final updatedBand = widget.band.copyWith(
        description: newDescription.isEmpty ? null : newDescription,
      );
      final bandRepo = ref.read(firestoreProvider);
      await bandRepo.saveBand(updatedBand, uid: user.uid);

      if (mounted) {
        Navigator.pop(context);
        showAppSnackBar(context, 'Description updated successfully');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Error updating description: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Handle add song - navigate to add song screen with bandId.
  /// Pushed, not go'd: a `go` switches the shell to the Songs branch and the
  /// save pops the user out onto the personal library instead of this band.
  void _handleAddSong() {
    context.pushNamed('add-song', queryParameters: {'bandId': widget.band.id});
  }

  /// Handle add setlist - navigate to create setlist screen (pushed, so saving
  /// returns to the band; see _handleAddSong).
  void _handleAddSetlist() {
    context.pushNamed(
      'create-setlist',
      queryParameters: {
        'bandId': widget.band.id,
        'scope': SetlistStorageScope.band.name,
      },
    );
  }

  /// Handle edit tags - navigate to band about screen
  void _handleEditTags() {
    context.pushNamed(
      'band-about',
      pathParameters: {'id': widget.band.id},
      extra: widget.band,
    );
  }

  /// Handle edit members - navigate to band about screen (member management
  /// lives there: role changes, remove, etc.). The read-only band-members
  /// screen is reached via the members chip on the About screen.
  void _handleEditMembers() {
    context.pushNamed(
      'band-about',
      pathParameters: {'id': widget.band.id},
      extra: widget.band,
    );
  }

  /// Handle add member - go straight to the invite/share screen
  void _handleAddMember() {
    context.pushNamed(
      'band-invite',
      pathParameters: {'id': widget.band.id},
      extra: widget.band,
    );
  }

  /// Handle band bank - navigate to band songs screen
  void _handleBandBank() {
    context.pushNamed(
      'band-songs',
      pathParameters: {'id': widget.band.id},
      extra: widget.band,
    );
  }

  Future<void> _handleChangeBandAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    try {
      final url = await AvatarFunctionService().setBandAvatar(
        File(picked.path),
        _band.id,
      );
      if (!mounted) return;
      setState(() => _band = _band.copyWith(photoURL: url));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Avatar upload failed: $e')),
      );
    }
  }

  Future<void> _handleRemoveBandAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AvatarFunctionService().removeBandAvatar(_band.id);
      if (!mounted) return;
      setState(() => _band = _band.copyWith(photoURL: null));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Avatar removal failed: $e')),
      );
    }
  }
}
