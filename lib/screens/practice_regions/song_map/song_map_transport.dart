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
  final VoidCallback? onPlay;
  final VoidCallback? onStop;
  final VoidCallback? onPlayLongPress;
  final VoidCallback? onSpeedTap;
  final ValueChanged<bool>? onLoopChanged;
  final ValueChanged<bool>? onCountInChanged;
  final ValueChanged<bool>? onClickChanged;
  final ValueChanged<bool>? onClickAndDrumsChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = playing ? 'Stop' : 'Play';
    final play = FilledButton(
      key: const ValueKey('play'),
      onPressed: playing ? onStop : onPlay,
      onLongPress: onPlayLongPress,
      style: FilledButton.styleFrom(
        foregroundColor: colors.onPrimary,
        backgroundColor: colors.primary,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 48),
        elevation: 0,
        shape: _shape,
      ),
      child: _face(playing ? Icons.stop : Icons.play_arrow, label, playLabel),
    );

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.sm),
          child: Row(
            spacing: MonoPulseSpacing.xs,
            children: [
              Expanded(
                child: onPlayLongPress == null
                    ? play
                    : Tooltip(
                        message: 'Hold for speed, pre-roll, drums',
                        child: play,
                      ),
              ),
              Expanded(
                child: _toggle(
                  colors,
                  'loop',
                  Icons.repeat,
                  'Loop',
                  loop,
                  onLoopChanged,
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('speed'),
                  onPressed: onSpeedTap,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.surfaceContainerHighest,
                    foregroundColor: colors.onSurface,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 48),
                    shape: _shape,
                  ),
                  child: _face(Icons.speed, '$speedPercent%'),
                ),
              ),
              Expanded(
                child: _toggle(
                  colors,
                  'count-in',
                  Icons.timer,
                  'Count-in',
                  countIn,
                  onCountInChanged,
                ),
              ),
              Expanded(
                child: Tooltip(
                  message: clickUnavailableReason ?? 'Click',
                  child: _toggle(
                    colors,
                    'click',
                    Icons.volume_up,
                    'Click',
                    click,
                    onClickChanged,
                  ),
                ),
              ),
              Expanded(
                child: Tooltip(
                  message: stretched
                      ? 'Click & drums is unavailable while audio is stretched'
                      : clickUnavailableReason ?? 'Click & drums',
                  child: _toggle(
                    colors,
                    'click-and-drums',
                    Icons.graphic_eq,
                    'Drums',
                    clickAndDrums,
                    stretched ? null : onClickAndDrumsChanged,
                    semanticsLabel: 'Click & drums',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(MonoPulseRadius.medium)),
  );

  Widget _face(IconData icon, String label, [String? semanticsLabel]) => Column(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 20),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            semanticsLabel: semanticsLabel,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    ],
  );

  Widget _toggle(
    ColorScheme colors,
    String key,
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool>? onChanged, {
    String? semanticsLabel,
  }) => FilterChip(
    key: ValueKey(key),
    label: SizedBox(
      width: double.infinity,
      height: 48,
      child: _face(icon, label, semanticsLabel),
    ),
    selected: value,
    onSelected: onChanged,
    showCheckmark: false,
    backgroundColor: colors.surfaceContainerHighest,
    selectedColor: colors.surfaceContainerHighest,
    side: value
        ? BorderSide(color: colors.onSurface, width: 2)
        : BorderSide.none,
    shape: _shape,
    padding: EdgeInsets.zero,
    labelPadding: EdgeInsets.zero,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
