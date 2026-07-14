import 'package:flutter/material.dart';

import '../theme/mono_pulse_theme.dart';
import '../widgets/tools/tool_scaffold.dart';

class PracticePlaceholderScreen extends StatelessWidget {
  const PracticePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ToolScreenScaffold(
      title: 'Practice',
      mainWidget: Center(
        child: Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book,
                size: 64,
                color: MonoPulseColors.accentOrange,
              ),
              const SizedBox(height: MonoPulseSpacing.lg),
              Text(
                'Practice workbook — coming soon',
                textAlign: TextAlign.center,
                style: MonoPulseTypography.headlineMedium,
              ),
              const SizedBox(height: MonoPulseSpacing.sm),
              Text(
                'Exercises, progress tracking and homework are on the way.',
                textAlign: TextAlign.center,
                style: MonoPulseTypography.bodyLarge.copyWith(
                  color: MonoPulseColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
