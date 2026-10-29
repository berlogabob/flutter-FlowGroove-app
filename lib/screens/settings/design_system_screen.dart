import 'package:flutter/material.dart';

import '../../theme/mono_pulse_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_filter_chip.dart';
import '../../widgets/bottom_nav_or_action_bar.dart';
import '../../widgets/custom_button.dart';
import 'design_system_screen_examples.dart';

/// Internal visual reference for the FlowGroove application design system.
/// Reachable from Settings in debug builds; not part of product navigation.
class DesignSystemScreen extends StatelessWidget {
  const DesignSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: context.mp.black,
      bottomNavigationBar: AppBottomBar.actions(
        onBack: () => Navigator.of(context).maybePop(),
        title: 'Design system',
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          children: [
            const Text(
              'FlowGroove / field guide',
              style: MonoPulseTypography.labelMedium,
            ),
            const SizedBox(height: MonoPulseSpacing.sm),
            Text('Made for the room.', style: text.displayMedium),
            const SizedBox(height: MonoPulseSpacing.sm),
            Text(
              'A shared music notebook should feel like an instrument: clear at a glance, reassuring in the hand, and ready when the band is.',
              style: text.bodyLarge?.copyWith(color: context.mp.textSecondary),
            ),
            const SizedBox(height: MonoPulseSpacing.xxl),
            _sectionTitle(context, '01 / Palette'),
            const SizedBox(height: MonoPulseSpacing.md),
            const Wrap(
              spacing: MonoPulseSpacing.sm,
              runSpacing: MonoPulseSpacing.sm,
              children: [
                _Swatch(
                  name: 'Paper',
                  color: MonoPulseColors.paper,
                  value: '#F6F5F0',
                ),
                _Swatch(
                  name: 'Stone',
                  color: MonoPulseColors.stone,
                  value: '#D8D6CC',
                ),
                _Swatch(
                  name: 'Fog',
                  color: MonoPulseColors.fog,
                  value: '#B5B2A8',
                ),
                _Swatch(
                  name: 'Sage',
                  color: MonoPulseColors.sage,
                  value: '#8A907F',
                ),
                _Swatch(
                  name: 'Petrol',
                  color: MonoPulseColors.petrol,
                  value: '#285E6E',
                ),
                _Swatch(
                  name: 'Charcoal',
                  color: MonoPulseColors.charcoal,
                  value: '#1E1E1C',
                ),
                _Swatch(
                  name: 'Signal orange',
                  color: MonoPulseColors.accentOrange,
                  value: '#FF5A36',
                ),
              ],
            ),
            const SizedBox(height: MonoPulseSpacing.xxl),
            _sectionTitle(context, '02 / Type'),
            const SizedBox(height: MonoPulseSpacing.md),
            AppCard(
              variant: AppCardVariant.raised,
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set the room in motion', style: text.headlineLarge),
                  const SizedBox(height: MonoPulseSpacing.sm),
                  Text(
                    'Source Serif 4 keeps song details and supporting copy warm and easy to read.',
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: MonoPulseSpacing.sm),
                  Text('Control labels / Arial', style: text.labelMedium),
                ],
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.xxl),
            _sectionTitle(context, '03 / Controls'),
            const SizedBox(height: MonoPulseSpacing.md),
            AppCard(
              variant: AppCardVariant.raised,
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              child: Wrap(
                spacing: MonoPulseSpacing.md,
                runSpacing: MonoPulseSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CustomButton(
                    label: 'Play set',
                    icon: Icons.play_arrow,
                    onPressed: () {},
                  ),
                  CustomButton(
                    label: 'Edit notes',
                    variant: ButtonVariant.outline,
                    onPressed: () {},
                  ),
                  const CustomButton(label: 'Disabled'),
                  const _HardwareButton(
                    icon: Icons.skip_previous,
                    label: 'Back',
                  ),
                  const _HardwareButton(
                    icon: Icons.stop,
                    label: 'Stop',
                    active: true,
                  ),
                  const _HardwareButton(icon: Icons.skip_next, label: 'Next'),
                ],
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.xxl),
            _sectionTitle(context, '04 / Song data'),
            const SizedBox(height: MonoPulseSpacing.md),
            AppCard(
              variant: AppCardVariant.raised,
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Viento Helado', style: text.headlineMedium),
                  const SizedBox(height: MonoPulseSpacing.xs),
                  Text(
                    'Sol  ·  Viento Helado',
                    style: text.bodyMedium?.copyWith(
                      color: context.mp.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MonoPulseSpacing.md),
                  const Wrap(
                    spacing: MonoPulseSpacing.sm,
                    children: [
                      _DataPlate(label: 'Key', value: 'Am'),
                      _DataPlate(label: 'Tempo', value: '120 BPM'),
                      _DataPlate(label: 'Time', value: '4/4'),
                    ],
                  ),
                  const SizedBox(height: MonoPulseSpacing.md),
                  Wrap(
                    spacing: MonoPulseSpacing.sm,
                    children: [
                      AppFilterChip(
                        label: 'Verse',
                        selected: false,
                        onSelected: (_) {},
                      ),
                      AppFilterChip(
                        label: 'Chorus',
                        selected: true,
                        onSelected: (_) {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.xxl),
            _sectionTitle(context, '05 / Rules'),
            const SizedBox(height: MonoPulseSpacing.md),
            const _RuleLine(
              number: '01',
              text:
                  'Paper is the default stage; charcoal is the instrument face.',
            ),
            const _RuleLine(
              number: '02',
              text:
                  'Orange marks the main action. Stone and Fog mark selections; gray keeps secondary details quiet.',
            ),
            const _RuleLine(
              number: '03',
              text:
                  'Use raised, screw-down surfaces for grouped controls and song data.',
            ),
            const _RuleLine(
              number: '04',
              text:
                  'Keep labels legible and secondary information calm, never tiny.',
            ),
            const SizedBox(height: MonoPulseSpacing.xxl),
            _sectionTitle(context, '06 / Screen examples'),
            const SizedBox(height: MonoPulseSpacing.sm),
            Text(
              'Try setlist, song and add-song screens with sample rehearsal data.',
              style: text.bodyMedium?.copyWith(color: context.mp.textSecondary),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            const FlowGrooveScreenExamples(),
            const SizedBox(height: MonoPulseSpacing.massive),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: MonoPulseSpacing.xs),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color, required this.value});
  final String name;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: context.mp.borderDefault),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _DataPlate extends StatelessWidget {
  const _DataPlate({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: context.mp.surfaceRaised,
      border: Border.all(color: context.mp.borderDefault),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.mp.textTertiary),
        ),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _HardwareButton extends StatelessWidget {
  const _HardwareButton({
    required this.icon,
    required this.label,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 64,
        height: 56,
        decoration: BoxDecoration(
          color: active
              ? MonoPulseColors.accentOrange
              : context.mp.surfaceRaised,
          border: Border.all(color: MonoPulseColors.charcoal, width: 1.2),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: context.mp.borderStrong.withValues(alpha: 0.55),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: MonoPulseColors.charcoal),
      ),
      const SizedBox(height: MonoPulseSpacing.sm),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: MonoPulseTypography.labelMedium.copyWith(
            color: MonoPulseColors.accentOrange,
          ),
        ),
        const SizedBox(width: MonoPulseSpacing.md),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
  );
}
