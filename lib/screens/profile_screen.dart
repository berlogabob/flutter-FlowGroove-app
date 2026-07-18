import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/auth/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../services/account_function_service.dart';
import '../../services/avatar_function_service.dart';
import '../../services/storage_service.dart';
import '../../services/telegram_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/music_role_icon.dart';
import '../../utils/responsive_breakpoints.dart';
import '../../widgets/role_picker_widget.dart';
import '../../widgets/standard_screen_scaffold.dart';
import '../utils/snackbar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _profilePhotoPath;
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadProfilePhoto();
    _migrateLegacyLocalPhoto();
  }

  // Avatar state derives from the LIVE users/{uid} doc (userDocProvider), so
  // this screen and every other one (home greeting, band lists) always agree
  // and update together (#91). `ref.read` here so the getters are also safe
  // in bottom-sheet callbacks; build() watches the provider for rebuilds.
  Map<String, dynamic>? get _userDoc => ref.read(userDocProvider).asData?.value;

  String? get _avatarUrl {
    final doc = _userDoc;
    final url = doc?['photoURL'] as String?;
    if (url != null) return url;
    if (doc?['telegramConsent'] == true) {
      // Legacy: no Storage URL yet, fall back to Telegram URL from Firestore
      return doc?['telegramPhotoURL'] as String?;
    }
    return null;
  }

  String get _photoSource {
    final doc = _userDoc;
    if (doc?['photoURL'] != null) {
      return (doc?['photoSource'] as String?) ?? 'upload';
    }
    if (doc?['telegramConsent'] == true && doc?['telegramPhotoURL'] != null) {
      return 'telegram';
    }
    return 'local';
  }

  String? get _telegramId => _userDoc?['telegramId'] as String?;

  /// One-time migration: upload the legacy local profile_photo.jpg to Storage
  /// when the user doc has no photoURL yet. The Storage write updates the doc,
  /// which propagates through userDocProvider.
  Future<void> _migrateLegacyLocalPhoto() async {
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if ((userDoc.data()?['photoURL'] as String?) != null) return;

      final dir = await getApplicationDocumentsDirectory();
      final legacy = File('${dir.path}/profile_photo.jpg');
      if (!await legacy.exists()) return;

      await StorageService().uploadProfilePicture(await legacy.readAsBytes());
      await legacy.delete();
      if (mounted) {
        setState(() => _profilePhotoPath = null);
      }
    } catch (e) {
      debugPrint('Avatar migration skipped: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photoFile = File('${directory.path}/profile_photo.jpg');
      if (await photoFile.exists()) {
        if (!mounted) return;
        setState(() {
          if (_avatarUrl == null) {
            _profilePhotoPath = photoFile.path;
          }
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
      if (pickedFile == null) return;

      // readAsBytes() works on web (blob) and mobile; File(path) + putFile does not.
      // The upload writes photoURL to users/{uid}; the live doc stream
      // refreshes this screen and every other avatar in the app.
      await StorageService().uploadProfilePicture(
        await pickedFile.readAsBytes(),
      );
      if (!mounted) return;
      setState(() => _profilePhotoPath = null);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Error uploading photo: $e');
      }
    }
  }

  Future<void> _removePhoto() async {
    try {
      await StorageService().deleteProfilePicture();
      if (!mounted) return;
      setState(() => _profilePhotoPath = null);
    } catch (e) {
      debugPrint('Error removing photo: $e');
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.mp.surface,
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
                color: _telegramId != null
                    ? MonoPulseColors.info
                    : context.mp.textTertiary,
              ),
              title: Text(
                _telegramId != null ? 'Use Telegram Photo' : 'Link Telegram',
              ),
              subtitle: _telegramId != null
                  ? (_photoSource == 'telegram'
                        ? const Text(
                            '✓ Currently using',
                            style: TextStyle(color: MonoPulseColors.success),
                          )
                        : null)
                  : Text(
                      'Import photo from Telegram',
                      style: TextStyle(color: context.mp.textTertiary),
                    ),
              onTap: () async {
                Navigator.pop(context);
                if (_telegramId == null) {
                  _showTelegramLinkDialog();
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                try {
                  // Server writes photoURL to users/{uid}; the live doc
                  // stream refreshes all screens.
                  await AvatarFunctionService().importTelegramAvatar();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Telegram import failed: $e')),
                  );
                }
              },
            ),
            // Google option - only when google-linked
            if (FirebaseAuth.instance.currentUser?.providerData.any(
                  (p) => p.providerId == 'google.com',
                ) ??
                false)
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: const Text('Use Google Photo'),
                subtitle: _photoSource == 'google'
                    ? const Text(
                        '✓ Currently using',
                        style: TextStyle(color: MonoPulseColors.success),
                      )
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await AvatarFunctionService().importGoogleAvatar();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Google import failed: $e')),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              subtitle: _photoSource == 'upload' && _avatarUrl != null
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
              subtitle: _photoSource == 'upload' && _avatarUrl != null
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
            if (_avatarUrl != null || _profilePhotoPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: MonoPulseColors.error),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: MonoPulseColors.error),
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
    final botLink = TelegramService.botLink(
      userId != null ? 'link_$userId' : 'link',
    );
    // On desktop web Telegram is usually on the phone, not this machine —
    // lead with a QR to scan instead of a deep link that dead-ends.
    final isDesktopWeb =
        kIsWeb &&
        getBreakpoint(MediaQuery.of(context).size.width) ==
            ScreenBreakpoint.desktop;

    Future<void> copyLink(BuildContext context) async {
      await Clipboard.setData(ClipboardData(text: botLink));
      if (context.mounted) {
        showAppSnackBar(
          context,
          'Link copied - paste in Telegram to continue.',
        );
      }
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link Telegram'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Link your Telegram account to automatically import your profile name and photo to FlowGroove.',
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: context.mp.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (isDesktopWeb) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(MonoPulseSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        MonoPulseRadius.small,
                      ),
                    ),
                    child: QrImageView(data: botLink, size: 160),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Scan with your phone - Telegram opens the FlowGroove bot',
                    style: MonoPulseTypography.bodySmall.copyWith(
                      color: context.mp.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(MonoPulseSpacing.md),
                decoration: BoxDecoration(
                  color: context.mp.surfaceRaised,
                  borderRadius: BorderRadius.circular(MonoPulseRadius.small),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How it works:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (isDesktopWeb)
                      const Text('1. Scan the QR code with your phone')
                    else
                      const Text('1. Click "Open Telegram" below'),
                    const Text('2. Send /link command to the bot'),
                    const Text('3. Tap "Yes, link my profile"'),
                    const Text('4. Your name and photo will be imported'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (isDesktopWeb) ...[
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final opened = await telegramService.openBotChat(userId);
                if (!opened && mounted) {
                  await copyLink(this.context);
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('Open Telegram'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await copyLink(this.context);
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy link'),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final opened = await telegramService.openBotChat(userId);
                if (!opened && mounted) {
                  await Clipboard.setData(ClipboardData(text: botLink));
                  showAppSnackBar(
                    context,
                    'Could not open Telegram. Link copied to clipboard - paste in Telegram to continue.',
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
      // Use the provider method which updates both Firebase and local state
      await ref.read(appUserProvider.notifier).updateDisplayName(newName);

      if (mounted) {
        setState(() => _isEditingName = false);
        showAppSnackBar(context, 'Name updated');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Error updating name: $e');
      }
    }
  }

  /// Get profile image based on source selection.
  /// Network URL (_avatarUrl) is the authoritative source for all
  /// Storage-backed sources: 'upload', 'telegram', 'google'.
  ImageProvider? _getProfileImage() {
    // Any Storage-backed network URL
    if (_avatarUrl != null) {
      return NetworkImage(_avatarUrl!);
    }
    // Legacy local file (pre-migration fallback)
    if (_profilePhotoPath != null) {
      return FileImage(File(_profilePhotoPath!));
    }
    // No photo
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the live user doc: the avatar getters above read from it.
    ref.watch(userDocProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final appUserAsync = ref.watch(appUserProvider);
    // Demo is a shared public account: hide all profile-editing affordances.
    final isDemo = ref.watch(isDemoUserProvider);

    final displayName =
        appUserAsync.whenOrNull(data: (u) => u?.displayName) ??
        user?.displayName ??
        'User';

    return StandardScreenScaffold(
      title: 'Profile',
      showBackButton: false, // Hide back button for main tabs
      body: ListView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: isDemo ? null : _showPhotoOptions,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: context.mp.surfaceRaised,
                          backgroundImage: _getProfileImage(),
                          child: _getProfileImage() == null
                              ? Text(
                                  user?.email?.substring(0, 1).toUpperCase() ??
                                      '?',
                                  style: MonoPulseTypography.headlineLarge
                                      .copyWith(
                                        color: MonoPulseColors.accentOrange,
                                        fontWeight: MonoPulseTypography.bold,
                                      ),
                                )
                              : null,
                        ),
                        if (!isDemo)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(
                                MonoPulseSpacing.xxs,
                              ),
                              decoration: const BoxDecoration(
                                color: MonoPulseColors.accentOrange,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 12,
                                color: context.mp.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MonoPulseSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isEditingName)
                          Row(
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Lets a long "Firstname 'Nickname' Lastname"
                              // wrap onto its own short lines instead of
                              // forcing one wide centered line.
                              Expanded(
                                child: Text(
                                  displayName,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: MonoPulseTypography.headlineSmall
                                      .copyWith(color: context.mp.textPrimary),
                                ),
                              ),
                              if (!isDemo)
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    _nameController.text = displayName == 'User'
                                        ? ''
                                        : displayName;
                                    setState(() => _isEditingName = true);
                                  },
                                  color: context.mp.textSecondary,
                                ),
                            ],
                          ),
                        const SizedBox(height: MonoPulseSpacing.xxs),
                        Text(
                          user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MonoPulseTypography.bodyMedium.copyWith(
                            color: context.mp.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          _buildSection(title: 'My Roles', children: [_buildTagsSection()]),
          const SizedBox(height: MonoPulseSpacing.lg),
          _buildSection(
            title: 'Account',
            children: [
              if (!isDemo)
                _buildMenuItem(
                  icon: Icons.person_outline,
                  title: 'Edit Profile',
                  subtitle: 'Change name and photo',
                  onTap: _showPhotoOptions,
                ),
              if (!isDemo)
                _buildMenuItem(
                  icon: Icons.send,
                  title: 'Link Telegram',
                  subtitle: 'Get name and photo from Telegram',
                  onTap: _showTelegramLinkDialog,
                ),
              // Keep screen on / analytics / AI access moved to the global
              // Settings screen (#129) — one control, one home.
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
          const SizedBox(height: MonoPulseSpacing.lg),
          _DangerZone(onDeleteAccount: _confirmAndDeleteAccount),
        ],
      ),
    );
  }

  /// Confirms, then deletes the account + all data via the server-authoritative
  /// `deleteAccount` callable, signs out and returns to login (Google Play
  /// data-deletion requirement).
  Future<void> _confirmAndDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text(
          'This permanently deletes your account and all your data — your '
          'songs, setlists, and band memberships. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: MonoPulseColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // Non-dismissible progress while the server cascades the deletion.
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      await AccountFunctionService().deleteAccount();
      if (!mounted) return;
      Navigator.pop(context); // dismiss progress
      await ref.read(appUserProvider.notifier).signOut();
      if (mounted) context.goNamed('login');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss progress
      final msg = e.code == 'failed-precondition'
          ? (e.message ?? 'This account cannot be deleted.')
          : 'Could not delete your account. Please try again.';
      showAppSnackBar(context, msg);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss progress
      showAppSnackBar(
        context,
        'Could not delete your account. Please try again.',
      );
    }
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: MonoPulseSpacing.xs,
            bottom: MonoPulseSpacing.sm,
          ),
          child: Text(
            title,
            style: MonoPulseTypography.labelLarge.copyWith(
              color: context.mp.textSecondary,
            ),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildTagsSection() {
    final userAsync = ref.watch(appUserProvider);
    final isDemo = ref.watch(isDemoUserProvider);

    return userAsync.when(
      data: (user) {
        final roles = user?.musicRoles ?? [];

        return Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: roles.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: MonoPulseSpacing.xs,
                        ),
                        child: Text(
                          'Tap edit to add your instruments and roles.',
                          style: TextStyle(color: context.mp.textTertiary),
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: roles.map((role) {
                          final icon = MusicRoleIcon.getIcon(role);
                          final displayName = MusicRoleIcon.getDisplayName(
                            role,
                          );
                          return Chip(
                            label: Text(
                              icon != null ? '$icon $displayName' : displayName,
                              style: MonoPulseTypography.bodySmall.copyWith(
                                color: context.mp.textPrimary,
                              ),
                            ),
                            backgroundColor: MonoPulseColors.accentOrange10,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
              ),
              if (!isDemo)
                TextButton.icon(
                  onPressed: () => _editRoles(roles),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(MonoPulseSpacing.lg),
        child: CircularProgressIndicator(),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(MonoPulseSpacing.lg),
        child: Text(
          'Error loading roles',
          style: TextStyle(color: MonoPulseColors.error),
        ),
      ),
    );
  }

  Future<void> _editRoles(List<String> currentRoles) async {
    final result = await showRolePicker(
      context: context,
      currentRoles: currentRoles,
      title: 'My Roles',
    );
    if (result != null) {
      try {
        await ref.read(appUserProvider.notifier).updateMusicRoles(result);
        if (mounted) {
          showAppSnackBar(context, 'Roles updated');
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, 'Error updating roles: $e');
        }
      }
    }
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: MonoPulseColors.accentOrange),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

}

/// GitHub-style collapsible section: starts closed so Delete Account can't be
/// tapped by accident, tap the header to reveal it.
class _DangerZone extends StatefulWidget {
  const _DangerZone({required this.onDeleteAccount});

  final VoidCallback onDeleteAccount;

  @override
  State<_DangerZone> createState() => _DangerZoneState();
}

class _DangerZoneState extends State<_DangerZone> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MonoPulseColors.error.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MonoPulseSpacing.lg,
                vertical: MonoPulseSpacing.md,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: MonoPulseColors.error,
                  ),
                  const SizedBox(width: MonoPulseSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Danger zone',
                      style: TextStyle(
                        color: MonoPulseColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: MonoPulseAnimation.durationShort,
                    child: const Icon(
                      Icons.expand_more,
                      color: MonoPulseColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                MonoPulseSpacing.lg,
                0,
                MonoPulseSpacing.lg,
                MonoPulseSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.onDeleteAccount,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Delete account',
                    style: TextStyle(
                      color: MonoPulseColors.error,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: MonoPulseAnimation.durationShort,
          ),
        ],
      ),
    );
  }
}
