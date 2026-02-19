import 'package:flutter/material.dart';

/// A widget for entering BPM (Beats Per Minute) value.
///
/// This widget provides a text field specifically designed for
/// entering tempo values with numeric keyboard and validation.
class BpmSelector extends StatelessWidget {
  /// Controller for the BPM text field.
  final TextEditingController controller;

  /// Optional label displayed above the field.
  final String? label;

  /// Hint text shown when field is empty.
  final String? hintText;

  /// Callback when BPM value changes.
  final ValueChanged<String>? onChanged;

  const BpmSelector({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.onChanged,
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
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'BPM',
            hintText: hintText,
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// A combined widget for selecting key and BPM together.
///
/// This is useful for song forms where key and tempo are related.
class KeyBpmSelector extends StatelessWidget {
  /// The selected base note.
  final String base;

  /// The selected modifier.
  final String modifier;

  /// Controller for the BPM field.
  final TextEditingController bpmController;

  /// Label for this selector group.
  final String label;

  /// Callback when key selection changes.
  final Function(String base, String modifier) onKeyChanged;

  /// Available base notes.
  final List<String> keyBases;

  /// Available modifiers.
  final List<String> keyModifiers;

  const KeyBpmSelector({
    super.key,
    required this.base,
    required this.modifier,
    required this.bpmController,
    required this.label,
    required this.onKeyChanged,
    this.keyBases = const ['C', 'D', 'E', 'F', 'G', 'A', 'B'],
    this.keyModifiers = const ['', '#', 'b', 'm'],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        ),
        const SizedBox(height: 4),
        IntrinsicHeight(
          child: Row(
            children: [
              _buildMiniDropdown(
                base,
                keyBases,
                (v) => onKeyChanged(v ?? 'C', modifier),
              ),
              const SizedBox(width: 4),
              _buildMiniDropdown(
                modifier,
                keyModifiers,
                (v) => onKeyChanged(base, v ?? ''),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: bpmController,
                  decoration: const InputDecoration(
                    labelText: 'BPM',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
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
