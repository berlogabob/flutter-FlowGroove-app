import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/mono_pulse_theme.dart';
import '../services/connectivity_service.dart';

/// Offline Indicator Widget - Shows connectivity status
///
/// Three variants:
/// - banner: Full-width banner at top (only shows when offline)
/// - chip: Small chip indicator (only shows when offline)
/// - minimal: Icon-only indicator (only shows when offline)
class OfflineIndicator extends ConsumerWidget {
  final OfflineIndicatorVariant variant;

  const OfflineIndicator.banner({super.key})
    : variant = OfflineIndicatorVariant.banner;

  const OfflineIndicator.chip({super.key})
    : variant = OfflineIndicatorVariant.chip;

  const OfflineIndicator.minimal({super.key})
    : variant = OfflineIndicatorVariant.minimal;

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrangeSubtle,
        border: Border.all(color: MonoPulseColors.accentOrange),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: MonoPulseColors.accentOrange, size: 20),
          SizedBox(width: 8),
          Text(
            'Offline - Some features may be limited',
            style: TextStyle(
              color: MonoPulseColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrangeSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MonoPulseColors.accentOrange),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, color: MonoPulseColors.accentOrange, size: 16),
          SizedBox(width: 6),
          Text(
            'Offline',
            style: TextStyle(
              color: MonoPulseColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
