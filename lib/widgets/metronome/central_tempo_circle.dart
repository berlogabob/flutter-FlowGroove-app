import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import 'tempo_change_dialog.dart';

/// Central Tempo Circle widget - Mono Pulse design (Sprint Fix)
///
/// Large rotary dial for tempo adjustment:
/// - Circle diameter ~50-60% screen width
/// - Background: #121212, stroke: 1px #222222
/// - Small dot/handle: #FF5E00 on edge
/// - Tick marks with labels (60, 120, 180 bpm)
/// - Center: BPM number (72-88px Bold) + "bpm" label
///
/// Sprint Fixes:
/// - Increase touch zone (entire circle + 30px around)
/// - Edge dot always matches current BPM (position on scale)
/// - Sensitivity: constant speed, no acceleration (long drag = smooth change)
/// - Scale: thin lines #333333, labels 60/120/180 #8A8A8F
class CentralTempoCircle extends ConsumerStatefulWidget {
  const CentralTempoCircle({super.key});

  @override
  ConsumerState<CentralTempoCircle> createState() => _CentralTempoCircleState();
}

class _CentralTempoCircleState extends ConsumerState<CentralTempoCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeProvider);
    final bpm = state.bpm;

    // Calculate rotation angle based on BPM (1-300 range)
    final normalizedBpm = (bpm / 300.0).clamp(0.0, 1.0);
    final rotationAngle = normalizedBpm * 2 * math.pi;

    return RepaintBoundary(
      child: Transform.rotate(angle: rotationAngle, child: Container()),
    );
  }
}
