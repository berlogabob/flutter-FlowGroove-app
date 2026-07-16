import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth/auth_provider.dart';
import '../services/analytics_service.dart';
import '../theme/mono_pulse_theme.dart';
import 'user_avatar.dart';

/// One row in an [showAppMenuSheet] bottom sheet.
///
/// Rows with [trailing] (e.g. a live `Switch`) do NOT auto-close the sheet on
/// tap — the trailing widget itself owns the interaction (its own
/// `onChanged`), so the sheet can stay open while the user flips a few
/// settings in a row (Metronome's Haptics, Tuner's Stage Mode). Rows without
/// [trailing] close the sheet first, then run [onTap] on the next frame (this
/// mirrors the old `_runAfterMenuCloses` pattern screens used with
/// `PopupMenuItem`, so a dialog/navigation triggered by [onTap] doesn't race
/// the sheet's own closing animation).
class AppMenuItem {
  const AppMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? trailing;
}

/// The app-wide contextual action sheet, opened from the bottom bar's Menu
/// slot (root mode: a tab; pushed mode: the `⋮` button). Styled after
/// `showSupportSheet` — dark theme, rounded top corners, `SafeArea`.
///
/// A header row with [title] is always shown. When [showProfileRow] is true
/// (root mode only — pushed-mode sheets don't offer it, the bottom bar
/// already shows the Back affordance), a divider + a Profile row is appended;
/// tapping it closes the sheet and navigates to the Profile branch.
Future<void> showAppMenuSheet(
  BuildContext context, {
  required String title,
  required List<AppMenuItem> items,
  bool showProfileRow = false,
  WidgetRef? ref,
}) {
  AnalyticsService.logMenuOpened(screen: title);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: MonoPulseColors.blackSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MonoPulseRadius.xlarge),
      ),
    ),
    builder: (sheetContext) {
      // StatefulBuilder gives room for future in-sheet local-state toggles.
      // The two current live-toggle use cases (Metronome Haptics, Tuner
      // Stage Mode) are Riverpod-backed, so their `trailing` widgets are
      // small ConsumerWidgets that rebuild themselves via `ref.watch` —
      // no `setSheetState` call is required for those, but it's here so a
      // future non-Riverpod toggle has a safe, local way to rebuild.
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MonoPulseSpacing.lg,
                    MonoPulseSpacing.lg,
                    MonoPulseSpacing.lg,
                    MonoPulseSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MonoPulseTypography.titleLarge.copyWith(
                            color: MonoPulseColors.textHighEmphasis,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: MonoPulseColors.borderSubtle),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final item in items)
                        _AppMenuRow(item: item, sheetContext: sheetContext),
                      if (showProfileRow) ...[
                        const Divider(
                          height: 1,
                          color: MonoPulseColors.borderSubtle,
                        ),
                        _ProfileRow(ref: ref, sheetContext: sheetContext),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _AppMenuRow extends StatelessWidget {
  const _AppMenuRow({required this.item, required this.sheetContext});

  final AppMenuItem item;
  final BuildContext sheetContext;

  @override
  Widget build(BuildContext context) {
    final hasTrailing = item.trailing != null;
    final enabled = hasTrailing || item.onTap != null;
    final color = item.destructive
        ? MonoPulseColors.error
        : enabled
        ? MonoPulseColors.textHighEmphasis
        : MonoPulseColors.textTertiary;

    return ListTile(
      enabled: enabled,
      leading: Icon(
        item.icon,
        size: 20,
        color: item.destructive ? MonoPulseColors.error : null,
      ),
      title: Text(
        item.label,
        style: MonoPulseTypography.bodyMedium.copyWith(color: color),
      ),
      trailing: item.trailing,
      onTap: item.onTap == null
          ? null
          : hasTrailing
          // Trailing rows (live toggles) stay open: run the action in place
          // so the user can flip several settings without reopening.
          ? item.onTap
          : () {
              Navigator.of(sheetContext).pop();
              final onTap = item.onTap!;
              WidgetsBinding.instance.addPostFrameCallback((_) => onTap());
            },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.ref, required this.sheetContext});

  final WidgetRef? ref;
  final BuildContext sheetContext;

  @override
  Widget build(BuildContext context) {
    String? displayName;
    String? photoURL;
    // Defensive: appUserProvider may not have resolved yet (or ref may be
    // null when the sheet was opened outside a ConsumerWidget) — fall back
    // to a generic "Profile" row rather than throwing.
    final currentRef = ref;
    if (currentRef != null) {
      try {
        final user = currentRef.read(appUserProvider).value;
        displayName = user?.displayName;
        photoURL = user?.photoURL;
      } on Object {
        // Provider not available in this context — keep the fallback.
      }
    }

    return ListTile(
      leading: UserAvatar(
        photoURL: photoURL,
        displayName: displayName,
        radius: 16,
      ),
      title: Text(
        displayName?.isNotEmpty ?? false ? displayName! : 'Profile',
        style: MonoPulseTypography.bodyMedium.copyWith(
          color: MonoPulseColors.textHighEmphasis,
        ),
      ),
      onTap: () {
        // Resolve the router before popping — `context` (and `sheetContext`)
        // may be deactivated by the time the post-frame callback runs, but a
        // `GoRouter` instance is safe to hold onto and call later.
        final router = GoRouter.of(context);
        Navigator.of(sheetContext).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.go('/main/profile');
        });
      },
    );
  }
}
