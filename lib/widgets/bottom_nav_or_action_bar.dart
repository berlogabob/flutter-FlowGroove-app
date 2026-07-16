import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../theme/mono_pulse_theme.dart';

/// One navigation destination, shared by the portrait bottom bar and the
/// landscape rail (Mono Pulse: "nav moves to a side rail").
typedef AppNavItem = ({IconData icon, IconData selectedIcon, String label});

/// The bottom bar / rail, in one of two mutually exclusive modes:
///
/// - [AppBottomBar.tabs]: the 4 branch tabs + a Menu slot (opens a bottom
///   sheet, never navigates). Shown while on one of the 5 branch roots.
/// - [AppBottomBar.actions]: `[← Back] [title | primaryAction] [⋮ Menu]`.
///   Shown for any pushed route — both branch children (e.g. edit-song) and
///   root-pushed tools (Metronome/Tuner/Join Band).
///
/// Both modes share the same height/padding/border chrome so switching
/// between them doesn't jump the layout.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar.tabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabTap,
    this.onMenuTap,
    this.menuSelected = false,
    this.menuHasBadge = false,
    super.key,
  }) : _isTabs = true,
       onBack = null,
       title = null,
       primaryAction = null,
       onMenu = null;

  const AppBottomBar.actions({
    required this.onBack,
    this.title,
    this.primaryAction,
    this.onMenu,
    super.key,
  }) : _isTabs = false,
       tabs = const [],
       selectedIndex = 0,
       onTabTap = null,
       onMenuTap = null,
       menuSelected = false,
       menuHasBadge = false;

  final bool _isTabs;

  // .tabs mode
  final List<AppNavItem> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onTabTap;
  final VoidCallback? onMenuTap;
  final bool menuSelected;
  final bool menuHasBadge;

  // .actions mode
  final VoidCallback? onBack;
  final String? title;
  final Widget? primaryAction;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.mp.black,
        border: Border(top: BorderSide(color: context.mp.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.sm,
            vertical: MonoPulseSpacing.sm,
          ),
          child: _isTabs ? _buildTabs() : _buildActions(context),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(
            child: NavTab(
              item: tabs[i],
              selected: i == selectedIndex,
              onTap: () => onTabTap?.call(i),
            ),
          ),
        Expanded(
          child: NavTab(
            item: const (
              icon: Icons.more_horiz,
              selectedIcon: Icons.more_horiz,
              label: 'Menu',
            ),
            selected: menuSelected,
            showBadge: menuHasBadge,
            onTap: onMenuTap ?? () {},
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: NavTab(
            item: const (
              icon: Icons.arrow_back,
              selectedIcon: Icons.arrow_back,
              label: 'Back',
            ),
            selected: false,
            // Single central place for the in-app Back tap: logs
            // back_used{source: 'ui'} before running the screen's own
            // callback (system back — PopScope etc. — logs separately).
            onTap: () {
              AnalyticsService.logBackUsed(source: 'ui');
              (onBack ?? () {})();
            },
          ),
        ),
        Expanded(
          flex: 2,
          // heightFactor keeps the Center from expanding vertically: the
          // Scaffold gives bottomNavigationBar loose height constraints, and
          // an unbounded Center would balloon the bar to fill the screen.
          child: Center(
            heightFactor: 1,
            child: primaryAction != null
                // Scale an oversized primary action (e.g. a full button) down
                // to the slot instead of overflowing on narrow screens.
                ? FittedBox(fit: BoxFit.scaleDown, child: primaryAction)
                : (title == null || title!.isEmpty
                      ? const SizedBox.shrink()
                      : Semantics(
                          label: title,
                          child: Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: MonoPulseTypography.labelLarge.copyWith(
                              color: context.mp.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )),
          ),
        ),
        Expanded(
          child: onMenu == null
              ? const SizedBox.shrink()
              : NavTab(
                  item: const (
                    icon: Icons.more_horiz,
                    selectedIcon: Icons.more_horiz,
                    label: 'Menu',
                  ),
                  selected: false,
                  onTap: onMenu!,
                ),
        ),
      ],
    );
  }
}

/// A single nav/action tab (Mono Pulse): icon on top, label below. When
/// selected the icon + label turn orange and the label gets a rounded pill
/// background. Shared by [AppBottomBar]'s tabs mode, its actions mode
/// (Back/Menu buttons), and the landscape rail. Keeps a >=48px tap target.
class NavTab extends StatelessWidget {
  const NavTab({
    required this.item,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
    super.key,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  /// Small dot shown near the icon (Menu slot: current screen published
  /// contextual actions).
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? MonoPulseColors.accentOrange
        : context.mp.textTertiary;

    final label = Text(
      item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MonoPulseTypography.labelSmall.copyWith(
        color: color,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: color,
                    size: 22,
                  ),
                  if (showBadge)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: MonoPulseColors.accentOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: MonoPulseSpacing.xs),
              // Pill behind the label only when selected (per the doc's tab bar).
              DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? MonoPulseColors.accentOrange15
                      : MonoPulseColors.transparent,
                  borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MonoPulseSpacing.sm,
                    vertical: MonoPulseSpacing.xxs,
                  ),
                  child: label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
