import 'package:flutter/material.dart';

import '../../../theme/mono_pulse_theme.dart';

/// A widget for entering BPM (Beats Per Minute) value.
///
/// This widget provides a text field specifically designed for
/// entering tempo values with numeric keyboard and validation.
class BpmSelector extends StatelessWidget {
  const BpmSelector({
    required this.controller,
    this.label,
    this.hintText,
    this.onChanged,
    super.key,
  });

  /// Controller for the BPM text field.
  final TextEditingController controller;

  /// Optional label displayed above the field.
  final String? label;

  /// Hint text shown when field is empty.
  final String? hintText;

  /// Callback when BPM value changes.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: MonoPulseTypography.labelMedium),
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

/// A compact, column-aligned grid for the Original and Our key + BPM together.
/// Both rows share the same columns (note · accidental · BPM) so they line up as
/// a clear grid — used inside a single "Key & BPM" collapsible bubble.
class KeyBpmGrid extends StatelessWidget {
  const KeyBpmGrid({
    required this.originalBase,
    required this.originalModifier,
    required this.originalBpmController,
    required this.onOriginalKeyChanged,
    required this.ourBase,
    required this.ourModifier,
    required this.ourBpmController,
    required this.onOurKeyChanged,
    super.key,
    this.keyBases = const ['', 'C', 'D', 'E', 'F', 'G', 'A', 'B'],
    this.keyModifiers = const ['', '#', 'b', 'm'],
  });

  final String originalBase;
  final String originalModifier;
  final TextEditingController originalBpmController;
  final void Function(String base, String modifier) onOriginalKeyChanged;

  final String ourBase;
  final String ourModifier;
  final TextEditingController ourBpmController;
  final void Function(String base, String modifier) onOurKeyChanged;

  final List<String> keyBases;
  final List<String> keyModifiers;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
        3: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _row(
          context,
          'Original',
          originalBase,
          originalModifier,
          originalBpmController,
          onOriginalKeyChanged,
        ),
        _row(
          context,
          'Our',
          ourBase,
          ourModifier,
          ourBpmController,
          onOurKeyChanged,
        ),
      ],
    );
  }

  TableRow _row(
    BuildContext context,
    String label,
    String base,
    String modifier,
    TextEditingController bpm,
    void Function(String, String) onKey,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: MonoPulseSpacing.sm,
            horizontal: MonoPulseSpacing.xs,
          ),
          child: Text(label, style: MonoPulseTypography.labelMedium),
        ),
        Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.xs),
          child: _keyMiniDropdown(
            context,
            base,
            keyBases,
            (v) => onKey(v ?? '', modifier),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.xs),
          child: _keyMiniDropdown(
            context,
            modifier,
            keyModifiers,
            (v) => onKey(base, v ?? ''),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.xs),
          child: TextFormField(
            controller: bpm,
            decoration: const InputDecoration(labelText: 'BPM', isDense: true),
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }
}

/// Shared compact note/accidental dropdown used by the key grid.
Widget _keyMiniDropdown(
  BuildContext context,
  String value,
  List<String> items,
  ValueChanged<String?> onChanged,
) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm),
    decoration: BoxDecoration(
      color: context.mp.surfaceRaised,
      borderRadius: BorderRadius.circular(MonoPulseRadius.small),
      border: Border.all(color: context.mp.borderDefault),
    ),
    child: DropdownButton<String>(
      value: value,
      isDense: true,
      underline: const SizedBox(),
      dropdownColor: context.mp.surfaceOverlay,
      iconEnabledColor: context.mp.textSecondary,
      items: items
          .map(
            (k) => DropdownMenuItem(
              value: k,
              child: Text(
                k.isEmpty ? '-' : k,
                style: TextStyle(fontSize: 13, color: context.mp.textPrimary),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    ),
  );
}
