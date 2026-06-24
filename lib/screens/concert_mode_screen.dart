import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data/metronome_provider.dart';
import '../providers/wakelock_provider.dart';
import '../theme/mono_pulse_theme.dart';

/// Full-screen "stage" view of the metronome (Mono Pulse Concert Mode).
///
/// Reuses [metronomeProvider] — it adds no audio/timing logic, only a large,
/// glanceable readout for live use: a giant BPM number, a pulsing downbeat dot,
/// a beat strip, and a big transport. Keeps the screen awake and goes immersive
/// while open, restoring both on exit.
///
/// Launched by pushing onto the root navigator from the metronome menu, so the
/// metronome screen stays mounted underneath and the provider keeps running.
class ConcertModeScreen extends ConsumerStatefulWidget {
  const ConcertModeScreen({super.key});

  @override
  ConsumerState<ConcertModeScreen> createState() => _ConcertModeScreenState();
}

class _ConcertModeScreenState extends ConsumerState<ConcertModeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: MonoPulseAnimation.durationMedium,
    );
    ref.read(wakelockProvider).enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pulse.dispose();
    // Restore the system chrome and release the wakelock. Reading the provider
    // in dispose is safe here — the controller is owned by the (still-mounted)
    // metronome screen underneath.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ref.read(wakelockProvider).disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeProvider);

    // Pulse the downbeat dot whenever the beat advances while playing.
    ref.listen<int>(metronomeProvider.select((s) => s.currentBeat), (_, _) {
      if (mounted && state.isPlaying) _pulse.forward(from: 0);
    });

    final subdivisions = state.beatModes.isNotEmpty
        ? state.beatModes.first.length.clamp(1, 64)
        : 1;
    final numerator = state.timeSignature.numerator;
    final currentMainBeat = state.isPlaying
        ? (state.currentBeat ~/ subdivisions) % numerator
        : -1;

    return Scaffold(
      backgroundColor: MonoPulseColors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: MonoPulseSpacing.sm,
              right: MonoPulseSpacing.sm,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: MonoPulseColors.textSecondary,
                ),
                iconSize: 28,
                tooltip: 'Exit Concert Mode',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
              child: OrientationBuilder(
                builder: (context, orientation) {
                  final readout = _Readout(
                    bpm: state.bpm,
                    pulse: _pulse,
                    isPlaying: state.isPlaying,
                    songTitle: state.activeSong?.title,
                  );
                  final controls = _Controls(
                    isPlaying: state.isPlaying,
                    numerator: numerator,
                    currentBeat: currentMainBeat,
                    onToggle: () =>
                        ref.read(metronomeProvider.notifier).toggle(),
                    onAdjust: (d) => ref
                        .read(metronomeProvider.notifier)
                        .adjustTempoFine(d),
                    onPrevious: state.canGoToPreviousSetlistSong
                        ? () => ref
                              .read(metronomeProvider.notifier)
                              .previousSetlistSong()
                        : null,
                    onNext: state.canGoToNextSetlistSong
                        ? () => ref
                              .read(metronomeProvider.notifier)
                              .nextSetlistSong()
                        : null,
                    hasSetlist: state.loadedSetlist != null,
                  );

                  if (orientation == Orientation.landscape) {
                    return Row(
                      children: [
                        Expanded(child: Center(child: readout)),
                        Expanded(child: Center(child: controls)),
                      ],
                    );
                  }
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [readout, controls],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Giant BPM number with a glow and a pulsing downbeat dot above it.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.bpm,
    required this.pulse,
    required this.isPlaying,
    required this.songTitle,
  });

  final int bpm;
  final AnimationController pulse;
  final bool isPlaying;
  final String? songTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (songTitle != null) ...[
          Text(
            songTitle!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MonoPulseTypography.titleMedium.copyWith(
              color: MonoPulseColors.textSecondary,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
        ],
        // Pulsing downbeat dot. The animation only scales/repaints the dot —
        // it lives in a fixed-size slot and grows via Transform.scale (which
        // doesn't affect layout), wrapped in a RepaintBoundary, so the rest of
        // the screen never reflows or jumps on each beat.
        _PulseDot(pulse: pulse, isPlaying: isPlaying),
        const SizedBox(height: MonoPulseSpacing.xl),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$bpm',
            style: const TextStyle(
              fontFamily: MonoPulseTypography.fontFamilyDisplay,
              fontSize: 148,
              fontWeight: FontWeight.w700,
              height: 0.9,
              letterSpacing: -4,
              color: MonoPulseColors.textPrimary,
              shadows: [
                Shadow(
                  color: MonoPulseColors.accentOrange,
                  blurRadius: 55,
                ),
              ],
            ),
          ),
        ),
        Text(
          'BPM',
          style: MonoPulseTypography.labelMedium.copyWith(
            color: MonoPulseColors.textTertiary,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}

/// Downbeat dot that pulses without disturbing layout.
///
/// The dot occupies a constant [_slot]×[_slot] box; the per-beat "thump" is a
/// [Transform.scale] (paint-only, no relayout) applied to a fixed-size base
/// dot. A [RepaintBoundary] keeps the repaint local so siblings never repaint
/// or shift. The glow is part of the scaled child, so it breathes with the dot
/// but, being a shadow, also never affects layout.
class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.pulse, required this.isPlaying});

  final Animation<double> pulse;
  final bool isPlaying;

  static const double _slot = 36;
  static const double _base = 22;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: _base,
      height: _base,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MonoPulseColors.accentOrange,
        boxShadow: [
          BoxShadow(
            color: MonoPulseColors.accentOrange.withValues(alpha: 0.5),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
    );

    return RepaintBoundary(
      child: SizedBox(
        width: _slot,
        height: _slot,
        child: Center(
          child: AnimatedBuilder(
            animation: pulse,
            // The base dot is built once and passed as `child`; only the scale
            // is recomputed each frame.
            child: dot,
            builder: (context, child) {
              final t = isPlaying ? (1 - pulse.value) : 0.0;
              return Transform.scale(scale: 1 + 0.5 * t, child: child);
            },
          ),
        ),
      ),
    );
  }
}

