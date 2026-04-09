/// Demo mode banner widget.
///
/// Shown at the top of the app when the current user has `accessRole == 'demo'`.
/// Communicates read-only status and encourages sign-up for full access.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Banner that shows demo mode status at the top of screens.
///
/// Wraps child content and shows a dismissible banner when user is in demo mode.
class DemoModeBanner extends ConsumerWidget {
  final Widget child;

  const DemoModeBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoUserProvider);
    if (!isDemo) return child;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Demo mode banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: MonoPulseColors.accentOrange.withValues(alpha: 0.15),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: MonoPulseColors.accentOrange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo mode — changes are not saved',
                    style: MonoPulseTypography.bodySmall.copyWith(
                      color: MonoPulseColors.accentOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(appUserProvider.notifier).signOut();
                    if (context.mounted) {
                      context.goNamed('login');
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: MonoPulseColors.accentOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Main content
        Expanded(child: child),
      ],
    );
  }
}
