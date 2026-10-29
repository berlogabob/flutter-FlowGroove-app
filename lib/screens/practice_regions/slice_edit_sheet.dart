import 'package:flutter/material.dart';

import '../../models/audio_region.dart';
import '../../theme/mono_pulse_theme.dart';

Future<String?> showSliceEditSheet(
  BuildContext context, {
  required List<AudioRegion> regions,
  required int i,
  required String Function(AudioRegion) name,
  required String Function(int) preciseTime,
}) async {
  final region = regions[i];
  final next = i + 1 < regions.length ? regions[i + 1] : null;
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.mp.surface,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(name(region), style: MonoPulseTypography.titleLarge),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => Navigator.pop(sheetContext, 'rename'),
            ),
            ListTile(
              key: const ValueKey('slice-start'),
              leading: const Text('Start'),
              title: Text(preciseTime(region.startMs)),
              subtitle: Text(
                i == 0
                    ? 'Trim the lead-in (it becomes a skipped slice)'
                    : 'Also end of ${name(regions[i - 1])}',
              ),
              trailing: const Icon(Icons.tune),
              onTap: () => Navigator.pop(sheetContext, 'start'),
            ),
            ListTile(
              key: const ValueKey('slice-end'),
              leading: const Text('End'),
              title: Text(preciseTime(region.endMs)),
              subtitle: Text(
                next == null
                    ? 'Trim the tail (it becomes a skipped slice)'
                    : 'Also start of ${name(next)}',
              ),
              trailing: const Icon(Icons.tune),
              onTap: () => Navigator.pop(sheetContext, 'end'),
            ),
            SwitchListTile(
              key: const ValueKey('slice-skip'),
              secondary: const Icon(Icons.visibility_off_outlined),
              title: const Text('Skip'),
              subtitle: const Text('Hide the pad and jump over it in playback'),
              value: region.skip,
              onChanged: (_) => Navigator.pop(sheetContext, 'skip'),
            ),
            if (regions.length > 1)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete slice'),
                subtitle: Text(
                  i == 0
                      ? 'Its time joins the next slice'
                      : 'Its time joins the slice before it',
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
          ],
        ),
      ),
    ),
  );
  return action;
}
