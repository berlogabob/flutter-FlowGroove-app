import 'package:flutter/material.dart';

import '../theme/mono_pulse_theme.dart';

/// Shows a MonoPulse-styled snackbar with [message].
///
/// Pass [error]: true for error styling. Pass [actionLabel] and [onAction] to
/// render a snackbar action (e.g., for single-level undo). When an action is
/// provided, the snackbar duration is ~5s; otherwise it uses the default.
/// Replaces the ~scores of inline
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))`
/// call sites.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? MonoPulseColors.error : null,
        duration: actionLabel != null
            ? const Duration(seconds: 5)
            : const Duration(seconds: 4),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
              )
            : null,
      ),
    );
}
