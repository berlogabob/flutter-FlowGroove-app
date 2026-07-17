import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/band.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/member_label.dart';
import '../../utils/music_role_icon.dart';
import '../../utils/snackbar.dart';
import '../../widgets/app_menu_sheet.dart';
import '../../widgets/menu_items_scope.dart';
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
  void didUpdateWidget(BandAboutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // BandRouteResolver re-delivers the live band on every stream emission;
    // adopt it so renames/member changes made elsewhere show up (#91). While
    // editing, leave the description/tags buffers alone.
    _band = widget.band;
    if (!_isEditing) {
      _descriptionController.text = _band.description ?? '';
      _tags = List<String>.from(_band.tags);
    }
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
    final canManageMembers = ref.watch(canManageBandMembersProvider(_band.id));
    // Pushed branch child: title + actions are published for the shell's
    // bottom bar ([← Back] [title] [⋮ Menu]); the top bar is title-only.
    return MenuScopePublisher(
      data: MenuScopeData(
        title: 'About ${_band.name}',
        items: [
          if (_canEdit) ...[
            AppMenuItem(
              icon: _isEditing ? Icons.close : Icons.edit_outlined,
              label: _isEditing ? 'Cancel' : 'Edit',
              onTap: _toggleEdit,
            ),
            AppMenuItem(
              icon: Icons.save_outlined,
              label: 'Save',
              onTap: _saveChanges,
            ),
          ],
          AppMenuItem(
            icon: Icons.share_outlined,
            label: 'Share Band',
            onTap: () => _shareBand(context),
          ),
        ],
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
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
        ),
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
                      color: context.mp.textPrimary,
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
                          color: context.mp.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created ${_formatDate(_band.createdAt)}',
                        style: MonoPulseTypography.bodyMedium.copyWith(
                          color: context.mp.textSecondary,
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
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrange10,
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
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: MonoPulseColors.accentOrange,
            ),
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
                    color: context.mp.textPrimary,
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
                      ? context.mp.textPrimary
                      : context.mp.textSecondary,
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
                    color: context.mp.textPrimary,
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
                    selectedColor: MonoPulseColors.accentOrange10,
                    checkmarkColor: MonoPulseColors.accentOrange,
                  );
                }).toList(),
              ),
            ] else ...[
              if (_tags.isEmpty)
                Text(
                  'No tags yet',
                  style: TextStyle(color: context.mp.textSecondary),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          backgroundColor: MonoPulseColors.accentOrange10,
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
                        color: context.mp.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_band.members.length}',
                  style: TextStyle(
                    color: context.mp.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_band.members.isEmpty)
              Text(
                'No members found',
                style: TextStyle(color: context.mp.textSecondary),
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
                  color: context.mp.textTertiary,
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

  Widget _buildMemberTile(BandMember member, int index, bool canManageMembers) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: canManageMembers ? () => _showMemberActions(index) : null,
      leading: UserAvatar(
        photoURL: null,
        displayName: memberLabel(
          displayName: member.displayName,
          email: member.email,
        ),
        radius: 20,
      ),
      title: Text(
        memberLabel(displayName: member.displayName, email: member.email),
        style: TextStyle(
          color: context.mp.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatRole(member.role),
            style: TextStyle(color: context.mp.textSecondary),
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
                  backgroundColor: MonoPulseColors.accentOrange10,
                  labelStyle: const TextStyle(
                    color: MonoPulseColors.accentOrange,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
      trailing: canManageMembers
          ? Icon(Icons.more_vert, color: context.mp.textSecondary, size: 20)
          : null,
    );
  }

  /// Shows the admin management sheet for the member at [index].
  Future<void> _showMemberActions(int index) async {
    final member = _band.members[index];
    final name = memberLabel(
      displayName: member.displayName,
      email: member.email,
    );

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
                    color: context.mp.textPrimary,
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
                        : context.mp.textSecondary,
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
      () => ref
          .read(bandFunctionServiceProvider)
          .setMemberRole(
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
      () => ref
          .read(bandFunctionServiceProvider)
          .setMemberMusicRoles(
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

    final name = memberLabel(
      displayName: member.displayName,
      email: member.email,
    );
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
      () => ref
          .read(bandFunctionServiceProvider)
          .removeMember(bandId: _band.id, targetUid: member.uid),
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
    showAppSnackBar(context, message);
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
        showAppSnackBar(context, 'Band updated successfully');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Error updating band: $e');
      }
    }
  }

  Future<void> _shareBand(BuildContext context) async {
    final inviteCode = _band.inviteCode;
    if (inviteCode == null || inviteCode.isEmpty) {
      showAppSnackBar(context, 'No invite code available for this band');
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
      return DateFormat.yMMMd().format(date);
    }
  }
}
