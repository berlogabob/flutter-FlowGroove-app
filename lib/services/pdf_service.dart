import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/setlist.dart';
import '../models/song.dart';

class PdfService {
  static Future<void> exportSetlist(Setlist setlist, List<Song> songs) async {
    final pdf = pw.Document();

    final songWidgets = <pw.Widget>[];

    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      songWidgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 30,
                height: 30,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue100,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    '${i + 1}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      song.title,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      song.artist,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (song.ourKey != null)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        song.ourKey!,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ),
                  if (song.ourBPM != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${song.ourBPM} BPM',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange800,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              setlist.name,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            if (setlist.description != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                setlist.description!,
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ],
            if (setlist.eventDate != null || setlist.eventLocation != null) ...[
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  if (setlist.eventDate != null)
                    pw.Text(
                      '📅 ${setlist.eventDate}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  if (setlist.eventDate != null &&
                      setlist.eventLocation != null)
                    pw.Text('  •  ', style: const pw.TextStyle(fontSize: 10)),
                  if (setlist.eventLocation != null)
                    pw.Text(
                      '📍 ${setlist.eventLocation}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ],
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 20),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${songs.length} songs',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Text(
              'Generated by RepSync',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => songWidgets,
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${setlist.name.replaceAll(' ', '_')}_setlist.pdf',
    );
  }
}
