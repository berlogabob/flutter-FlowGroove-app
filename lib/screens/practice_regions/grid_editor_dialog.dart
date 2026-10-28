import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/audio_region.dart';
import '../../theme/mono_pulse_theme.dart';

Future<AudioGrid?> showGridEditorDialog(
  BuildContext context, {
  required AudioGrid? Function() getGrid,
  required int Function() positionMs,
  required String Function(int) preciseTime,
  required Future<void> Function() onRemoveGrid,
}) async {
  final bpm = TextEditingController(text: '${getGrid()?.bpm ?? 120}');
  var beats = getGrid()?.beatsPerBar ?? 4;
  var offsetMs = getGrid()?.offsetMs ?? 0;
  String? error;
  ModalRoute<dynamic>? dialogRoute;
  final grid = await showDialog<AudioGrid>(
    context: context,
    builder: (dialogContext) {
      dialogRoute = ModalRoute.of(dialogContext);
      return StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          backgroundColor: context.mp.surface,
          title: const Text('Tempo grid'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bpm,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'BPM',
                    errorText: error,
                  ),
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () => dialogSetState(() {
                        final value = double.tryParse(bpm.text.trim());
                        if (value != null && value.isFinite && value > 0) {
                          offsetMs = (positionMs() % (60000 / value * beats))
                              .round();
                        }
                      }),
                      child: const Text('Downbeat here'),
                    ),
                    TextButton(
                      onPressed: () => dialogSetState(() => offsetMs -= 10),
                      child: const Text('-10 ms'),
                    ),
                    TextButton(
                      onPressed: () => dialogSetState(() => offsetMs += 10),
                      child: const Text('+10 ms'),
                    ),
                  ],
                ),
                Text('Downbeat ${preciseTime(offsetMs)}'),
                DropdownButton<int>(
                  value: beats,
                  items: [
                    for (var n = 2; n <= 7; n++)
                      DropdownMenuItem(
                        value: n,
                        child: Text('$n beats per bar'),
                      ),
                  ],
                  onChanged: (value) => dialogSetState(() => beats = value!),
                ),
              ],
            ),
          ),
          actions: [
            if (getGrid() != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  unawaited(onRemoveGrid());
                },
                child: const Text('Remove grid'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(bpm.text.trim());
                if (value == null || !value.isFinite || value <= 0) {
                  dialogSetState(() => error = 'Enter a positive BPM');
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  AudioGrid(bpm: value, beatsPerBar: beats, offsetMs: offsetMs),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    },
  );
  unawaited(dialogRoute?.completed.then((_) => bpm.dispose()));
  return grid;
}
