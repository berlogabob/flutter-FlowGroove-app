/// Collapsible section widget for consistent UI design.
///
/// This widget provides a standardized collapsible section with:
/// - Header with title and optional actions
/// - Expandable/collapsible content
/// - Consistent styling across the app
library;

import 'package:flutter/material.dart';
import '../../../theme/mono_pulse_theme.dart';

/// A collapsible section widget.
class CollapsibleSection extends StatefulWidget {
  /// Section title.
  final String title;

  /// Section content.
  final Widget child;

  /// Whether the section is initially expanded.
  final bool initiallyExpanded;

  /// Optional action button (e.g., copy, add).
  final Widget? action;

  /// Optional icon for the header.
  final IconData? icon;

  /// Callback when expansion state changes.
  final Function(bool expanded)? onExpandedChanged;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
    this.action,
    this.icon,
    this.onExpandedChanged,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MonoPulseColors.surface,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderDefault, width: 1),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            child: Container(
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              child: Row(
                children: [
                  // Expand/collapse icon
                  AnimatedRotation(
                    turns: _isExpanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.icon ?? Icons.keyboard_arrow_down,
                      color: MonoPulseColors.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Title
                  Expanded(
                    child: Text(
                      widget.title,
                      style: MonoPulseTypography.titleLarge.copyWith(
                        color: MonoPulseColors.textPrimary,
                      ),
                    ),
                  ),
                  // Action button
                  if (widget.action != null) ...[
                    widget.action!,
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          // Content
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Visibility(
              visible: _isExpanded,
              maintainState: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MonoPulseSpacing.lg,
                  vertical: 8,
                ),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpandedChanged?.call(_isExpanded);
  }
}
