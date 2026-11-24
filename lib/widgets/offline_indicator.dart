import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/mono_pulse_theme.dart';
import '../services/connectivity_service.dart';
import 'app_badge.dart';

/// Offline Indicator Widget - Shows connectivity status
///
/// Three variants:
/// - banner: Full-width banner at top (only shows when offline)
/// - chip: Small chip indicator (only shows when offline)
/// - minimal: Icon-only indicator (only shows when offline)
class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator.banner({super.key})
    : variant = OfflineIndicatorVariant.banner;

  const OfflineIndicator.chip({super.key})
    : variant = OfflineIndicatorVariant.chip;

  const OfflineIndicator.minimal({super.key})
    : variant = OfflineIndicatorVariant.minimal;
  final OfflineIndicatorVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(offlineProvider);

    // Don't show anything when online
    if (!isOffline) {
      return const SizedBox.shrink();
    }

    switch (variant) {
      case OfflineIndicatorVariant.banner:
        return _buildBanner(context);
      case OfflineIndicatorVariant.chip:
        return _buildChip(context);
      case OfflineIndicatorVariant.minimal:
        return _buildMinimal(context);
    }
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MonoPulseSpacing.sm),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrange10,
        border: Border.all(color: MonoPulseColors.accentOrange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off,
            color: MonoPulseColors.accentOrange,
            size: 20,
          ),
          const SizedBox(width: MonoPulseSpacing.sm),
          Text(
            'Offline - Some features may be limited',
            style: MonoPulseTypography.bodySmall.copyWith(
              color: context.mp.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context) {
    return const AppBadge(
      label: 'Offline',
      icon: Icons.wifi_off,
      outlined: true,
    );
  }

  Widget _buildMinimal(BuildContext context) {
    return const Icon(
      Icons.wifi_off,
      color: MonoPulseColors.accentOrange,
      size: 20,
    );
  }
}

enum OfflineIndicatorVariant { banner, chip, minimal }
