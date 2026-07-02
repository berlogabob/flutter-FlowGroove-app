/// Role picker modal widget for selecting music roles.
///
/// Features:
/// - Search field with real-time filtering
/// - Popular roles grid (adaptive column count)
/// - Custom role input
/// - Selected roles as removable chips
/// - Responsive layout (2-5 columns based on screen width)
library;

import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/music_role_icon.dart';

/// Modal dialog for picking music roles.
///
/// Returns the updated list of role keys, or null if cancelled.
Future<List<String>?> showRolePicker({
  required BuildContext context,
  required List<String> currentRoles,
  String? title,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => RolePickerDialog(
      currentRoles: currentRoles,
      title: title,
    ),
  );
}

/// Role picker dialog.
class RolePickerDialog extends StatefulWidget {

  const RolePickerDialog({
    required this.currentRoles,
    super.key,
    this.title,
  });
  final List<String> currentRoles;
  final String? title;

  @override
  State<RolePickerDialog> createState() => _RolePickerDialogState();
}

class _RolePickerDialogState extends State<RolePickerDialog> {
  late List<String> _selectedRoles;
  String _searchQuery = '';
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedRoles = List.from(widget.currentRoles);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _toggleRole(String role) {
    setState(() {
      if (_selectedRoles.contains(role)) {
        _selectedRoles.remove(role);
      } else {
        _selectedRoles.add(role);
      }
    });
  }

  void _addCustomRole(String role) {
    final trimmed = role.trim();
    if (trimmed.isEmpty || _selectedRoles.contains(trimmed)) {
      return;
    }
    setState(() {
      _selectedRoles.add(trimmed);
      _textController.clear();
      _searchQuery = '';
    });
  }

  List<String> get _filteredPopular {
    if (_searchQuery.isEmpty) return MusicRoleIcon.popularRoles;
    final query = _searchQuery.toLowerCase();
    return MusicRoleIcon.popularRoles
        .where((r) => MusicRoleIcon.getDisplayName(r).toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AlertDialog(
      title: Text(widget.title ?? 'Select Roles'),
      content: SizedBox(
        width: min(screenWidth * 0.9, 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search field
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Search or type new role...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _textController.clear();
                          setState(() => _searchQuery = '');
                        },
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MonoPulseRadius.small),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _addCustomRole(value.trim());
                }
              },
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: MonoPulseSpacing.sm),

            // Selected roles
            if (_selectedRoles.isNotEmpty) ...[
              Text(
                'Selected:',
                style: MonoPulseTypography.labelSmall.copyWith(
                  color: MonoPulseColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedRoles.map((role) {
                  final icon = MusicRoleIcon.getIcon(role);
                  final displayName = MusicRoleIcon.getDisplayName(role);
                  return InputChip(
                    label: Text(icon != null ? '$icon $displayName' : displayName),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _toggleRole(role),
                    selected: true,
                    onSelected: (_) => _toggleRole(role),
                    backgroundColor: MonoPulseColors.accentOrange10,
                    selectedColor: MonoPulseColors.accentOrange10,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
              const SizedBox(height: MonoPulseSpacing.sm),
            ],

            // Popular roles grid
            Text(
              'Popular roles:',
              style: MonoPulseTypography.labelSmall.copyWith(
                color: MonoPulseColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            if (_filteredPopular.isEmpty && _searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No matching popular roles.\nType above to add custom role.',
                    textAlign: TextAlign.center,
                    style: MonoPulseTypography.bodySmall.copyWith(
                      color: MonoPulseColors.textTertiary,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _filteredPopular.map((role) {
                  final icon = MusicRoleIcon.getIcon(role);
                  final displayName = MusicRoleIcon.getDisplayName(role);
                  final isSelected = _selectedRoles.contains(role);
                  return GestureDetector(
                    onTap: () => _toggleRole(role),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? MonoPulseColors.accentOrange10
                            : MonoPulseColors.surfaceOverlay,
                        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                        border: Border.all(
                          color: isSelected
                              ? MonoPulseColors.accentOrange
                              : MonoPulseColors.textTertiary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) Text(icon, style: const TextStyle(fontSize: 16)),
                          if (icon != null) const SizedBox(width: 4),
                          Text(
                            displayName,
                            style: MonoPulseTypography.bodySmall.copyWith(
                              color: isSelected
                                  ? MonoPulseColors.accentOrange
                                  : MonoPulseColors.textHighEmphasis,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedRoles),
          style: ElevatedButton.styleFrom(
            backgroundColor: MonoPulseColors.accentOrange,
            foregroundColor: MonoPulseColors.textPrimary,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
