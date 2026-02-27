import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/band.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/custom_app_bar.dart';

class BandAboutScreen extends ConsumerStatefulWidget {
  final Band band;

  const BandAboutScreen({super.key, required this.band});

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
    return Scaffold(
      appBar: CustomAppBar.build(
        context,
        title: 'About ${_band.name}',
        menuItems: [
          if (_canEdit) ...[
            PopupMenuItem<void>(
              onTap: () => _toggleEdit(),
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
        padding: const EdgeInsets.all(16),
        children: [
          _buildBandInfo(),
          const SizedBox(height: 24),
          _buildDescriptionSection(),
          const SizedBox(height: 24),
          _buildTagsSection(),
          const SizedBox(height: 24),
          _buildMembersSection(),
        ],
      ),
    );
  }

  Widget _buildBandInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: MonoPulseColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created ${_formatDate(_band.createdAt)}',
                        style: const TextStyle(
                          color: MonoPulseColors.textSecondary,
                          fontSize: 14,
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
                ),
                const SizedBox(width: 8),
                if (_band.inviteCode != null && _band.inviteCode!.isNotEmpty)
                  _buildInfoChip(
                    icon: Icons.qr_code,
                    label: 'Invite: ${_band.inviteCode}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrangeSubtle,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: MonoPulseColors.accentOrange),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: MonoPulseColors.accentOrange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description_outlined, size: 20),
                SizedBox(width: 8),
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.label_outline, size: 20),
                SizedBox(width: 8),
                Text(
                  'Tags',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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

  Widget _buildMembersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.people, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Members',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
                return _buildMemberTile(member);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(BandMember member) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: MonoPulseColors.accentOrange,
        child: Text(
          (member.displayName ?? member.email ?? '?')[0].toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        member.displayName ?? member.email ?? 'Unknown',
        style: const TextStyle(
          color: MonoPulseColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _formatRole(member.role),
        style: const TextStyle(color: MonoPulseColors.textSecondary),
      ),
      trailing: member.role == BandMember.roleAdmin
          ? const Icon(
              Icons.star,
              color: MonoPulseColors.accentOrange,
              size: 20,
            )
          : null,
    );
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

  void _shareBand(BuildContext context) async {
    final inviteCode = _band.inviteCode;
    if (inviteCode == null || inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invite code available for this band')),
      );
      return;
    }

    const String domain = 'repsync-app-8685c.web.app';

    final shareText =
        'Join my band "${_band.name}" on RepSync!\n\n'
        'Use invite code: $inviteCode\n\n'
        'Or click the link: https://$domain/join-band?code=$inviteCode';

    await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: 'Join my band "${_band.name}" on RepSync',
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
