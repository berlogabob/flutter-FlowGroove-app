import 'package:flutter/material.dart';

import '../utils/chordpro.dart';

/// Renders a ChordPro [chart] as chords-over-lyrics. Each segment is a small
/// column (chord above its syllable), so alignment holds without a monospace
/// font; lines wrap on narrow screens. Shared by the section editor preview and
/// the performance view.
class ChordChartView extends StatelessWidget {
  const ChordChartView({
    required this.chart,
    this.lyricStyle,
    this.chordColor,
    this.lineSpacing = 10,
    super.key,
  });

  final String chart;
  final TextStyle? lyricStyle;
  final Color? chordColor;
  final double lineSpacing;

  @override
  Widget build(BuildContext context) {
    final lyric =
        lyricStyle ?? Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    final chordStyle = lyric.copyWith(
      fontWeight: FontWeight.bold,
      color: chordColor ?? Theme.of(context).colorScheme.primary,
    );

    final lines = chart.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: EdgeInsets.only(bottom: lineSpacing),
            child: _ChartLine(line: line, lyric: lyric, chord: chordStyle),
          ),
      ],
    );
  }
}

class _ChartLine extends StatelessWidget {
  const _ChartLine({
    required this.line,
    required this.lyric,
    required this.chord,
  });

  final String line;
  final TextStyle lyric;
  final TextStyle chord;

  @override
  Widget build(BuildContext context) =>
      ChordLineView(segments: parseChordProLine(line), lyric: lyric, chord: chord);
}

/// Renders one already-parsed ChordPro line as a `Wrap` of chord-over-syllable
/// columns. Split out of [_ChartLine] so callers that parse ahead of time (the
/// performance sheet, which caches parsed lines to keep scroll builds cheap —
/// #96) can render without re-parsing on every rebuild.
class ChordLineView extends StatelessWidget {
  const ChordLineView({
    required this.segments,
    required this.lyric,
    required this.chord,
    super.key,
  });

  final List<ChordSegment> segments;
  final TextStyle lyric;
  final TextStyle chord;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      // Blank line — preserve as vertical space.
      return SizedBox(height: lyric.fontSize ?? 16);
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (final seg in segments)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(seg.chord ?? '', style: chord),
              Text(seg.text.isEmpty ? ' ' : seg.text, style: lyric),
            ],
          ),
      ],
    );
  }
}
