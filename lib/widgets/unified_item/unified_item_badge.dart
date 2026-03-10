import 'package:flutter/material.dart';
import '../../theme/mono_pulse_theme.dart';

class UnifiedItemBadge extends StatelessWidget {
  final String text;
  final Color color;

  const UnifiedItemBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: MonoPulseTypography.labelSmall.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
