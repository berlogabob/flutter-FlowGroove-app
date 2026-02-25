/// Dialog for exporting songs to CSV.
import 'package:flutter/material.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/services/csv/song_csv_service.dart';

/// Dialog for exporting songs to CSV file.
class SongExportDialog extends StatefulWidget {
  /// List of songs to export.
  final List<Song> songs;

  const SongExportDialog({
    super.key,
    required this.songs,
  });

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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.file_download),
                  const SizedBox(width: 12),
                  const Text(
                    'Export Songs to CSV',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Padding(
              padding: const EdgeInsets.all(24.0),
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
      return const Center(child: CircularProgressIndicator());
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
          style: const TextStyle(fontSize: 16),
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
        const SizedBox(height: 16),
        const Text(
          'CSV file can be opened in Excel, Google Sheets, or imported back to RepSync',
          style: TextStyle(color: Colors.grey, fontSize: 14),
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
          color: Colors.green,
          size: 64,
        ),
        SizedBox(height: 16),
        Text(
          'Export Successful!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'Songs exported to CSV',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
    final filePath = await _service.exportToFile(widget.songs);
    setState(() {
      _exported = filePath != null;
      _isLoading = false;
    });
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
