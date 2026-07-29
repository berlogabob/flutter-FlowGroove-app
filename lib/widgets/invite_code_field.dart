import 'package:flutter/material.dart';

import '../theme/mono_pulse_theme.dart';

/// Dark, monospaced, high-contrast display for a band invite code.
///
/// Fixes the white-on-white invite field (Mono Pulse audit A1). Presentational
/// only — callers supply their own copy / share / regenerate actions around it.
class InviteCodeField extends StatelessWidget {
  const InviteCodeField({required this.code, this.placeholder, super.key});

  final String code;

  /// Dimmed text shown when [code] is empty (e.g. while regenerating).
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final isEmpty = code.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.lg,
        vertical: MonoPulseSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.mp.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: context.mp.borderDefault),
      ),
      child: Text(
        isEmpty ? (placeholder ?? '') : code,
        textAlign: TextAlign.center,
        style:
            const TextStyle(
              fontFamily: 'monospace',
              fontSize: 26,
              fontWeight: FontWeight.w600,
              // Letter-spacing pushes a trailing gap; the leading indent balances it
              // so centered text stays visually centered.
              letterSpacing: 8,
            ).copyWith(
              color: isEmpty ? context.mp.textTertiary : context.mp.textPrimary,
            ),
      ),
    );
  }
}
