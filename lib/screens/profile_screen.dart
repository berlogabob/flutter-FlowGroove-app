import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
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
  String? _telegramPhotoURL;
  String _photoSource = 'local'; // 'telegram', 'google', 'local'
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadVersionInfo();
    _loadProfilePhoto();
    _loadTelegramProfile();
  }

  /// Load Telegram profile data if user gave consent
  Future<void> _loadTelegramProfile() async {
    try {
      final user = ref.read(currentUserProvider).value;
      print('🔍 Loading Telegram profile for user: ${user?.uid}');

      if (user == null) {
        print('⚠️ No user found');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      print('📄 User doc exists: ${userDoc.exists}');

      if (userDoc.exists) {
        final data = userDoc.data();
        print('📊 User data: $data');

        if (data != null && data['telegramConsent'] == true) {
          print('✅ Telegram consent found');
          setState(() {
            _telegramPhotoURL = data['telegramPhotoURL'] as String?;
            print('🖼️ Telegram photo URL: $_telegramPhotoURL');
            // If no local photo, use Telegram
            if (_profilePhotoPath == null && _telegramPhotoURL != null) {
              _photoSource = 'telegram';
              print('📱 Set photo source to telegram');
            }
          });
        } else {
          print('⚠️ No telegram consent or data');
        }
      }
    } catch (e) {
      print('❌ Error loading Telegram profile: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadVersionInfo() async {
    try {
      // On web, directly fetch version.json to get buildNumber correctly
      if (kIsWeb) {
        try {
          final response = await http.get(Uri.parse('version.json'));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final version = data['version'] as String? ?? '';
            final buildNumber = data['buildNumber'] as String? ?? '';
            
            if (mounted) {
              setState(() {
                if (buildNumber.isNotEmpty && buildNumber != '1') {
                  _version = '$version+$buildNumber';
                } else {
                  _version = version;
                }
                _buildDate = '';
              });
            }
            return;
          }
        } catch (_) {
          // Fallback to package_info_plus
        }
      }
      
      // For mobile or if web fetch fails
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
          _version = '0.13.1+146';
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
            // Telegram option - always show
            ListTile(
              leading: Icon(
                Icons.send,
                color: _telegramPhotoURL != null ? MonoPulseColors.info : MonoPulseColors.textTertiary,
              ),
              title: Text(
                _telegramPhotoURL != null
                    ? 'Use Telegram Photo'
                    : 'Link Telegram',
              ),
              subtitle: _telegramPhotoURL != null
                  ? (_photoSource == 'telegram'
                        ? const Text(
                            '✓ Currently using',
                            style: TextStyle(color: MonoPulseColors.success),
                          )
                        : null)
                  : const Text(
                      'Import photo from Telegram',
                      style: TextStyle(color: MonoPulseColors.textTertiary),
                    ),
              onTap: () {
                Navigator.pop(context);
                if (_telegramPhotoURL != null) {
                  // Use Telegram photo
                  setState(() {
                    _photoSource = 'telegram';
                    _profilePhotoPath = null;
                  });
                } else {
                  // Link Telegram first
                  _showTelegramLinkDialog();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              subtitle: _photoSource == 'local' && _profilePhotoPath != null
                  ? const Text(
                      '✓ Currently using',
                      style: TextStyle(color: MonoPulseColors.success),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              subtitle: _photoSource == 'local' && _profilePhotoPath != null
                  ? const Text(
                      '✓ Currently using',
                      style: TextStyle(color: MonoPulseColors.success),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_profilePhotoPath != null || _photoSource == 'telegram')
              ListTile(
                leading: const Icon(Icons.delete, color: MonoPulseColors.error),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: MonoPulseColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _profilePhotoPath = null;
                    _photoSource = 'local';
                  });
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
            Text(
              'Link your Telegram account to automatically import your profile name and photo to RepSync.',
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: MonoPulseColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(MonoPulseSpacing.md),
              decoration: BoxDecoration(
                color: MonoPulseColors.surfaceRaised,
                borderRadius: BorderRadius.circular(MonoPulseRadius.small),
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

  /// Get profile image based on source selection
  ImageProvider? _getProfileImage() {
    // Telegram photo
    if (_photoSource == 'telegram' && _telegramPhotoURL != null) {
      return NetworkImage(_telegramPhotoURL!);
    }
    // Local photo
    if (_profilePhotoPath != null) {
      return FileImage(File(_profilePhotoPath!));
    }
    // No photo
    return null;
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
                          backgroundImage: _getProfileImage(),
                          child: _getProfileImage() == null
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
                              color: MonoPulseColors.textPrimary,
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
                          style: MonoPulseTypography.headlineLarge.copyWith(
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
                    style: MonoPulseTypography.bodyLarge.copyWith(
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
              icon: const Icon(Icons.logout, color: MonoPulseColors.error),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: MonoPulseColors.error),
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
            style: MonoPulseTypography.labelLarge.copyWith(
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
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            child: Text(
              'No tags yet. Add your instruments and roles in band assignments.',
              style: TextStyle(color: MonoPulseColors.textTertiary),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: MonoPulseColors.textPrimary,
                  ),
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
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => const Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
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
