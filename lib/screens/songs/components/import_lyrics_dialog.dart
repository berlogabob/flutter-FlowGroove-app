import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../models/section.dart';
import '../../../models/song.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../utils/chordpro.dart';
import '../../../widgets/chord_chart_view.dart';

/// Result of the paste-import sheet: the sections plus any song-level metadata
/// recovered from a full ChordPro document (title/artist/key/tempo/time). The
/// caller applies the non-null fields to the song form.
class ImportedSong {
  ImportedSong({
    required this.sections,
    this.title,
    this.artist,
    this.ourKey,
    this.ourBpm,
    this.timeTop,
  });

  final List<Section> sections;
  final String? title;
  final String? artist;
  final String? ourKey;
  final int? ourBpm;
  final int? timeTop;

  bool get hasMeta =>
      title != null ||
      artist != null ||
      ourKey != null ||
      ourBpm != null ||
      timeTop != null;
}

/// Bottom sheet to paste ChordPro / lyrics+chords and import it. A full ChordPro
/// document (with `{title}`/`{key}`/`{tempo}`/`{start_of_*}` directives) is parsed
/// by [chordProToSong] so title, artist, key, tempo, time signature AND the
/// sections all sync to the form; looser lyrics fall back to [parseSongSections]
/// for section-splitting only.
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

  static final _blankBase = Song(
    id: '',
    title: '',
    artist: '',
    createdAt: DateTime(2000),
    updatedAt: DateTime(2000),
  );

  ImportedSong get _parsed {
    final text = _controller.text;

    // A doc with directives → full ChordPro sync (metadata + structured sections).
    // ponytail: the `{` heuristic is enough; looser lyric pastes have none.
    if (text.contains('{')) {
      final p = chordProToSong(text, base: _blankBase);
      final sections = p.sections
          .map(
            (s) => Section(
              id: _uuid.v4(),
              name: s.name,
              notes: s.notes,
              chordChart: s.chordChart,
            ),
          )
          .toList();
      final hasTime = RegExp(
        r'\{\s*time\b',
        caseSensitive: false,
      ).hasMatch(text);
      return ImportedSong(
        sections: sections,
        title: p.song.title.isNotEmpty ? p.song.title : null,
        artist: p.song.artist.isNotEmpty ? p.song.artist : null,
        ourKey: p.song.ourKey,
        ourBpm: p.song.ourBPM,
        timeTop: hasTime ? p.song.accentBeats : null,
      );
    }

    // Loose lyrics with [Verse 1] / "Chorus:" headers — sections only.
    final sections = parseSongSections(text)
        .map((s) => Section(id: _uuid.v4(), name: s.name, chordChart: s.chart))
        .toList();
    return ImportedSong(sections: sections);
  }

  void _import() => Navigator.pop(context, _parsed);

  String _metaLine(ImportedSong p) => [
    if (p.title != null) '“${p.title}”',
    if (p.artist != null) p.artist!,
    if (p.ourKey != null) '${p.ourKey} · ${keyToScale(p.ourKey!).quality}',
    if (p.ourBpm != null) '${p.ourBpm} BPM',
    if (p.timeTop != null) '${p.timeTop}/4',
  ].join('   ·   ');

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final canImport = parsed.sections.isNotEmpty || parsed.hasMeta;
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
              'Paste ChordPro. A full chart with {title}, {key}, {tempo} and '
              '{start_of_verse: …} blocks fills the whole song; plain lyrics with '
              '[Verse 1] or "Chorus:" just split into sections.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText:
                    '{title: Back to Black}\n{artist: Amy Winehouse}\n{key: Dm}\n'
                    '{tempo: 123}\n\n{start_of_verse: Verse 1}\n[Dm]He left no '
                    'time to [Gm]regret\n{end_of_verse}',
                border: OutlineInputBorder(),
              ),
              maxLines: 12,
              minLines: 5,
              onChanged: (_) => setState(() {}),
            ),
            if (parsed.hasMeta) ...[
              const SizedBox(height: 16),
              Text(
                'Song details detected:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _metaLine(parsed),
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.accentOrange,
                ),
              ),
            ],
            if (parsed.sections.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Preview — ${parsed.sections.length} section(s):',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                songMapSummary(parsed.sections.map((s) => s.name).toList()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final s in parsed.sections) ...[
                Text(
                  s.name,
                  style: MonoPulseTypography.titleMedium.copyWith(
                    color: MonoPulseColors.accentOrange,
                  ),
                ),
                const SizedBox(height: 4),
                ChordChartView(chart: s.chordChart ?? ''),
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
                  onPressed: canImport ? _import : null,
                  child: Text(
                    parsed.sections.isEmpty
                        ? 'Import'
                        : 'Import ${parsed.sections.length}',
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
