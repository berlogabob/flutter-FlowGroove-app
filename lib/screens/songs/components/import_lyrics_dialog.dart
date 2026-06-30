import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../models/section.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../utils/chordpro.dart';
import '../../../widgets/chord_chart_view.dart';

/// Bottom sheet to paste ChordPro / lyrics+chords text and import it as song
/// sections. Parses live (see [parseSongSections]) and previews the result;
/// returns the built `List<Section>` on import.
class ImportLyricsDialog extends StatefulWidget {
  const ImportLyricsDialog({super.key});

  @override
  State<ImportLyricsDialog> createState() => _ImportLyricsDialogState();
}

class _ImportLyricsDialogState extends State<ImportLyricsDialog> {
  final _controller = TextEditingController();
  static const _uuid = Uuid();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<({String name, String chart})> get _parsed =>
      parseSongSections(_controller.text);

  void _import() {
    final sections = _parsed
        .map((s) => Section(id: _uuid.v4(), name: s.name, chordChart: s.chart))
        .toList();
    Navigator.pop(context, sections);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import lyrics & chords',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Paste ChordPro or lyrics with [chords]. Lines like [Verse 1] or '
              '"Chorus:" start a new section.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText:
                    '[Verse 1]\n[Am]Twinkle [F]little [C]star\n\nChorus:\n[C]How I [G]wonder',
                border: OutlineInputBorder(),
              ),
              maxLines: 10,
              minLines: 5,
              onChanged: (_) => setState(() {}),
            ),
            if (parsed.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Preview — ${parsed.length} section(s):',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final s in parsed) ...[
                Text(
                  s.name,
                  style: MonoPulseTypography.titleMedium.copyWith(
                    color: MonoPulseColors.accentOrange,
                  ),
                ),
                const SizedBox(height: 4),
                ChordChartView(chart: s.chart),
                const SizedBox(height: 12),
              ],
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: parsed.isEmpty ? null : _import,
                  child: Text(
                    parsed.isEmpty ? 'Import' : 'Import ${parsed.length}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
