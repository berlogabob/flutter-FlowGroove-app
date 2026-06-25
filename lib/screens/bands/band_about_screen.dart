import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/band.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/music_role_icon.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/role_picker_widget.dart';
import '../../widgets/user_avatar.dart';

class BandAboutScreen extends ConsumerStatefulWidget {

  const BandAboutScreen({required this.band, super.key});
  final Band band;

  @override
  ConsumerState<BandAboutScreen> createState() => _BandAboutScreenState();
}

class _BandAboutScreenState extends ConsumerState<BandAboutScreen> {
  late Band _band;
  bool _isEditing = false;
  late TextEditingController _descriptionController;
  late List<String> _tags;

  final List<String> _availableTags = [
    'rock',
    'pop',
    'jazz',
    'blues',
    'metal',
    'folk',
    'country',
    'reggae',
    'funk',
    'r&b',
    'cover band',
    'original',
    'tribute',
    'wedding',
    'bar',
    'live',
    'studio',
  ];

  @override
  void initState() {
    super.initState();
    _band = widget.band;
    _descriptionController = TextEditingController(
      text: _band.description ?? '',
    );
    _tags = List<String>.from(_band.tags);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String? get _userRole {
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user == null) return null;

    final member = _band.members.firstWhere(
      (m) => m.uid == user.uid,
      orElse: () => BandMember(uid: '', role: ''),
    );
    return member.role.isNotEmpty ? member.role : null;
  }

  bool get _canEdit {
    final role = _userRole;
    return role == BandMember.roleAdmin || role == BandMember.roleEditor;
  }

