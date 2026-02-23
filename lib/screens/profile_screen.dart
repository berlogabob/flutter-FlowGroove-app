import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../providers/auth/auth_provider.dart';
import '../theme/mono_pulse_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _version = 'Loading...';
  String _buildDate = '';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      // Try to load version from web/version.json
      final response = await http.get(Uri.parse('version.json'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final version = data['version'] as String;
        final buildNumber = data['buildNumber'] as String;
        final buildDateStr = data['buildDate'] as String?;

        // Parse build date and convert to Lisbon timezone
        String buildDate = '';
        if (buildDateStr != null && buildDateStr.isNotEmpty) {
          try {
            final utcDate = DateTime.parse(buildDateStr);
            // Convert to Lisbon timezone (UTC+0 in winter, UTC+1 in summer)
            // For simplicity, use UTC offset for Portugal
            final lisbonDate = utcDate
                .toLocal(); // Flutter web runs in browser timezone
            buildDate =
                '${lisbonDate.year}-${lisbonDate.month.toString().padLeft(2, '0')}-${lisbonDate.day.toString().padLeft(2, '0')} '
                '${lisbonDate.hour.toString().padLeft(2, '0')}:${lisbonDate.minute.toString().padLeft(2, '0')}';
          } catch (e) {
            buildDate = '';
          }
        }

        if (mounted) {
          setState(() {
            _version = '$version+$buildNumber';
            _buildDate = buildDate;
          });
        }
      } else {
        // Fallback to hardcoded version
        if (mounted) {
          setState(() {
            _version = '0.9.0+1';
            _buildDate = '';
          });
        }
      }
    } catch (e) {
      // Fallback to hardcoded version
      if (mounted) {
        setState(() {
          _version = '0.9.0+1';
          _buildDate = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final appUserAsync = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: MonoPulseColors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: MonoPulseColors.surfaceRaised,
                    child: Text(
                      user?.email?.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(
                        fontSize: 40,
                        color: MonoPulseColors.accentOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: MonoPulseSpacing.lg),
                  Text(
                    appUserAsync.whenOrNull(
                          data: (u) => u?.displayName ?? 'User',
                        ) ??
                        'Loading...',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: MonoPulseColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      color: MonoPulseColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.xxl),
          const Text(
            'Account',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: MonoPulseColors.textTertiary,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.person,
                    color: MonoPulseColors.textSecondary,
                  ),
                  title: const Text(
                    'Edit Profile',
                    style: TextStyle(color: MonoPulseColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MonoPulseColors.textTertiary,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon!')),
                    );
                  },
                ),
                const Divider(height: 1, color: MonoPulseColors.borderSubtle),
                ListTile(
                  leading: const Icon(
                    Icons.notifications,
                    color: MonoPulseColors.textSecondary,
                  ),
                  title: const Text(
                    'Notifications',
                    style: TextStyle(color: MonoPulseColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MonoPulseColors.textTertiary,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon!')),
                    );
                  },
                ),
                const Divider(height: 1, color: MonoPulseColors.borderSubtle),
                ListTile(
                  leading: const Icon(
                    Icons.palette,
                    color: MonoPulseColors.textSecondary,
                  ),
                  title: const Text(
                    'Appearance',
                    style: TextStyle(color: MonoPulseColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MonoPulseColors.textTertiary,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.xxl),
          const Text(
            'About',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: MonoPulseColors.textTertiary,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.info,
                    color: MonoPulseColors.textSecondary,
                  ),
                  title: const Text(
                    'App Version',
                    style: TextStyle(color: MonoPulseColors.textPrimary),
                  ),
                  subtitle: _buildDate.isNotEmpty
                      ? Text(
                          _buildDate,
                          style: const TextStyle(
                            color: MonoPulseColors.textTertiary,
                          ),
                        )
                      : null,
                  trailing: Text(
                    _version,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: MonoPulseColors.textPrimary,
                    ),
                  ),
                ),
                const Divider(height: 1, color: MonoPulseColors.borderSubtle),
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip,
                    color: MonoPulseColors.textSecondary,
                  ),
                  title: const Text(
                    'Privacy Policy',
                    style: TextStyle(color: MonoPulseColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MonoPulseColors.textTertiary,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon!')),
                    );
                  },
                ),
                const Divider(height: 1, color: MonoPulseColors.borderSubtle),
                ListTile(
                  leading: const Icon(
                    Icons.description,
                    color: MonoPulseColors.textSecondary,
                  ),
                  title: const Text(
                    'Terms of Service',
                    style: TextStyle(color: MonoPulseColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MonoPulseColors.textTertiary,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.xxl),
          const Text(
            'Support',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: MonoPulseColors.textTertiary,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.help,
                    color: MonoPulseColors.textSecondary,
                  ),
                  title: const Text(
                    'Help & FAQ',
                    style: TextStyle(color: MonoPulseColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MonoPulseColors.textTertiary,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon!')),
                    );
                  },
                ),
                const Divider(height: 1, color: MonoPulseColors.borderSubtle),
                ListTile(
                  leading: const Icon(
                    Icons.feedback,
                    color: MonoPulseColors.textSecondary,
                  ),
                  title: const Text(
                    'Send Feedback',
                    style: TextStyle(color: MonoPulseColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MonoPulseColors.textTertiary,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.xxxl),
          ElevatedButton.icon(
            onPressed: () => _showLogoutDialog(context, ref),
            icon: const Icon(Icons.logout, color: MonoPulseColors.black),
            label: const Text(
              'Log Out',
              style: TextStyle(color: MonoPulseColors.black),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: MonoPulseColors.error,
              foregroundColor: MonoPulseColors.black,
              padding: const EdgeInsets.symmetric(
                vertical: MonoPulseSpacing.lg,
              ),
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.xxxl),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MonoPulseColors.surface,
        title: const Text(
          'Log Out',
          style: TextStyle(color: MonoPulseColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: MonoPulseColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: MonoPulseColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(appUserProvider.notifier).signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MonoPulseColors.error,
              foregroundColor: MonoPulseColors.black,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
