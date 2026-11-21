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
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback onSpeedTap;
  final ValueChanged<bool> onLoopChanged;
  final ValueChanged<bool> onCountInChanged;
  final ValueChanged<bool> onClickChanged;
  final ValueChanged<bool> onClickAndDrumsChanged;

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
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: MonoPulseSpacing.xs,
          runSpacing: MonoPulseSpacing.xs,
          children: [
            _action(
              icon: playing ? Icons.stop : Icons.play_arrow,
              label: playing ? 'Stop' : 'Play',
              onPressed: playing ? onStop : onPlay,
              selected: true,
            ),
            _toggle(Icons.repeat, 'Loop', loop, onLoopChanged),
            _action(
              icon: Icons.speed,
              label: '$speedPercent%',
              onPressed: onSpeedTap,
            ),
            _toggle(Icons.timer, 'Count-in', countIn, onCountInChanged),
            _toggle(Icons.music_note, 'Click', click, onClickChanged),
            Tooltip(
              message: stretched
                  ? 'Click & drums is unavailable while audio is stretched'
                  : 'Click & drums',
              child: _toggle(
                Icons.queue_music,
                'Click & drums',
                clickAndDrums,
                onClickAndDrumsChanged,
                enabled: !stretched,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool selected = false,
  }) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: selected
          ? MonoPulseColors.charcoal
          : MonoPulseColors.textPrimary,
      backgroundColor: selected ? MonoPulseColors.accentOrange : null,
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm),
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
      ),
    ),
  );

  Widget _toggle(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    bool enabled = true,
  }) => FilterChip(
    avatar: Icon(icon, size: 16),
    label: Text(label),
    selected: value,
    onSelected: enabled ? onChanged : null,
    showCheckmark: false,
    labelPadding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xs),
    visualDensity: VisualDensity.compact,
  );
}
