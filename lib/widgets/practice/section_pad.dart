import 'package:flutter/material.dart';

import '../../theme/mono_pulse_theme.dart';
import '../../utils/pad_state.dart';
import '../../utils/play_mode.dart';

class SectionPad extends StatelessWidget {
  const SectionPad({
    required this.name,
    required this.bars,
    required this.color,
    required this.state,
    required this.onTap,
    super.key,
    this.onLongPress,
    this.mode = PlayMode.once,
    this.queuedLabel = 'Next bar',
  });

  final String name;
  final int bars;
  final Color color;
  final PadState state;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final PlayMode mode;
  final String queuedLabel;

  @override
  Widget build(BuildContext context) {
    final playing = state == PadState.playing;
    final foreground = playing
        ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
              ? MonoPulseColors.white
              : MonoPulseColors.black)
        : context.mp.textPrimary;
    final radius = BorderRadius.circular(MonoPulseRadius.large);

    return Semantics(
      label:
          '$name, ${state == PadState.queued ? 'Starts ${queuedLabel.toLowerCase()}' : padStateLabel(state)}',
      button: true,
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Material(
            color: playing ? color : context.mp.blackSurface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: state == PadState.queued
                    ? MonoPulseColors.transparent
                    : color,
                width: MonoPulseBorder.bold,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 96),
                child: Padding(
                  padding: const EdgeInsets.all(MonoPulseSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: MonoPulseTypography.bodyLarge.copyWith(
                          color: foreground,
                        ),
                      ),
                      Text(
                        bars == 1 ? '1 bar' : '$bars bars',
                        style: MonoPulseTypography.bodySmall.copyWith(
                          color: playing
                              ? foreground
                              : context.mp.textSecondary,
                        ),
                      ),
                      const SizedBox(height: MonoPulseSpacing.xs),
                      Wrap(
                        spacing: MonoPulseSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (playing) ...[
                            Icon(
                              Icons.play_arrow,
                              size: MonoPulseIcons.sizeSmall,
                              color: foreground,
                            ),
                            if (mode != PlayMode.once)
                              Icon(
                                mode == PlayMode.loop
                                    ? Icons.loop
                                    : Icons.queue_music,
                                size: MonoPulseIcons.sizeSmall,
                                color: foreground,
                              ),
                          ],
                          Text(
                            state == PadState.queued
                                ? queuedLabel
                                : padStateLabel(state),
                            style: MonoPulseTypography.labelSmall.copyWith(
                              color: foreground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (state == PadState.queued)
            Positioned.fill(child: _PulsingOutline(color: color)),
        ],
      ),
    );
  }
}

class _PulsingOutline extends StatefulWidget {
  const _PulsingOutline({required this.color});

  final Color color;

  @override
  State<_PulsingOutline> createState() => _PulsingOutlineState();
}

class _PulsingOutlineState extends State<_PulsingOutline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MonoPulseAnimation.durationLong * 3,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            border: Border.all(
              color: widget.color.withValues(
                alpha: 0.4 + _controller.value * 0.6,
              ),
              width: MonoPulseBorder.bold,
            ),
          ),
        ),
      ),
    );
  }
}
