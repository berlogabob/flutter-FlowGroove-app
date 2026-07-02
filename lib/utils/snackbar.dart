import 'package:flutter/material.dart';

import '../theme/mono_pulse_theme.dart';

/// Shows a MonoPulse-styled snackbar with [message].
///
/// Pass [error]: true for error styling. Replaces the ~scores of inline
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))`
/// call sites. For snackbars that need an action, custom duration, or bespoke
/// content, build the SnackBar inline instead.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? MonoPulseColors.error : null,
      ),
    );
}
