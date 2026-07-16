import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/song.dart';
import '../../models/song_lab.dart';

/// Markdown export of a song's Lab history (#70): active decisions, open
/// tasks, versions and the timeline — the "how we play it and why" document.
String buildLabMarkdown({
  required Song song,
  required List<SongLabEntry> entries,
  required List<SongTask> tasks,
  required List<SongVersion> versions,
}) {
  final b = StringBuffer()
    ..writeln('# ${song.title} — Lab history')
    ..writeln()
    ..writeln('${song.artist} · exported ${_d(DateTime.now())}')
    ..writeln();

  final decisions = entries
      .where((e) => e.type == LabEntryType.decision && e.status == 'active')
      .toList();
  if (decisions.isNotEmpty) {
    b.writeln('## Active decisions');
    for (final e in decisions) {
      b.writeln('- **${e.title ?? 'Decision'}**'
          '${e.body != null ? ' — ${e.body}' : ''}');
    }
    b.writeln();
  }

  final open = tasks.where((t) => t.isOpen).toList();
  if (open.isNotEmpty) {
    b.writeln('## Open tasks');
    for (final t in open) {
      b.writeln('- [ ] ${t.title}'
          '${t.dueAt != null ? ' (due ${_d(t.dueAt!)})' : ''}');
    }
    b.writeln();
  }

  if (versions.isNotEmpty) {
    b.writeln('## Versions');
    for (final v in versions) {
      b.writeln('- **${v.name}**${v.isCurrent ? ' — current' : ''}'
          '${v.key != null ? ' · ${v.key}' : ''}'
          '${v.bpm != null ? ' · ${v.bpm} BPM' : ''}'
          ' · ${_d(v.createdAt)}'
          '${v.notes != null ? ' — ${v.notes}' : ''}');
    }
    b.writeln();
  }

  if (entries.isNotEmpty) {
    b.writeln('## Timeline');
    for (final e in entries) {
      b.writeln('- ${_d(e.createdAt)} · ${e.type.name}'
          '${e.status != null ? ' (${e.status})' : ''}: '
          '${e.title ?? ''}${e.title != null && e.body != null ? ' — ' : ''}'
          '${e.body ?? ''}');
    }
  }
  return b.toString();
}

String _d(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// Shares the Lab history as a `.md` file (same share path as ChordPro/CSV).
Future<bool> shareLabMarkdown(String markdown, String songTitle) async {
  try {
    final safe = songTitle.trim().replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final fileName = '${safe.isEmpty ? 'song' : safe}_lab.md';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(markdown),
            name: fileName,
            mimeType: 'text/markdown',
          ),
        ],
        fileNameOverrides: [fileName],
        subject: 'FlowGroove Lab — $songTitle',
      ),
    );
    return true;
  } catch (e, stackTrace) {
    debugPrint('Lab markdown share failed: $e\n$stackTrace');
    return false;
  }
}
