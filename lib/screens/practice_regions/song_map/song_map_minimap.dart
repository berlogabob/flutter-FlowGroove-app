import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../models/audio_region.dart';
import '../../../models/section.dart';
import '../../../theme/mono_pulse_theme.dart';

/// Whole-song overview shown while zoomed into a section or part.
class SongMapMinimap extends StatelessWidget {
  const SongMapMinimap({
    required this.durationMs,
    required this.regions,
    required this.viewportStartMs,
    required this.viewportEndMs,
    required this.onSeek,
    super.key,
  });

  final int durationMs;
  final List<AudioRegion> regions;
  final int viewportStartMs;
  final int viewportEndMs;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MonoPulseSpacing.huge,
    width: double.infinity,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTapDown: (details) {
            if (durationMs <= 0 || width <= 0) return;
            onSeek(
              (details.localPosition.dx / width * durationMs)
                  .round()
                  .clamp(0, durationMs)
                  .toInt(),
            );
          },
          child: durationMs <= 0 || width <= 0
              ? const SizedBox.shrink()
              : _strip(context, width),
        );
      },
    ),
  );

  Widget _strip(BuildContext context, double width) {
    final start = viewportStartMs.clamp(0, durationMs);
    final end = viewportEndMs.clamp(start, durationMs);
    return ClipRRect(
      borderRadius: BorderRadius.circular(MonoPulseRadius.button),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: context.mp.surfaceRaised),
          for (final region in regions)
            if (region.endMs > region.startMs)
              Positioned(
                left: region.startMs.clamp(0, durationMs) / durationMs * width,
                width: (region.endMs.clamp(0, durationMs) - region.startMs.clamp(0, durationMs)) / durationMs * width,
                top: 0,
                bottom: 0,
                child: ColoredBox(color: _sectionColor(region.section ?? region.name)),
              ),
          Positioned(
            left: start / durationMs * width,
            width: (end - start) / durationMs * width,
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: context.mp.textPrimary,
                  width: MonoPulseSpacing.xxs,
                ),
                borderRadius: BorderRadius.circular(MonoPulseRadius.button),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _sectionColor(String name) {
    final base = name.trim().toLowerCase().replaceFirst(RegExp(r'\s+\d+$'), '');
    const colors = MonoPulseColors.sectionColors;
    final template = Section.templates.indexWhere((value) => value.toLowerCase() == base);
    if (template >= 0) return colors[template];
    final hash = base.codeUnits.fold(0, (value, unit) => (value * 31 + unit) & 0x7fffffff);
    return colors[hash % colors.length];
  }
}
