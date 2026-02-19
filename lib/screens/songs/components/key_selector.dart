import 'package:flutter/material.dart';

/// A widget for selecting musical key with base note and modifier.
///
/// This widget provides a compact UI for selecting a musical key using
/// dropdown selectors for the base note (C, D, E, F, G, A, B) and
/// modifier (sharp, flat, minor).
class KeySelector extends StatelessWidget {
  /// The selected base note (e.g., 'C', 'D', 'E').
  final String base;

  /// The selected modifier (e.g., '', '#', 'b', 'm').
  final String modifier;

  /// Callback when key selection changes.
  ///
  /// Returns the new base and modifier values.
  final Function(String base, String modifier) onChanged;

  /// Optional label displayed above the selector.
  final String? label;

  /// Available base notes. Defaults to standard musical notes.
  final List<String> keyBases;

  /// Available modifiers. Defaults to common modifiers.
  final List<String> keyModifiers;

  const KeySelector({
    super.key,
    required this.base,
    required this.modifier,
    required this.onChanged,
    this.label,
    this.keyBases = const ['C', 'D', 'E', 'F', 'G', 'A', 'B'],
    this.keyModifiers = const ['', '#', 'b', 'm'],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
          const SizedBox(height: 4),
        ],
        IntrinsicHeight(
          child: Row(
            children: [
              _buildMiniDropdown(
                base,
                keyBases,
                (v) => onChanged(v ?? 'C', modifier),
              ),
              const SizedBox(width: 4),
              _buildMiniDropdown(
                modifier,
                keyModifiers,
                (v) => onChanged(base, v ?? ''),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniDropdown(
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        underline: const SizedBox(),
        items: items
            .map(
              (k) => DropdownMenuItem(
                value: k,
                child: Text(
                  k.isEmpty ? '-' : k,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
