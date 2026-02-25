/// Dialog for importing songs from CSV.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_repsync_app/services/csv/song_csv_parser.dart';
import 'package:flutter_repsync_app/services/csv/song_csv_service.dart';
import 'song_csv_preview_table.dart';

/// Dialog for importing songs from CSV file or clipboard.
class SongImportDialog extends StatefulWidget {
  const SongImportDialog({super.key});

  @override
  State<SongImportDialog> createState() => _SongImportDialogState();
}

class _SongImportDialogState extends State<SongImportDialog> {
  final SongCsvService _service = SongCsvService();
  bool _isLoading = false;
  SongParseResult? _result;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.file_upload),
                  const SizedBox(width: 12),
                  const Text(
                    'Import Songs from CSV',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(
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

    if (_result != null) {
      return _buildPreview();
    }

    return _buildImportOptions();
  }

  Widget _buildImportOptions() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose how to import songs:',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Import from file
              ElevatedButton.icon(
                onPressed: _importFromFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select CSV File'),
              ),
              const SizedBox(width: 16),
              // Import from clipboard
              ElevatedButton.icon(
                onPressed: _importFromClipboard,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste from Clipboard'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Supports CSV files from Google Sheets, Excel, or other apps',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_result == null) {
      return const SizedBox.shrink();
    }

    return SongCsvPreviewTable(
      songs: _result!.successful,
      errors: _result!.errors,
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_result != null) ...[
            TextButton(
              onPressed: _isLoading ? null : _reset,
              child: const Text('Back'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _isLoading ? null : _confirmImport,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'Import ${_result!.successful.length} Songs',
              ),
            ),
          ] else ...[
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _importFromFile() async {
    setState(() => _isLoading = true);
    final result = await _service.importFromFile();
    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  Future<void> _importFromClipboard() async {
    setState(() => _isLoading = true);
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final content = clipboardData?.text ?? '';
      if (content.isEmpty) {
        setState(() {
          _result = SongParseResult(
            successful: [],
            errors: ['Clipboard is empty'],
          );
          _isLoading = false;
        });
        return;
      }
      final result = await _service.importFromString(content);
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = SongParseResult(
          successful: [],
          errors: ['Failed to read clipboard: $e'],
        );
        _isLoading = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _result = null;
    });
  }

  void _confirmImport() {
    if (_result == null) return;

    // Return imported songs to parent
    Navigator.of(context).pop(_result!.successful);
  }
}
