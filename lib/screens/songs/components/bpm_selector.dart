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
    // '#m' and 'bm' are required, not decorative: a single mutually-exclusive
    // modifier slot cannot express Abm / Bbm / C#m, so those keys either crashed
    // the dropdown or lost their accidental on round trip.
    this.keyModifiers = const ['', '#', 'b', 'm', '#m', 'bm'],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(
          context,
          'Original version',
          originalBase,
          originalModifier,
          originalBpmController,
          onOriginalKeyChanged,
        ),
        const SizedBox(height: MonoPulseSpacing.sm),
        _row(
          context,
          'Our version',
          ourBase,
          ourModifier,
          ourBpmController,
          onOurKeyChanged,
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String base,
    String modifier,
    TextEditingController bpm,
    void Function(String, String) onKey,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MonoPulseTypography.labelMedium),
        const SizedBox(height: MonoPulseSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Root', style: MonoPulseTypography.labelMedium),
                  const SizedBox(height: MonoPulseSpacing.xs),
                  _keyMiniDropdown(
                    context,
                    base,
                    keyBases,
                    (v) => onKey(v ?? '', modifier),
                  ),
                ],
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Accidental / quality', style: MonoPulseTypography.labelMedium),
                  const SizedBox(height: MonoPulseSpacing.xs),
                  _keyMiniDropdown(
                    context,
                    modifier,
                    keyModifiers,
                    (v) => onKey(base, v ?? ''),
                  ),
                ],
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: bpm,
                decoration: const InputDecoration(labelText: 'BPM', isDense: true),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
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
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm),
    decoration: BoxDecoration(
      color: context.mp.surfaceRaised,
      borderRadius: BorderRadius.circular(MonoPulseRadius.small),
      border: Border.all(color: context.mp.borderDefault),
    ),
    child: DropdownButton<String>(
      // DropdownButton asserts that `value` matches exactly one item, so an
      // unexpected value is a crash, not a cosmetic glitch. Imports can deliver
      // anything, so fall back to unset rather than take the app down. null is
      // used rather than '' because a caller may pass an item list without it.
      value: items.contains(value) ? value : null,
      isExpanded: true,
      isDense: false,
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
