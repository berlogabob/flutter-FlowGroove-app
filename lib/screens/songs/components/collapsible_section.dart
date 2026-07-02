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

  const CollapsibleSection({
    required this.title,
    required this.child,
    super.key,
    this.initiallyExpanded = true,
    this.action,
    this.icon,
    this.preview,
    this.inlinePreview = true,
    this.onExpandedChanged,
  });
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

  /// Optional compact preview shown while collapsed — e.g. a song-map graph,
  /// a notes snippet, or the selected tags — so a collapsed section still
  /// communicates its content at a glance.
  final Widget? preview;

  /// Whether the collapsed [preview] sits inline at the right of the header
  /// row (single line, keeps the bubble one row tall). Set false for wide
  /// previews like the song map, which render under the header instead.
  final bool inlinePreview;

  /// Callback when expansion state changes.
  final void Function(bool expanded)? onExpandedChanged;

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MonoPulseColors.surface,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderDefault),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MonoPulseSpacing.lg,
                vertical: MonoPulseSpacing.md,
              ),
              child: Row(
                children: [
                  // Expand/collapse icon
                  AnimatedRotation(
                    turns: _isExpanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.icon ?? Icons.keyboard_arrow_down,
                      color: MonoPulseColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Title (compact — leaves room for the collapsed preview).
                  Text(
                    widget.title,
                    style: MonoPulseTypography.titleMedium.copyWith(
                      color: MonoPulseColors.textPrimary,
                    ),
                  ),
                  // Inline collapsed preview, right-aligned on the SAME line
                  // as the title so the collapsed bubble stays one row tall.
                  Expanded(
                    child:
                        !_isExpanded &&
                            widget.preview != null &&
                            widget.inlinePreview
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: widget.preview,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  // Action button
                  if (widget.action != null) ...[
                    const SizedBox(width: 8),
                    widget.action!,
                  ],
                ],
              ),
            ),
          ),
          // Wide preview under the header while collapsed.
          if (widget.preview != null && !widget.inlinePreview)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        MonoPulseSpacing.lg,
                        0,
                        MonoPulseSpacing.lg,
                        MonoPulseSpacing.lg,
                      ),
                      child: widget.preview,
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
                  vertical: MonoPulseSpacing.sm,
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
