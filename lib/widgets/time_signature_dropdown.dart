import 'package:flutter/material.dart';
import '../models/time_signature.dart';
import '../theme/app_theme.dart';

/// A dropdown widget for selecting musical time signatures.
///
/// Displays two dropdown menus side by side for selecting the numerator
/// and denominator of a time signature, formatted as "[X ▼] / [Y ▼]".
class TimeSignatureDropdown extends StatelessWidget {
  /// The current time signature value.
  final TimeSignature value;

  /// Callback when the time signature changes.
  final Function(TimeSignature) onChanged;

  const TimeSignatureDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Numerator dropdown
        _buildDropdown(
          value: value.numerator,
          items: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
          onChanged: (num) {
            if (num != null) {
              onChanged(TimeSignature(
                numerator: num,
                denominator: value.denominator,
              ));
            }
          },
        ),

        // Divider "/"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '/',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.color4,
            ),
          ),
        ),

        // Denominator dropdown
        _buildDropdown(
          value: value.denominator,
          items: [4, 8],
          onChanged: (den) {
            if (den != null) {
              onChanged(TimeSignature(
                numerator: value.numerator,
                denominator: den,
              ));
            }
          },
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required int value,
    required List<int> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.color1.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<int>(
        value: value,
        underline: const SizedBox(),
        icon: const Icon(
          Icons.arrow_drop_down,
          color: AppColors.color1,
        ),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.color4,
        ),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text('$item'),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
