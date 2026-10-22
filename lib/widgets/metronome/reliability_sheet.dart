import 'package:flutter/material.dart';

import '../../services/power_reliability.dart';
import '../../theme/mono_pulse_theme.dart';

Future<void> showReliabilitySheet(
  BuildContext context, {
  PowerReliability? power,
}) async {
  final reliability = power ?? PowerReliability();
  final family = await reliability.family();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.mp.blackSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MonoPulseRadius.xlarge),
      ),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Keep timing reliable',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            const Text(
              'Some phones stop audio apps when the screen turns off. Concerts need exact timing.',
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            Text(PowerReliability.steps(family)),
            const SizedBox(height: MonoPulseSpacing.lg),
            FilledButton(
              onPressed: reliability.requestIgnoreOptimizations,
              child: const Text('Allow unrestricted battery'),
            ),
            OutlinedButton(
              onPressed: reliability.openVendorSettings,
              child: const Text('Open phone battery settings'),
            ),
            TextButton(
              onPressed: () async {
                await reliability.markSetupSeen();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ),
  );
}