/// Beat strip, big play/pause, and ±1 / ±5 tempo nudges.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.isPlaying,
    required this.numerator,
    required this.currentBeat,
    required this.onToggle,
    required this.onAdjust,
    required this.onPrevious,
    required this.onNext,
    required this.hasSetlist,
  });

  final bool isPlaying;
  final int numerator;
  final int currentBeat;
  final VoidCallback onToggle;
  final ValueChanged<int> onAdjust;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool hasSetlist;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Beat strip.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: MonoPulseSpacing.sm,
          runSpacing: MonoPulseSpacing.sm,
          children: List.generate(numerator, (i) {
            final active = i == currentBeat;
            return AnimatedContainer(
              duration: MonoPulseAnimation.durationShort,
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.accentOrange15,
                border: Border.all(
                  color: active
                      ? MonoPulseColors.accentOrange
                      : MonoPulseColors.borderDefault,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: MonoPulseSpacing.huge),
        // Big play/pause, flanked by setlist prev/next when a setlist is loaded.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasSetlist) ...[
              _SkipButton(icon: Icons.skip_previous, onTap: onPrevious),
              const SizedBox(width: MonoPulseSpacing.xl),
            ],
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MonoPulseColors.accentOrange,
                  boxShadow: [
                    BoxShadow(
                      color: MonoPulseColors.accentOrange.withValues(
                        alpha: 0.55,
                      ),
                      blurRadius: 60,
                    ),
                  ],
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: MonoPulseColors.black,
                  size: 56,
                ),
              ),
            ),
            if (hasSetlist) ...[
              const SizedBox(width: MonoPulseSpacing.xl),
              _SkipButton(icon: Icons.skip_next, onTap: onNext),
            ],
          ],
        ),
        const SizedBox(height: MonoPulseSpacing.huge),
        // Tempo nudges.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NudgeButton(label: '−5', onTap: () => onAdjust(-5)),
            _NudgeButton(label: '−1', onTap: () => onAdjust(-1)),
            _NudgeButton(label: '+1', accent: true, onTap: () => onAdjust(1)),
            _NudgeButton(label: '+5', accent: true, onTap: () => onAdjust(5)),
          ],
        ),
      ],
    );
  }
}

/// Setlist prev/next. Dimmed and inert when [onTap] is null (no adjacent song).
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MonoPulseColors.surfaceRaised,
          border: Border.all(color: MonoPulseColors.borderDefault),
        ),
        child: Icon(
          icon,
          color: enabled
              ? MonoPulseColors.textSecondary
              : MonoPulseColors.textTertiary,
          size: 32,
        ),
      ),
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent
                ? MonoPulseColors.accentOrange15
                : MonoPulseColors.surfaceRaised,
            border: Border.all(
              color: accent
                  ? MonoPulseColors.accentOrange30
                  : MonoPulseColors.borderDefault,
            ),
          ),
          child: Text(
            label,
            style: MonoPulseTypography.titleMedium.copyWith(
              color: accent
                  ? MonoPulseColors.accentOrangeLight
                  : MonoPulseColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