  @override
  Widget build(BuildContext context) {
    final canManageMembers = ref.watch(
      canManageBandMembersProvider(_band.id),
    );
    return Scaffold(
      appBar: CustomAppBar.build(
        context,
        title: 'About ${_band.name}',
        menuItems: [
          if (_canEdit) ...[
            PopupMenuItem<void>(
              onTap: _toggleEdit,
              child: Row(
                children: [
                  Icon(
                    _isEditing ? Icons.close : Icons.edit_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(_isEditing ? 'Cancel' : 'Edit'),
                ],
              ),
            ),
            PopupMenuItem<void>(
              onTap: _saveChanges,
              child: const Row(
                children: [
                  Icon(Icons.save_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Save'),
                ],
              ),
            ),
          ],
          PopupMenuItem<void>(
            onTap: () => _shareBand(context),
            child: const Row(
              children: [
                Icon(Icons.share_outlined, size: 20),
                SizedBox(width: 12),
                Text('Share Band'),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        children: [
          _buildBandInfo(),
          const SizedBox(height: 24),
          _buildDescriptionSection(),
          const SizedBox(height: 24),
          _buildTagsSection(),
          const SizedBox(height: 24),
          _buildMembersSection(canManageMembers),
        ],
      ),
    );
  }

  Widget _buildBandInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: MonoPulseColors.accentOrange,
                  child: Text(
                    _band.name.isNotEmpty ? _band.name[0].toUpperCase() : '?',
                    style: MonoPulseTypography.headlineLarge.copyWith(
                      color: MonoPulseColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _band.name,
                        style: MonoPulseTypography.headlineMedium.copyWith(
                          color: MonoPulseColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created ${_formatDate(_band.createdAt)}',
                        style: MonoPulseTypography.bodyMedium.copyWith(
                          color: MonoPulseColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.people_outline,
                  label: '${_band.members.length} members',
                  onTap: () => context.pushNamed(
                    'band-members',
                    pathParameters: {'id': _band.id},
                    extra: _band,
                  ),
                ),
                const SizedBox(width: 8),
                if (_band.inviteCode != null && _band.inviteCode!.isNotEmpty)
                  _buildInfoChip(
                    icon: Icons.qr_code,
                    label: 'Invite: ${_band.inviteCode}',
                    onTap: () => context.pushNamed(
                      'band-invite',
                      pathParameters: {'id': _band.id},
                      extra: _band,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrangeSubtle,
        borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: MonoPulseColors.accentOrange),
          const SizedBox(width: 6),
          Text(
            label,
            style: MonoPulseTypography.bodySmall.copyWith(
              color: MonoPulseColors.accentOrange,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 16, color: MonoPulseColors.accentOrange),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
      child: chip,
    );
  }

  Widget _buildDescriptionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Description',
                  style: MonoPulseTypography.headlineSmall.copyWith(
                    color: MonoPulseColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isEditing)
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter band description...',
                  border: OutlineInputBorder(),
                ),
              )
            else
              Text(
                _band.description?.isNotEmpty == true
                    ? _band.description!
                    : 'No description yet',
                style: TextStyle(
                  color: _band.description?.isNotEmpty == true
                      ? MonoPulseColors.textPrimary
                      : MonoPulseColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.label_outline, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Tags',
                  style: MonoPulseTypography.headlineSmall.copyWith(
                    color: MonoPulseColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isEditing) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((tag) {
                  final isSelected = _tags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _tags.add(tag);
                        } else {
                          _tags.remove(tag);
                        }
                      });
                    },
                    selectedColor: MonoPulseColors.accentOrangeSubtle,
                    checkmarkColor: MonoPulseColors.accentOrange,
                  );
                }).toList(),
              ),
            ] else ...[
              if (_tags.isEmpty)
                const Text(
                  'No tags yet',
                  style: TextStyle(color: MonoPulseColors.textSecondary),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          backgroundColor: MonoPulseColors.accentOrangeSubtle,
                          labelStyle: const TextStyle(
                            color: MonoPulseColors.accentOrange,
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection(bool canManageMembers) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Members',
                      style: MonoPulseTypography.headlineSmall.copyWith(
                        color: MonoPulseColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_band.members.length}',
                  style: const TextStyle(
                    color: MonoPulseColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_band.members.isEmpty)
              const Text(
                'No members found',
                style: TextStyle(color: MonoPulseColors.textSecondary),
              )
            else
              ...List.generate(_band.members.length, (index) {
                final member = _band.members[index];
                return _buildMemberTile(member, index, canManageMembers);
              }),
            if (canManageMembers) ...[
              const SizedBox(height: 4),
              Text(
                'You are an admin — tap a member to manage their role.',
                style: MonoPulseTypography.bodySmall.copyWith(
                  color: MonoPulseColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Number of admins currently in the band (used to prevent removing/demoting
  /// the last admin and locking everyone out of management).
  int get _adminCount =>
      _band.members.where((m) => m.role == BandMember.roleAdmin).length;

  Widget _buildMemberTile(
    BandMember member,
    int index,
    bool canManageMembers,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: canManageMembers ? () => _showMemberActions(index) : null,
      leading: UserAvatar(
        photoURL: null,
        displayName: member.displayName ?? member.email,
        radius: 20,
      ),
      title: Text(
        member.displayName ?? member.email ?? 'Unknown',
        style: const TextStyle(
          color: MonoPulseColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatRole(member.role),
            style: const TextStyle(color: MonoPulseColors.textSecondary),
          ),
          if (member.musicRoles.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: member.musicRoles.map((role) {
                final icon = MusicRoleIcon.getIcon(role);
                final displayName = MusicRoleIcon.getDisplayName(role);
                return Chip(
                  label: Text(
                    icon != null ? '$icon $displayName' : displayName,
                    style: const TextStyle(fontSize: 10),
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: MonoPulseColors.accentOrangeSubtle,
                  labelStyle: const TextStyle(
                    color: MonoPulseColors.accentOrange,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (member.role == BandMember.roleAdmin)
            const Icon(
              Icons.star,
              color: MonoPulseColors.accentOrange,
              size: 20,
            ),
          if (canManageMembers) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.more_vert,
              color: MonoPulseColors.textSecondary,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }

  /// Shows the admin management sheet for the member at [index].
  Future<void> _showMemberActions(int index) async {
    final member = _band.members[index];
    final name = member.displayName ?? member.email ?? 'this member';

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(MonoPulseSpacing.lg),
                child: Text(
                  name,
                  style: MonoPulseTypography.headlineSmall.copyWith(
                    color: MonoPulseColors.textPrimary,
                  ),
                ),
              ),
              for (final role in const [
                BandMember.roleAdmin,
                BandMember.roleEditor,
                BandMember.roleViewer,
              ])
                ListTile(
                  leading: Icon(
                    member.role == role
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: member.role == role
                        ? MonoPulseColors.accentOrange
                        : MonoPulseColors.textSecondary,
                  ),
                  title: Text('${_formatRole(role)} role'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _changeMemberRole(index, role);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.music_note_outlined),
                title: const Text('Edit music roles'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _editMemberMusicRoles(index);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_remove_outlined,
                  color: MonoPulseColors.error,
                ),
                title: const Text(
                  'Remove from band',
                  style: TextStyle(color: MonoPulseColors.error),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _removeMember(index);
                },
              ),
              const SizedBox(height: MonoPulseSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeMemberRole(int index, String newRole) async {
    final member = _band.members[index];
    if (member.role == newRole) return;

    // Don't allow demoting the last admin (would lock out member management).
    if (member.role == BandMember.roleAdmin &&
        newRole != BandMember.roleAdmin &&
        _adminCount <= 1) {
      _showMessage('A band must keep at least one admin.');
      return;
    }

    await _applyMemberChange(
      () => ref.read(bandFunctionServiceProvider).setMemberRole(
        bandId: _band.id,
        targetUid: member.uid,
        role: newRole,
      ),
      _band.copyWith(
        members: List<BandMember>.from(_band.members)
          ..[index] = member.copyWith(role: newRole),
      ),
      'Updated role to ${_formatRole(newRole)}',
    );
  }

  Future<void> _editMemberMusicRoles(int index) async {
    final member = _band.members[index];
    final result = await showRolePicker(
      context: context,
      currentRoles: member.musicRoles,
      title: 'Music roles',
    );
    if (result == null) return;

    final normalized = MusicRoleIcon.normalizeKeys(result);
    await _applyMemberChange(
      () => ref.read(bandFunctionServiceProvider).setMemberMusicRoles(
        bandId: _band.id,
        targetUid: member.uid,
        musicRoles: normalized,
      ),
      _band.copyWith(
        members: List<BandMember>.from(_band.members)
          ..[index] = member.copyWith(musicRoles: normalized),
      ),
      'Updated music roles',
    );
  }

  Future<void> _removeMember(int index) async {
    final member = _band.members[index];

    if (member.role == BandMember.roleAdmin && _adminCount <= 1) {
      _showMessage('You cannot remove the last admin.');
      return;
    }

    final name = member.displayName ?? member.email ?? 'this member';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove member'),
        content: Text('Remove $name from "${_band.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: MonoPulseColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _applyMemberChange(
      () => ref.read(bandFunctionServiceProvider).removeMember(
        bandId: _band.id,
        targetUid: member.uid,
      ),
      _band.copyWith(
        members: List<BandMember>.from(_band.members)..removeAt(index),
      ),
      'Removed $name',
    );
  }

  /// Runs an admin member mutation server-side (callable Cloud Function), then
  /// optimistically reflects [updatedBand] locally and refreshes the band list.
  ///
  /// The function rewrites the shared `bands/{id}` doc and its derived UID
  /// arrays atomically, and (for removals) cleans up the member's personal
  /// band reference — which client-side rules would not permit cross-user.
  Future<void> _applyMemberChange(
    Future<void> Function() action,
    Band updatedBand,
    String successMessage,
  ) async {
    try {
      await action();
      if (mounted) {
        setState(() => _band = updatedBand);
        ref.invalidate(bandsProvider);
        _showMessage(successMessage);
      }
    } catch (e) {
      if (mounted) _showMessage('Error: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _descriptionController.text = _band.description ?? '';
        _tags = List<String>.from(_band.tags);
      }
    });
  }

  Future<void> _saveChanges() async {
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user == null) return;

    final updatedBand = _band.copyWith(
      description: _descriptionController.text,
      tags: _tags,
    );

    try {
      await ref.read(firestoreProvider).saveBand(updatedBand, uid: user.uid);
      if (mounted) {
        setState(() {
          _band = updatedBand;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Band updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating band: $e')));
      }
    }
  }

  Future<void> _shareBand(BuildContext context) async {
    final inviteCode = _band.inviteCode;
    if (inviteCode == null || inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invite code available for this band')),
      );
      return;
    }

    const String domain = 'flowgroove.app';

    final shareText =
        'Join my band "${_band.name}" on FlowGroove!\n\n'
        'Use invite code: $inviteCode\n\n'
        'Or click the link: https://$domain/join?code=$inviteCode';

    await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: 'Join my band "${_band.name}" on FlowGroove',
      ),
    );
  }

  String _formatRole(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'editor':
        return 'Editor';
      case 'viewer':
      default:
        return 'Viewer';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
