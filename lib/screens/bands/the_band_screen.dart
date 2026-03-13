import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/band.dart';
import '../../models/user.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/analytics_debug.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/dashboard_grid.dart';

/// The Band Screen - displays band dashboard similar to personal page.
///
/// Features (per Issue #13, #21, and #22):
/// - Band name header (replaces "Hello, username")
/// - "Ready to rock" section showing band description
/// - 3-dots menu with: Edit name, Edit description, Add song, Add setlist, Edit tags, Edit members
/// - Dashboard with band-specific statistics (songs, setlists, members)
/// - Quick actions: Add Song (to band), Add Setlist (to band), Band Bank, Add Member
/// - Collapsible/expandable widgets with autosave (via BandAboutScreen for editing)
class TheBandScreen extends ConsumerStatefulWidget {
  const TheBandScreen({required this.band, super.key});

  final Band band;

  @override
  ConsumerState<TheBandScreen> createState() => _TheBandScreenState();
}

class _TheBandScreenState extends ConsumerState<TheBandScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.band.name);
    _descriptionController = TextEditingController(text: widget.band.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Check if user can edit the band (admin or editor only)
  bool get _canEdit {
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user == null) return false;

    final member = widget.band.members.firstWhere(
      (m) => m.uid == user.uid,
      orElse: () => BandMember(uid: '', role: ''),
    );
    return member.role == BandMember.roleAdmin ||
        member.role == BandMember.roleEditor;
  }

  @override
  Widget build(BuildContext context) {
    // Log screen view for analytics
    AnalyticsDebug.logScreenView(
      screenName: 'TheBandScreen',
      screenClass: 'TheBandScreen',
    );

    FirebaseAnalytics.instance.logScreenView(
      screenName: 'TheBandScreen',
      screenClass: 'TheBandScreen',
    );

    return Scaffold(
      backgroundColor: MonoPulseColors.black,
      appBar: CustomAppBar.build(
        context,
        title: widget.band.name,
        onBack: () => context.pop(),
        menuItems: _buildMenuItems(),
      ),
      body: _buildBandDashboard(),
    );
  }

  /// Build menu items for 3-dots menu
  List<PopupMenuEntry<void>> _buildMenuItems() {
    return [
      // Edit Band Name
      PopupMenuItem<void>(
        enabled: _canEdit,
        onTap: _canEdit ? _showEditNameDialog : null,
        child: Row(
          children: [
            const Icon(Icons.edit, size: 20),
            const SizedBox(width: 12),
            Text(
              'Edit Band Name',
              style: TextStyle(
                color: _canEdit
                    ? MonoPulseColors.textPrimary
                    : MonoPulseColors.textTertiary,
              ),
            ),
          ],
        ),
      ),

      // Edit Description
      PopupMenuItem<void>(
        enabled: _canEdit,
        onTap: _canEdit ? _showEditDescriptionDialog : null,
        child: Row(
          children: [
            const Icon(Icons.description, size: 20),
            const SizedBox(width: 12),
            Text(
              'Edit Description',
              style: TextStyle(
                color: _canEdit
                    ? MonoPulseColors.textPrimary
                    : MonoPulseColors.textTertiary,
              ),
            ),
          ],
        ),
      ),

      const PopupMenuDivider(),

      // Add Song
      PopupMenuItem<void>(
        onTap: _handleAddSong,
        child: const Row(
          children: [
            Icon(Icons.add, size: 20),
            SizedBox(width: 12),
            Text('Add Song'),
          ],
        ),
      ),

      // Add Setlist
      PopupMenuItem<void>(
        onTap: _handleAddSetlist,
        child: const Row(
          children: [
            Icon(Icons.playlist_add, size: 20),
            SizedBox(width: 12),
            Text('Add Setlist'),
          ],
        ),
      ),

      const PopupMenuDivider(),

      // Edit Tags
      PopupMenuItem<void>(
        enabled: _canEdit,
        onTap: _canEdit ? _handleEditTags : null,
        child: Row(
          children: [
            const Icon(Icons.label_outline, size: 20),
            const SizedBox(width: 12),
            Text(
              'Edit Tags',
              style: TextStyle(
                color: _canEdit
                    ? MonoPulseColors.textPrimary
                    : MonoPulseColors.textTertiary,
              ),
            ),
          ],
        ),
      ),

      // Edit Members
      PopupMenuItem<void>(
        enabled: _canEdit,
        onTap: _canEdit ? _handleEditMembers : null,
        child: Row(
          children: [
            const Icon(Icons.people, size: 20),
            const SizedBox(width: 12),
            Text(
              'Edit Members',
              style: TextStyle(
                color: _canEdit
                    ? MonoPulseColors.textPrimary
                    : MonoPulseColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildBandDashboard() {
    final userAsync = ref.watch(appUserProvider);
    final songCountAsync = ref.watch(bandSongsProvider(widget.band.id));
    // TODO: Add band setlist count provider when implemented
    const setlistCount = '0'; // Placeholder

    return SingleChildScrollView(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Band greeting card (replaces user greeting)
          _buildBandGreetingCard(),
          const SizedBox(height: MonoPulseSpacing.xxxl),

          // Dashboard with statistics and quick actions
          DashboardGrid(
            statistics: _buildStatistics(
              userAsync,
              songCountAsync,
              setlistCount,
            ),
            quickActions: _buildQuickActions(),
            tools: _buildTools(),
          ),
        ],
      ),
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
        onTap: () => context.goNamed(
          'band-songs',
          pathParameters: {'id': widget.band.id},
          extra: widget.band,
        ),
      ),
      StatCard(
        icon: Icons.queue_music,
        label: 'Setlists',
        value: setlistCount,
        color: MonoPulseColors.textSecondary,
        onTap: () {
          // TODO: Navigate to band setlists when implemented
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Band setlists coming soon!')),
          );
        },
      ),
      StatCard(
        icon: Icons.people,
        label: 'Members',
        value: memberCount,
        color: MonoPulseColors.textSecondary,
        onTap: _handleEditMembers,
      ),
    ];
  }

  /// Build quick action buttons for band dashboard
  List<QuickActionButton> _buildQuickActions() {
    return [
      QuickActionButton(
        icon: Icons.add,
        label: 'Song',
        onTap: _handleAddSong,
      ),
      QuickActionButton(
        icon: Icons.person_add,
        label: 'Member',
        onTap: _handleAddMember,
      ),
      QuickActionButton(
        icon: Icons.playlist_add,
        label: 'Setlist',
        onTap: _handleAddSetlist,
      ),
      QuickActionButton(
        icon: Icons.library_music,
        label: 'Bank',
        onTap: _handleBandBank,
      ),
    ];
  }

  /// Build tool buttons for band dashboard
  List<ToolButton> _buildTools() {
    return [
      ToolButton(
        icon: Icons.tune,
        label: 'Tuner',
        onTap: () => context.goNamed('tuner'),
      ),
      ToolButton(
        icon: Icons.speed,
        label: 'Metronome',
        onTap: () => context.goNamed('metronome'),
      ),
    ];
  }

  /// Band greeting card - similar to GreetingCard but for bands
  Widget _buildBandGreetingCard() {
    final description = widget.band.description;

    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrangeSubtle,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Band name
          Text(
            widget.band.name,
            style: MonoPulseTypography.headlineMedium.copyWith(
              color: MonoPulseColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.md),

          // Description / "Ready to rock" section
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: MonoPulseColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: MonoPulseSpacing.sm),
              Expanded(
                child: Text(
                  description ?? 'Ready to rock?',
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Menu Actions ====================

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Band name updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating band name: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Description updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating description: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Handle add song - navigate to add song screen with bandId
  void _handleAddSong() {
    context.goNamed(
      'add-song',
      queryParameters: {'bandId': widget.band.id},
    );
  }

  /// Handle add setlist - navigate to create setlist screen
  void _handleAddSetlist() {
    context.goNamed('create-setlist');
  }

  /// Handle edit tags - navigate to band about screen
  void _handleEditTags() {
    context.goNamed(
      'band-about',
      pathParameters: {'id': widget.band.id},
      extra: widget.band,
    );
  }

  /// Handle edit members - navigate to band about screen
  void _handleEditMembers() {
    context.goNamed(
      'band-about',
      pathParameters: {'id': widget.band.id},
      extra: widget.band,
    );
  }

  /// Handle add member - navigate to band about screen for member management
  void _handleAddMember() {
    context.goNamed(
      'band-about',
      pathParameters: {'id': widget.band.id},
      extra: widget.band,
    );
  }

  /// Handle band bank - navigate to band songs screen
  void _handleBandBank() {
    context.goNamed(
      'band-songs',
      pathParameters: {'id': widget.band.id},
      extra: widget.band,
    );
  }
}
