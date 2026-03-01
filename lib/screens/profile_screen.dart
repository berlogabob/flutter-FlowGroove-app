import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../services/telegram_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/standard_screen_scaffold.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _version = 'Loading...';
  String _buildDate = '';
  String? _profilePhotoPath;
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadVersionInfo();
    _loadProfilePhoto();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = '${packageInfo.version}+${packageInfo.buildNumber}';
          _buildDate = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _version = '0.11.0+1';
          _buildDate = '';
        });
      }
    }
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photoFile = File('${directory.path}/profile_photo.jpg');
      if (await photoFile.exists()) {
        setState(() {
          _profilePhotoPath = photoFile.path;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile photo: $e');
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final savedFile = await File(
          pickedFile.path,
        ).copy('${directory.path}/profile_photo.jpg');
        setState(() {
          _profilePhotoPath = savedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking photo: $e')));
      }
    }
  }

  Future<void> _removePhoto() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photoFile = File('${directory.path}/profile_photo.jpg');
      if (await photoFile.exists()) {
        await photoFile.delete();
      }
      setState(() {
        _profilePhotoPath = null;
      });
    } catch (e) {
      debugPrint('Error removing photo: $e');
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MonoPulseColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_profilePhotoPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showTelegramLinkDialog() {
    final telegramService = TelegramService();
    final userAsync = ref.read(currentUserProvider);
    final userId = userAsync.value?.uid;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link Telegram'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Link your Telegram account to automatically import your profile name and photo to RepSync.',
              style: TextStyle(
                fontSize: 14,
                color: MonoPulseColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MonoPulseColors.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Click "Open Telegram" below'),
                  Text('2. Send /link command to the bot'),
                  Text('3. Tap "Yes, link my profile"'),
                  Text('4. Your name and photo will be imported'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              // Open Telegram with start parameter
              final opened = await telegramService.openBotChat(userId);
              if (!opened && mounted) {
                // Try copying link to clipboard as fallback
                final link = 'https://t.me/repsyncappbot?start=link_$userId';
                await Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not open Telegram. Link copied to clipboard - paste in Telegram to continue.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Open Telegram'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      setState(() => _isEditingName = false);
      return;
    }

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user == null) return;

    try {
      await user.updateDisplayName(newName);
      await ref
          .read(firestoreProvider)
          .updateUserProfile(uid: user.uid, displayName: newName);
      if (mounted) {
        setState(() => _isEditingName = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Name updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating name: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final appUserAsync = ref.watch(appUserProvider);

    final displayName =
        appUserAsync.whenOrNull(data: (u) => u?.displayName) ??
        user?.displayName ??
        'User';

    return StandardScreenScaffold(
      title: 'Profile',
      showBackButton: false, // Hide back button for main tabs
      showOfflineIndicator: true,
      body: ListView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showPhotoOptions,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: MonoPulseColors.surfaceRaised,
                          backgroundImage: _profilePhotoPath != null
                              ? FileImage(File(_profilePhotoPath!))
                              : null,
                          child: _profilePhotoPath == null
                              ? Text(
                                  user?.email?.substring(0, 1).toUpperCase() ??
                                      '?',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    color: MonoPulseColors.accentOrange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: MonoPulseColors.accentOrange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MonoPulseSpacing.lg),
                  if (_isEditingName)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter display name',
                              isDense: true,
                            ),
                            autofocus: true,
                            onSubmitted: (_) => _saveDisplayName(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: _saveDisplayName,
                          color: MonoPulseColors.accentOrange,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _isEditingName = false),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: MonoPulseColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () {
                            _nameController.text = displayName == 'User'
                                ? ''
                                : displayName;
                            setState(() => _isEditingName = true);
                          },
                          color: MonoPulseColors.textSecondary,
                        ),
                      ],
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
          const SizedBox(height: MonoPulseSpacing.lg),
          _buildSection(title: 'My Tags', children: [_buildTagsSection()]),
          const SizedBox(height: MonoPulseSpacing.lg),
          _buildSection(
            title: 'Account',
            children: [
              _buildMenuItem(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                subtitle: 'Change name and photo',
                onTap: _showPhotoOptions,
              ),
              _buildMenuItem(
                icon: Icons.send,
                title: 'Link Telegram',
                subtitle: 'Get name and photo from Telegram',
                onTap: _showTelegramLinkDialog,
              ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          _buildSection(
            title: 'App Info',
            children: [
              _buildInfoItem(title: 'Version', value: _version),
              _buildInfoItem(
                title: 'Build',
                value: _buildDate.isNotEmpty ? _buildDate : 'Production',
              ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.xxl),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await ref.read(appUserProvider.notifier).signOut();
                  if (mounted) {
                    context.goNamed('login');
                  }
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: MonoPulseColors.textSecondary,
            ),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildTagsSection() {
    final userAsync = ref.watch(appUserProvider);

    return userAsync.when(
      data: (user) {
        final tags = user?.baseTags ?? [];

        if (tags.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No tags yet. Add your instruments and roles in band assignments.',
              style: TextStyle(color: MonoPulseColors.textTertiary),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: MonoPulseColors.accentOrange,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Error loading tags',
          style: TextStyle(color: MonoPulseColors.error),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: MonoPulseColors.accentOrange),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildInfoItem({required String title, required String value}) {
    return ListTile(
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(color: MonoPulseColors.textSecondary),
      ),
    );
  }
}
