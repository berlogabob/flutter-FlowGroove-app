import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../theme/mono_pulse_theme.dart';

/// Shows a MonoPulse-styled snackbar with [message].
///
/// Pass [error]: true for error styling. Pass [actionLabel] and [onAction] to
/// render a snackbar action (e.g., for single-level undo). When an action is
/// provided, the snackbar duration is ~5s; otherwise it uses the default.
/// Replaces the ~scores of inline
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))`
/// call sites.
///
/// [analyticsAction] is an optional short id (e.g. 'section_delete') logged
/// as `undo_shown`/`undo_used` when an action is present — callers that don't
/// pass it skip analytics for that snackbar (not every actioned snackbar is
/// an undo).
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
  String? actionLabel,
  VoidCallback? onAction,
  String? analyticsAction,
}) {
  if (actionLabel != null && analyticsAction != null) {
    AnalyticsService.logUndoShown(action: analyticsAction);
  }
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
                onPressed: () {
                  if (analyticsAction != null) {
                    AnalyticsService.logUndoUsed(action: analyticsAction);
                  }
                  onAction();
                },
              )
            : null,
      ),
    );
}
