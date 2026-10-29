import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/section.dart';
import '../../theme/mono_pulse_theme.dart';

Future<String?> showRegionNameSheet(
  BuildContext context, {
  required String initialName,
}) async {
  final controller = TextEditingController(text: initialName);
  ModalRoute<dynamic>? sheetRoute;
  final name = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.mp.surface,
    builder: (sheetContext) {
      sheetRoute = ModalRoute.of(sheetContext);
      return StatefulBuilder(
        builder: (context, sheetSetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            MonoPulseSpacing.lg,
            MonoPulseSpacing.lg,
            MonoPulseSpacing.lg,
            MediaQuery.viewInsetsOf(context).bottom + MonoPulseSpacing.lg,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Region name',
                    style: MonoPulseTypography.titleLarge,
                  ),
                  Wrap(
                    spacing: MonoPulseSpacing.sm,
                    children: [
                      for (final template in Section.templates)
                        ChoiceChip(
                          label: Text(template),
                          selected: controller.text == template,
                          onSelected: (_) => sheetSetState(() {
                            controller.text = template;
                          }),
                        ),
                    ],
                  ),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (_) => sheetSetState(() {}),
                    onSubmitted: (value) => Navigator.pop(sheetContext, value),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(sheetContext, controller.text),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  // Keep the controller alive until the sheet finishes dismissing.
  unawaited(sheetRoute?.completed.then((_) => controller.dispose()));
  return name;
}
