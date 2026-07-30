// Renders a real setlist to an actual PDF and asserts the bytes are a valid,
// non-trivial document.
//
// The pre-existing "PDF tests" only assert `PdfService.exportSetlist != null`
// and poke at the Setlist model — nothing ever produced a document, because
// exportSetlist ended in Printing.layoutPdf/sharePdf, which need platform
// channels. Splitting `buildSetlistBytes` out of `exportSetlist` made the layout
// reachable from a test; this is the first coverage that actually exercises it.
//
// Doubles as the export tool: point FLOWGROOVE_SETLIST_JSON at a fixture dumped
// from Firestore and FLOWGROOVE_PDF_OUT at a path, and it writes the file.
//
//   dart run tool/export_setlist_pdf.dart      (thin wrapper, see that file)
//
// PdfGoogleFonts fetches Roboto over HTTP. flutter_test installs an HttpOverrides
// that fails every request, so it has to be cleared or the build throws.

import 'dart:convert';
import 'dart:io';

import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/services/export/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    // Without this, PdfGoogleFonts' asset lookup logs "Binding has not yet been
    // initialized" before falling back to the network.
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_test blocks all network by default; PdfGoogleFonts needs it.
    HttpOverrides.global = null;
  });

  final fixturePath = Platform.environment['FLOWGROOVE_SETLIST_JSON'] ??
      '/tmp/roume/setlist.json';

  group('setlist PDF render', () {
    late Setlist setlist;
    late List<Song> songs;

    setUp(() {
      final file = File(fixturePath);
      if (!file.existsSync()) {
        markTestSkipped('no fixture at $fixturePath');
        return;
      }
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      setlist = Setlist.fromJson(Map<String, dynamic>.from(raw['setlist'] as Map));
      songs = [
        for (final s in (raw['songs'] as List))
          Song.fromJson(Map<String, dynamic>.from(s as Map)),
      ];
    });

    test('the fixture parses into models the PDF can consume', () {
      if (!File(fixturePath).existsSync()) return;
      expect(setlist.name, isNotEmpty);
      expect(songs, isNotEmpty);
      // effectiveItems is what the PDF iterates; a break divider has no songId.
      expect(setlist.effectiveItems.where((i) => i.isBreak), isNotEmpty,
          reason: 'expected the medley divider to survive parsing');
      expect(setlist.eventKit?.people ?? const [], isNotEmpty,
          reason: 'the lineup section needs an Event Kit roster');
      expect(
        setlist.effectiveItems.where((i) => i.performerIds.isNotEmpty),
        isNotEmpty,
        reason: 'per-song performers are the whole point of the lineup section',
      );
    });

    test('renders a valid PDF for every layout', () async {
      if (!File(fixturePath).existsSync()) return;
      for (final layout in SetlistPdfLayout.values) {
        // The performer layout needs a performerId; use the first roster entry.
        final performerId = layout == SetlistPdfLayout.performer
            ? setlist.eventKit!.people.first.id
            : null;
        final bytes = await PdfService.buildSetlistBytes(
          setlist,
          songs,
          layout: layout,
          performerId: performerId,
        );
        expect(bytes.length, greaterThan(2000), reason: '$layout produced a suspiciously small file');
        // A PDF must start with %PDF- and end with the EOF marker.
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: '$layout is not a PDF');
        expect(
          String.fromCharCodes(bytes.skip(bytes.length - 8)),
          contains('EOF'),
          reason: '$layout is truncated',
        );
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('writes the file when FLOWGROOVE_PDF_OUT is set', () async {
      final out = Platform.environment['FLOWGROOVE_PDF_OUT'];
      if (out == null || !File(fixturePath).existsSync()) {
        markTestSkipped('FLOWGROOVE_PDF_OUT not set');
        return;
      }
      final dir = Directory(out);
      dir.createSync(recursive: true);
      for (final layout in [
        SetlistPdfLayout.detailed,
        SetlistPdfLayout.compact,
        SetlistPdfLayout.eventGuide,
      ]) {
        final bytes = await PdfService.buildSetlistBytes(setlist, songs, layout: layout);
        final name = PdfService.setlistFileName(setlist, layout, null, songs);
        final file = File('${dir.path}/$name');
        file.writeAsBytesSync(bytes);
        // ignore: avoid_print
        print('wrote ${file.path} (${(bytes.length / 1024).round()} KB)');
      }
      // One per-performer copy each, so every guest gets their own running order.
      for (final person in setlist.eventKit!.people) {
        final bytes = await PdfService.buildSetlistBytes(
          setlist, songs,
          layout: SetlistPdfLayout.performer,
          performerId: person.id,
        );
        final name = PdfService.setlistFileName(
            setlist, SetlistPdfLayout.performer, person.id, songs);
        File('${dir.path}/$name').writeAsBytesSync(bytes);
        // ignore: avoid_print
        print('wrote ${dir.path}/$name (${person.name})');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
