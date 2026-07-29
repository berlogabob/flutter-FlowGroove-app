import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../models/rehearsal.dart';

// ponytail: hand-rolled ICS; swap for a lib only if we need recurrence/timezones.

/// Builds an iCalendar (.ics) document for a confirmed rehearsal.
/// Times are emitted as UTC (`...Z`), which every calendar app accepts.
/// Returns null if the rehearsal has no confirmed slot.
String? rehearsalToIcs(Rehearsal rehearsal, {String? setlistName}) {
  final slot = rehearsal.confirmedSlot;
  if (slot == null) return null;

  final descParts = <String>[
    if (setlistName != null && setlistName.isNotEmpty) 'Setlist: $setlistName',
    if (rehearsal.notes != null && rehearsal.notes!.isNotEmpty) rehearsal.notes!,
  ];

  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//FlowGroove//Rehearsal//EN',
    'BEGIN:VEVENT',
    'UID:rehearsal-${rehearsal.id}@flowgroove.app',
    'DTSTAMP:${_ics(DateTime.now())}',
    'DTSTART:${_ics(slot.startTime)}',
    'DTEND:${_ics(slot.endTime)}',
    'SUMMARY:${_esc(rehearsal.title)}',
    if (rehearsal.location != null && rehearsal.location!.isNotEmpty)
      'LOCATION:${_esc(rehearsal.location!)}',
    if (descParts.isNotEmpty) 'DESCRIPTION:${_esc(descParts.join('\\n'))}',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return lines.join('\r\n');
}

/// Builds the .ics and opens the share sheet. Returns false on failure or if
/// there is no confirmed slot.
Future<bool> shareRehearsalIcs(Rehearsal rehearsal, {String? setlistName}) async {
  try {
    final ics = rehearsalToIcs(rehearsal, setlistName: setlistName);
    if (ics == null) return false;
    final fileName = '${_sanitize(rehearsal.title)}.ics';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(ics),
            name: fileName,
            mimeType: 'text/calendar',
          ),
        ],
        fileNameOverrides: [fileName],
        subject: 'FlowGroove — ${rehearsal.title}',
      ),
    );
    return true;
  } catch (e, stackTrace) {
    debugPrint('ICS share failed: $e\n$stackTrace');
    return false;
  }
}

/// UTC basic format: 20260702T190000Z
String _ics(DateTime dt) {
  final u = dt.toUtc();
  String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  return '${p(u.year, 4)}${p(u.month)}${p(u.day)}T'
      '${p(u.hour)}${p(u.minute)}${p(u.second)}Z';
}

/// Escapes text per RFC 5545 (commas, semicolons, backslashes, newlines).
String _esc(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;')
    .replaceAll('\n', '\\n');

String _sanitize(String title) {
  final cleaned = title.trim().replaceAll(RegExp(r'[^\w\s-]'), '').trim();
  return cleaned.isEmpty ? 'rehearsal' : cleaned;
}
