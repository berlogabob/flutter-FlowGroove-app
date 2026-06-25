import 'package:flutter/material.dart';

import '../../models/band.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/music_role_icon.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/user_avatar.dart';

/// Read-only list of band members with their permission and music roles.
class BandMembersScreen extends StatelessWidget {
  const BandMembersScreen({required this.band, super.key});

  final Band band;

  String _formatRole(String role) {
    switch (role) {
      case BandMember.roleAdmin:
        return 'Admin';
      case BandMember.roleEditor:
        return 'Editor';
      default:
        return 'Viewer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.build(context, title: '${band.name} Members'),
      body: band.members.isEmpty
          ? const Center(
              child: Text(
                'No members found',
                style: TextStyle(color: MonoPulseColors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              itemCount: band.members.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = band.members[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
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
                        style: const TextStyle(
                          color: MonoPulseColors.textSecondary,
                        ),
                      ),
                      if (member.musicRoles.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: member.musicRoles.map((role) {
                            final icon = MusicRoleIcon.getIcon(role);
                            final displayName =
                                MusicRoleIcon.getDisplayName(role);
                            return Chip(
                              label: Text(
                                icon != null
                                    ? '$icon $displayName'
                                    : displayName,
                                style: const TextStyle(fontSize: 10),
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
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
                  trailing: member.role == BandMember.roleAdmin
                      ? const Icon(Icons.star, color: MonoPulseColors.accentOrange, size: 18)
                      : null,
                );
              },
            ),
    );
  }
}
