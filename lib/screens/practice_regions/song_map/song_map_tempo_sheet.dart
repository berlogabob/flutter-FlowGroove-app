import 'package:material_ui/material_ui.dart';

import '../../../theme/mono_pulse_theme.dart';

typedef SongMapTempoResult = ({int bpm, bool listen});

const _minBpm = 20;
const _maxBpm = 400;
const _tapWindow = 4;
const _tapTimeout = Duration(seconds: 2);

/// The Tempo sheet: Save returns the value and the Listen switch, Cancel null.
Future<SongMapTempoResult?> showSongMapTempoSheet(
  BuildContext context, {
  required int bpm,
  required bool listen,
}) => showModalBottomSheet<SongMapTempoResult>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.mp.surfaceRaised,
  builder: (_) => SongMapTempoSheet(bpm: bpm, listen: listen),
);

class SongMapTempoSheet extends StatefulWidget {
  const SongMapTempoSheet({
    required this.bpm,
    required this.listen,
    this.now = DateTime.now,
    super.key,
  });

  final int bpm;
  final bool listen;
  final DateTime Function() now;

  @override
  State<SongMapTempoSheet> createState() => _SongMapTempoSheetState();
}

class _SongMapTempoSheetState extends State<SongMapTempoSheet> {
  late int _bpm = widget.bpm;
  late bool _listen = widget.listen;
  final _taps = <DateTime>[];

  void _set(int value) => setState(() => _bpm = value.clamp(_minBpm, _maxBpm));

  void _tap() {
    final now = widget.now();
    if (_taps.isNotEmpty && now.difference(_taps.last) > _tapTimeout) {
      _taps.clear();
    }
    _taps.add(now);
    if (_taps.length > _tapWindow) _taps.removeAt(0);
    if (_taps.length < 2) return;
    final span = _taps.last.difference(_taps.first).inMicroseconds;
    if (span <= 0) return;
    _set((60000000 * (_taps.length - 1) / span).round());
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.mp;
    Widget step(String label, VoidCallback onTap) => Expanded(
      child: OutlinedButton(
        style: const ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size(double.infinity, MonoPulseSpacing.massive),
          ),
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          MonoPulseSpacing.xl,
          MonoPulseSpacing.lg,
          MonoPulseSpacing.xl,
          MonoPulseSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MonoPulseSpacing.sm,
          children: [
            Text(
              'Tempo',
              style: MonoPulseTypography.headlineMedium.copyWith(
                color: palette.textPrimary,
              ),
            ),
            // Fixed slot: 2- and 3-digit values never move the rest.
            SizedBox(
              height: MonoPulseSpacing.huge + MonoPulseSpacing.xl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: MonoPulseSpacing.sm,
                children: [
                  SizedBox(
                    key: const ValueKey('tempo-value-slot'),
                    width: MonoPulseSpacing.huge * 2 + MonoPulseSpacing.sm,
                    child: Text(
                      '$_bpm',
                      key: const ValueKey('tempo-value'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: MonoPulseTypography.labelLarge.copyWith(
                        fontSize: MonoPulseSpacing.huge,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MonoPulseSpacing.huge,
                    child: Text(
                      'BPM',
                      style: MonoPulseTypography.titleMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              spacing: MonoPulseSpacing.sm,
              children: [
                step('÷2', () => _set((_bpm / 2).round())),
                step('-1', () => _set(_bpm - 1)),
                step('+1', () => _set(_bpm + 1)),
                step('×2', () => _set(_bpm * 2)),
              ],
            ),
            OutlinedButton(
              key: const ValueKey('tempo-tap'),
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(
                  Size(
                    double.infinity,
                    MonoPulseSpacing.massive + MonoPulseSpacing.sm,
                  ),
                ),
                alignment: Alignment.centerLeft,
              ),
              onPressed: _tap,
              child: Row(
                spacing: MonoPulseSpacing.md,
                children: [
                  const Icon(
                    Icons.touch_app,
                    size: MonoPulseSpacing.xl,
                    color: MonoPulseColors.accentOrange,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tap',
                          style: MonoPulseTypography.labelLarge.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          'Tap $_tapWindow times',
                          style: MonoPulseTypography.bodySmall.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              key: const ValueKey('tempo-listen'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Listen'),
              subtitle: const Text('Click over the recording'),
              value: _listen,
              onChanged: (value) => setState(() => _listen = value),
            ),
            FilledButton(
              key: const ValueKey('tempo-save'),
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(
                  Size(double.infinity, MonoPulseSpacing.massive),
                ),
              ),
              onPressed: () =>
                  Navigator.pop(context, (bpm: _bpm, listen: _listen)),
              child: const Text('Save'),
            ),
            TextButton(
              key: const ValueKey('tempo-cancel'),
              style: TextButton.styleFrom(
                foregroundColor: MonoPulseColors.accentOrange,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
