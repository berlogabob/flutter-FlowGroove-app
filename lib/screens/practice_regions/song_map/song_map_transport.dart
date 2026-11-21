import 'package:material_ui/material_ui.dart';

import '../../../theme/mono_pulse_theme.dart';

/// Persistent playback controls for the Song Map.
class SongMapTransport extends StatelessWidget {
  const SongMapTransport({
    required this.playing,
    required this.speedPercent,
    required this.loop,
    required this.countIn,
    required this.click,
    required this.clickAndDrums,
    required this.onPlay,
    required this.onStop,
    required this.onSpeedTap,
    required this.onLoopChanged,
    required this.onCountInChanged,
    required this.onClickChanged,
    required this.onClickAndDrumsChanged,
    this.playLabel,
    this.onPlayLongPress,
    this.clickUnavailableReason,
    this.leading,
    this.trailing,
    this.stretched = false,
    super.key,
  });

  final bool playing;
  final int speedPercent;
  final bool loop;
  final bool countIn;
  final bool click;
  final bool clickAndDrums;
  final bool stretched;
  final String? playLabel;
  final String? clickUnavailableReason;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onPlay;
  final VoidCallback? onStop;
  final VoidCallback? onPlayLongPress;
  final VoidCallback? onSpeedTap;
  final ValueChanged<bool>? onLoopChanged;
  final ValueChanged<bool>? onCountInChanged;
  final ValueChanged<bool>? onClickChanged;
  final ValueChanged<bool>? onClickAndDrumsChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: MonoPulseColors.surfaceRaised,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.md,
          vertical: MonoPulseSpacing.sm,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final controls = _controls();
            if (leading == null && trailing == null) return controls;

            final left = Expanded(child: leading ?? const SizedBox.shrink());
            final right = Expanded(child: trailing ?? const SizedBox.shrink());
            if (constraints.maxWidth >= 740) {
              return Row(
                children: [
                  left,
                  Expanded(flex: 6, child: controls),
                  right,
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [left, const Spacer(), right]),
                const SizedBox(height: MonoPulseSpacing.xs),
                controls,
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _controls() => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: MonoPulseSpacing.xs,
    runSpacing: MonoPulseSpacing.xs,
    children: [
      _playButton(),
      _toggle('loop', Icons.repeat, 'Loop', loop, onLoopChanged),
      OutlinedButton.icon(
        key: const ValueKey('speed'),
        onPressed: onSpeedTap,
        icon: const Icon(Icons.speed, size: 18),
        label: Text('$speedPercent%'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm),
          minimumSize: const Size(0, 40),
        ),
      ),
      _toggle('count-in', Icons.timer, 'Count-in', countIn, onCountInChanged),
      Tooltip(
        message: clickUnavailableReason ?? 'Click',
        child: _toggle(
          'click',
          Icons.music_note,
          'Click',
          click,
          onClickChanged,
        ),
      ),
      Tooltip(
        message: stretched
            ? 'Click & drums is unavailable while audio is stretched'
            : clickUnavailableReason ?? 'Click & drums',
        child: _toggle(
          'click-and-drums',
          Icons.queue_music,
          'Click & drums',
          clickAndDrums,
          stretched ? null : onClickAndDrumsChanged,
        ),
      ),
    ],
  );

  Widget _playButton() {
    final button = FilledButton.icon(
      key: const ValueKey('play'),
      onPressed: playing ? onStop : onPlay,
      onLongPress: onPlayLongPress,
      icon: Icon(
        playing
            ? (playLabel == 'Pause' ? Icons.pause : Icons.stop)
            : Icons.play_arrow,
        size: 18,
      ),
      label: Text(playLabel ?? (playing ? 'Stop' : 'Play')),
      style: FilledButton.styleFrom(
        foregroundColor: MonoPulseColors.black,
        backgroundColor: MonoPulseColors.accentOrange,
        padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm),
        minimumSize: const Size(0, 40),
      ),
    );
    return onPlayLongPress == null
        ? button
        : Tooltip(message: 'Hold for speed, pre-roll, drums', child: button);
  }

  Widget _toggle(
    String key,
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool>? onChanged,
  ) => FilterChip(
    key: ValueKey(key),
    avatar: Icon(icon, size: 16),
    label: Text(label),
    selected: value,
    onSelected: onChanged,
    showCheckmark: false,
    labelPadding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xs),
    visualDensity: VisualDensity.compact,
  );
}
