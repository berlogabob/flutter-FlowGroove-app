import 'dart:io';

import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/responsive_breakpoints.dart';

/// Greeting card widget for dashboard and other screens.
///
/// Displays user greeting with avatar, name, and optional subtitle.
/// Responsive design adapts to different screen sizes.
///
/// Features:
/// - Responsive avatar sizing
/// - Adaptive typography
/// - Support for network or file-based avatar images
/// - Fallback to initial letter avatar
///
/// Usage:
/// ```dart
/// // Basic usage
/// GreetingCard(userName: 'John', subtitle: 'Ready to rock?')
///
/// // With avatar
/// GreetingCard(
///   userName: 'John',
///   avatarPath: 'https://example.com/avatar.jpg',
///   subtitle: 'Let\'s make music!',
/// )
///
/// // Compact mode for tablet/desktop
/// GreetingCard(userName: 'John', isCompact: true)
/// ```
class GreetingCard extends StatelessWidget {
  /// User name to display in greeting.
  final String userName;

  /// User avatar URL or file path (optional).
  final String? avatarPath;

  /// Subtitle text displayed below greeting (optional).
  final String? subtitle;

  /// Compact mode for tablet/desktop layouts (optional).
  final bool isCompact;

  const GreetingCard({
    super.key,
    required this.userName,
    this.isCompact = false,
    this.avatarPath,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final avatarRadius = ResponsiveSizes.avatarRadius(breakpoint);
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Container(
      padding: EdgeInsets.all(
        isCompact ? MonoPulseSpacing.md : MonoPulseSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrangeSubtle,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: MonoPulseColors.surfaceRaised,
            backgroundImage: _buildAvatarImage(),
            child: avatarPath == null || avatarPath!.isEmpty
                ? Text(
                    initial,
                    style: MonoPulseTypography.headlineSmall.copyWith(
                      color: MonoPulseColors.accentOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: avatarRadius * 0.75,
                    ),
                  )
                : null,
          ),
          SizedBox(width: isCompact ? MonoPulseSpacing.md : MonoPulseSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hello, $userName!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _getGreetingStyle(context, breakpoint),
                ),
                SizedBox(height: isCompact ? 2 : 4),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _getSubtitleStyle(context, breakpoint),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build avatar image provider from URL or file path.
  ImageProvider? _buildAvatarImage() {
    if (avatarPath == null || avatarPath!.isEmpty) return null;

    if (avatarPath!.startsWith('http')) {
      return NetworkImage(avatarPath!);
    }

    try {
      return FileImage(File(avatarPath!));
    } catch (e) {
      return null;
    }
  }

  /// Get greeting text style based on breakpoint.
  TextStyle? _getGreetingStyle(
    BuildContext context,
    ScreenBreakpoint breakpoint,
  ) {
    final baseStyle = isCompact
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.headlineSmall;

    return baseStyle?.copyWith(
      fontWeight: FontWeight.w700,
      color: MonoPulseColors.textPrimary,
      fontSize: _getGreetingFontSize(breakpoint),
      height: 1.2,
    );
  }

  /// Get subtitle text style based on breakpoint.
  TextStyle? _getSubtitleStyle(
    BuildContext context,
    ScreenBreakpoint breakpoint,
  ) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: MonoPulseColors.textTertiary,
      fontSize: _getSubtitleFontSize(breakpoint),
      height: 1.2,
    );
  }

  /// Get greeting font size based on breakpoint and compact mode.
  double _getGreetingFontSize(ScreenBreakpoint breakpoint) {
    if (isCompact) {
      switch (breakpoint) {
        case ScreenBreakpoint.mobile:
          return 14;
        case ScreenBreakpoint.tablet:
          return 16;
        case ScreenBreakpoint.desktop:
          return 18;
      }
    }

    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 16;
      case ScreenBreakpoint.tablet:
        return 18;
      case ScreenBreakpoint.desktop:
        return 20;
    }
  }

  /// Get subtitle font size based on breakpoint.
  double _getSubtitleFontSize(ScreenBreakpoint breakpoint) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 12;
      case ScreenBreakpoint.tablet:
        return 13;
      case ScreenBreakpoint.desktop:
        return 14;
    }
  }
}
