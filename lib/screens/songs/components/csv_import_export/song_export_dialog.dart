/// Dialog for exporting songs to CSV.
library;

import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/services/csv/song_csv_service.dart';
import 'package:flowgroove/services/json/song_json_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/mono_pulse_theme.dart';
import '../../../../widgets/loading_indicator.dart';

/// Dialog for exporting songs to CSV file.
class SongExportDialog extends StatefulWidget {

  const SongExportDialog({required this.songs, super.key});
  /// List of songs to export.
  final List<Song> songs;

  @override
  State<SongExportDialog> createState() => _SongExportDialogState();
}

class _SongExportDialogState extends State<SongExportDialog> {
  final SongCsvService _service = SongCsvService();
  bool _isLoading = false;
  bool _exported = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.file_download),
                  SizedBox(width: 12),
                  Text(
                    'Export Songs',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: MonoPulseColors.textHighEmphasis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildContent(),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const LoadingIndicator();
    }

    if (_exported) {
      return _buildSuccessContent();
    }

    return _buildExportOptions();
  }

  Widget _buildExportOptions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Export ${widget.songs.length} song(s) to CSV file:',
          style: MonoPulseTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: MonoPulseColors.textHighEmphasis,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Save to file
            ElevatedButton.icon(
              onPressed: _exportToFile,
              icon: const Icon(Icons.save),
              label: const Text('Save to Device'),
            ),
            const SizedBox(width: 16),
            // Share
            ElevatedButton.icon(
              onPressed: _exportAndShare,
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Copy FlowGroove Song JSON (round-trips with paste-import; AI-friendly)
        OutlinedButton.icon(
          onPressed: _copyJson,
          icon: const Icon(Icons.data_object),
          label: const Text('Copy as JSON'),
        ),
        const SizedBox(height: 16),
        Text(
          'CSV opens in Excel/Google Sheets. JSON is the FlowGroove Song format — '
          'paste it into an AI to edit, or back into Import.',
          style: MonoPulseTypography.bodyMedium.copyWith(
            color: MonoPulseColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessContent() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle,
          color: MonoPulseColors.successGreen,
          size: 64,
        ),
        SizedBox(height: 16),
        Text(
          'Export Successful!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: MonoPulseColors.textHighEmphasis,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Songs exported to CSV',
          style: TextStyle(color: MonoPulseColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_exported ? 'Close' : 'Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToFile() async {
    setState(() => _isLoading = true);
    final success = await _service.exportToFile(widget.songs);
    if (!mounted) return;
    setState(() {
      _exported = success;
      _isLoading = false;
    });
  }

  Future<void> _copyJson() async {
    final jsonStr = const SongJsonCodec().exportToString(widget.songs);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.songs.length} song(s) copied as JSON')),
    );
  }

  Future<void> _exportAndShare() async {
    setState(() => _isLoading = true);
    final success = await _service.exportAndShare(widget.songs);
    if (!mounted) return;
    setState(() {
      _exported = success;
      _isLoading = false;
    });
    if (success) {
      Navigator.of(context).pop();
    }
  }
}
