import 'package:flutter/material.dart';

import '../../models/midi_pattern.dart';
import '../../services/audio/midi/drum_map.dart';

class DrumKitView extends StatefulWidget {
  const DrumKitView({
    required this.currentStep,
    required this.pattern,
    required this.muted,
    required this.solo,
    required this.onToggleMute,
    required this.onToggleSolo,
    super.key,
  });

  final int currentStep;
  final MidiPattern pattern;
  final Set<DrumLane> muted;
  final DrumLane? solo;
  final ValueChanged<DrumLane> onToggleMute;
  final ValueChanged<DrumLane> onToggleSolo;

  @override
  State<DrumKitView> createState() => _DrumKitViewState();
}

class _DrumKitViewState extends State<DrumKitView>
    with SingleTickerProviderStateMixin {
  late final _decay = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );

  @override
  void initState() {
    super.initState();
    _decay.forward();
  }

  @override
  void didUpdateWidget(DrumKitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep ||
        oldWidget.pattern != widget.pattern) {
      _decay.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _decay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final steps = widget.pattern.totalSteps;
    final current = steps > 0 ? widget.currentStep % steps : -1;
    final hits = <DrumLane, Set<int>>{};
    for (final hit in widget.pattern.hits) {
      final lane = laneForNote(hit.note);
      if (lane != null && hit.vel > 0 && hit.step >= 0 && hit.step < steps) {
        hits.putIfAbsent(lane, () => <int>{}).add(hit.step);
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: AspectRatio(
              aspectRatio: 1.5,
              child: AnimatedBuilder(
                animation: _decay,
                builder: (context, child) => CustomPaint(
                  key: const Key('drum-kit'),
                  painter: DrumKitPainter(
                    active: {
                      for (final lane in hits.keys)
                        if (hits[lane]!.contains(current)) lane,
                    },
                    flash: 1 - _decay.value,
                    colors: colors,
                  ),
                ),
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lane in DrumLane.values)
              if (hits.containsKey(lane))
                Row(
                  key: ValueKey('lane-${lane.name}'),
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        laneLabel(lane),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    for (var offset = 0; offset < 16; offset++)
                      Expanded(
                        child: Center(
                          child: Semantics(
                            label:
                                '${laneLabel(lane)} step ${(current + offset) % steps + 1}',
                            value:
                                hits[lane]!.contains((current + offset) % steps)
                                ? 'Hit'
                                : 'Rest',
                            selected: offset == 0,
                            child: Container(
                              key: ValueKey('dot-${lane.name}-$offset'),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    hits[lane]!.contains(
                                      (current + offset) % steps,
                                    )
                                    ? colors.primary
                                    : null,
                                border: Border.all(
                                  color: offset == 0
                                      ? colors.tertiary
                                      : colors.outline,
                                  width: offset == 0 ? 2 : 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    _chip(
                      lane,
                      'M',
                      widget.muted.contains(lane),
                      widget.onToggleMute,
                    ),
                    _chip(lane, 'S', widget.solo == lane, widget.onToggleSolo),
                  ],
                ),
          ],
        ),
      ],
    );
  }

  Widget _chip(
    DrumLane lane,
    String label,
    bool selected,
    ValueChanged<DrumLane> onToggle,
  ) {
    return SizedBox(
      width: 48,
      height: 48,
      child: FilterChip(
        key: ValueKey('$label-${lane.name}'),
        label: Text(label),
        tooltip: '${label == 'M' ? 'Mute' : 'Solo'} ${laneLabel(lane)}',
        selected: selected,
        showCheckmark: false,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onSelected: (_) => onToggle(lane),
      ),
    );
  }
}

class DrumKitPainter extends CustomPainter {
  DrumKitPainter({
    required this.active,
    required this.flash,
    required this.colors,
  });

  final Set<DrumLane> active;
  final double flash;
  final ColorScheme colors;

  static const _pads = <DrumLane, (double, double, double)>{
    DrumLane.kick: (0.50, 0.68, 0.17),
    DrumLane.snare: (0.26, 0.66, 0.11),
    DrumLane.hatClosed: (0.10, 0.42, 0.09),
    DrumLane.hatOpen: (0.10, 0.67, 0.09),
    DrumLane.tomHigh: (0.36, 0.30, 0.10),
    DrumLane.tomMid: (0.60, 0.30, 0.11),
    DrumLane.tomFloor: (0.79, 0.68, 0.12),
    DrumLane.crash: (0.13, 0.17, 0.10),
    DrumLane.ride: (0.85, 0.23, 0.12),
  };

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in _pads.entries) {
      final (x, y, radius) = entry.value;
      final strength = active.contains(entry.key) ? flash : 0.0;
      final center = Offset(size.width * x, size.height * y);
      final scaledRadius = size.height * radius * (1 + strength * 0.15);
      canvas
        ..drawCircle(
          center,
          scaledRadius,
          Paint()
            ..color = Color.lerp(
              colors.surfaceContainerHigh,
              colors.primary,
              strength,
            )!,
        )
        ..drawCircle(
          center,
          scaledRadius,
          Paint()
            ..color = colors.outline
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      final label = TextPainter(
        text: TextSpan(
          text: lanePadLabel(entry.key),
          style: TextStyle(
            color: strength > 0.5 ? colors.onPrimary : colors.onSurface,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      label
        ..layout()
        ..paint(canvas, center - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(DrumKitPainter oldDelegate) =>
      active != oldDelegate.active ||
      flash != oldDelegate.flash ||
      colors != oldDelegate.colors;
}
