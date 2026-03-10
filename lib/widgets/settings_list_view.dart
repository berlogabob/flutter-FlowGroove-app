import 'dart:io';

import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// Settings list view with grouped sections.
///
/// Features:
/// - Section headers
/// - Menu item tiles with icons
/// - Info item display (title/value pairs)
/// - Editable fields
/// - Photo picker tile
/// - Sign out button
///
/// Usage:
/// ```dart
/// SettingsListView(
///   sections: [
///     SettingsSection(
///       title: 'Account',
///       items: [
///         SettingsItem.icon(...),
///         SettingsItem.editable(...),
///       ],
///     ),
///   ],
///   footer: SignOutButton(onPressed: _signOut),
/// )
/// ```
class SettingsListView extends StatelessWidget {
  /// List of settings sections.
  final List<SettingsSection> sections;

  /// Footer widget (e.g., sign out button).
  final Widget? footer;

  const SettingsListView({super.key, required this.sections, this.footer});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      children: [
        // Sections
        ...sections.map((section) => _buildSection(context, section)),

        // Footer
        if (footer != null) ...[
          const SizedBox(height: MonoPulseSpacing.xxxl),
          footer!,
        ],
      ],
    );
  }

  Widget _buildSection(BuildContext context, SettingsSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(bottom: MonoPulseSpacing.md),
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: MonoPulseColors.textPrimary,
            ),
          ),
        ),
        // Section cards
        Card(
          color: MonoPulseColors.surface,
          child: Column(
            children: section.items.map((item) {
              final index = section.items.indexOf(item);
              return Column(
                children: [
                  item,
                  if (index < section.items.length - 1)
                    const Divider(
                      color: MonoPulseColors.borderSubtle,
                      height: 1,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: MonoPulseSpacing.lg),
      ],
    );
  }
}

/// Settings section containing a list of items.
class SettingsSection {
  /// Section title.
  final String title;

  /// List of settings items.
  final List<SettingsItem> items;

  const SettingsSection({required this.title, required this.items});
}

/// Base class for settings items.
abstract class SettingsItem extends StatelessWidget {
  const SettingsItem({super.key});
}

/// Settings item with icon, title, subtitle, and navigation.
class SettingsMenuItem extends SettingsItem {
  /// Icon to display.
  final IconData icon;

  /// Item title.
  final String title;

  /// Item subtitle (optional).
  final String? subtitle;

  /// Callback when item is tapped.
  final VoidCallback? onTap;

  /// Custom trailing widget (optional).
  final Widget? trailing;

  /// Whether item is enabled.
  final bool enabled;

  const SettingsMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: enabled
            ? MonoPulseColors.accentOrange
            : MonoPulseColors.textTertiary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled
              ? MonoPulseColors.textPrimary
              : MonoPulseColors.textDisabled,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(color: MonoPulseColors.textSecondary),
            )
          : null,
      trailing:
          trailing ??
          (enabled
              ? const Icon(
                  Icons.chevron_right,
                  color: MonoPulseColors.textSecondary,
                )
              : null),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}

/// Settings item displaying a title/value pair (info display).
class SettingsInfoItem extends SettingsItem {
  /// Item title (label).
  final String title;

  /// Item value.
  final String value;

  /// Callback when item is tapped (optional).
  final VoidCallback? onTap;

  const SettingsInfoItem({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: MonoPulseTypography.bodySmall,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          value,
          style: MonoPulseTypography.bodyLarge,
        ),
      ),
      trailing: onTap != null
          ? const Icon(
              Icons.chevron_right,
              color: MonoPulseColors.textSecondary,
            )
          : null,
      onTap: onTap,
    );
  }
}

/// Settings item with editable text field.
class SettingsEditableItem extends StatefulWidget {
  /// Item title (label).
  final String title;

  /// Current value.
  final String value;

  /// Whether in edit mode.
  final bool isEditing;

  /// Callback to toggle edit mode.
  final VoidCallback onToggleEdit;

  /// Callback to save value.
  final Function(String) onSave;

  const SettingsEditableItem({
    super.key,
    required this.title,
    required this.value,
    required this.isEditing,
    required this.onToggleEdit,
    required this.onSave,
  });

  @override
  State<SettingsEditableItem> createState() => _SettingsEditableItemState();
}

class _SettingsEditableItemState extends State<SettingsEditableItem> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(SettingsEditableItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        widget.title,
        style: MonoPulseTypography.bodySmall,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: widget.isEditing
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: MonoPulseTypography.bodyLarge,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.check,
                      color: MonoPulseColors.accentOrange,
                    ),
                    onPressed: () => widget.onSave(_controller.text),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: MonoPulseColors.textSecondary,
                    ),
                    onPressed: widget.onToggleEdit,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.value,
                      style: MonoPulseTypography.bodyLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: MonoPulseColors.textSecondary,
                    ),
                    onPressed: widget.onToggleEdit,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Settings item for profile photo with picker.
class SettingsPhotoItem extends SettingsItem {
  /// Current photo path (null = no photo).
  final String? photoPath;

  /// Callback when photo should be changed.
  final VoidCallback onPhotoTap;

  const SettingsPhotoItem({
    super.key,
    this.photoPath,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 30,
        backgroundColor: MonoPulseColors.surfaceRaised,
        backgroundImage: photoPath != null ? FileImage(File(photoPath!)) : null,
        child: photoPath == null
            ? const Icon(
                Icons.person,
                color: MonoPulseColors.textSecondary,
                size: 32,
              )
            : null,
      ),
      title: const Text(
        'Profile Photo',
        style: TextStyle(color: MonoPulseColors.textPrimary),
      ),
      subtitle: Text(
        photoPath != null ? 'Tap to change' : 'Tap to add',
        style: const TextStyle(color: MonoPulseColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.camera_alt,
        color: MonoPulseColors.accentOrange,
      ),
      onTap: onPhotoTap,
    );
  }
}

/// Sign out button for settings footer.
class SignOutButton extends StatelessWidget {
  /// Callback when sign out is pressed.
  final VoidCallback onPressed;

  const SignOutButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: MonoPulseColors.borderStrong,
          foregroundColor: MonoPulseColors.textPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.lg,
            vertical: MonoPulseSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          ),
        ),
        child: Text(
          'Sign Out',
          style: MonoPulseTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
