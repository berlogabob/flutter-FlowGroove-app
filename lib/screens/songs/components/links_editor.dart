import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/link.dart';
import '../../../theme/mono_pulse_theme.dart';

/// A widget for managing a collection of links.
///
/// This widget displays existing links as chips and provides
/// functionality to add and remove links through a dialog.
class LinksEditor extends StatelessWidget {

  const LinksEditor({
    required this.links,
    required this.onAddLink,
    required this.onRemoveLink,
    this.embedded = false,
    super.key,
  });
  /// The current list of links.
  final List<Link> links;

  /// Callback when a link is added.
  final void Function(Link link) onAddLink;

  /// Callback when a link is removed.
  final void Function(int index) onRemoveLink;

  /// When true, render only the chips + an "Add link" button (no own header),
  /// for embedding inside a [CollapsibleSection] that supplies the title.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (links.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: links
                  .asMap()
                  .entries
                  .map(
                    (e) => _LinkChip(
                      link: e.value,
                      index: e.key,
                      onDeleted: () => onRemoveLink(e.key),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showAddLinkDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add link'),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Links', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () => _showAddLinkDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        if (links.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: links
                .asMap()
                .entries
                .map(
                  (e) => _LinkChip(
                    link: e.value,
                    index: e.key,
                    onDeleted: () => onRemoveLink(e.key),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  void _showAddLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final urlController = TextEditingController();
        String selectedType = Link.typeYoutubeOriginal;
        return AlertDialog(
          title: const Text('Add Link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                items: const [
                  DropdownMenuItem(
                    value: Link.typeSpotify,
                    child: Text('Spotify'),
                  ),
                  DropdownMenuItem(
                    value: Link.typeYoutubeOriginal,
                    child: Text('YouTube Original'),
                  ),
                  DropdownMenuItem(
                    value: Link.typeYoutubeCover,
                    child: Text('YouTube Cover'),
                  ),
                  DropdownMenuItem(
                    value: Link.typeTabs,
                    child: Text('Tabs/Chords'),
                  ),
                  DropdownMenuItem(value: Link.typeDrums, child: Text('Drums')),
                  DropdownMenuItem(value: Link.typeOther, child: Text('Other')),
                ],
                onChanged: (value) => selectedType = value!,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (urlController.text.isNotEmpty) {
                  onAddLink(Link(type: selectedType, url: urlController.text));
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

/// Internal chip widget for displaying a single link.
class _LinkChip extends StatelessWidget {

  const _LinkChip({
    required this.link,
    required this.index,
    required this.onDeleted,
  });
  final Link link;
  final int index;
  final VoidCallback onDeleted;

  /// Open the link's URL externally (new tab on web). Best-effort — shows a
  /// snackbar if it can't be launched, mirroring the app's other launch sites.
  Future<void> _open(BuildContext context) async {
    final url = link.url.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show the service name (title) when present, else the humanised type.
    final label = link.title ?? link.type.replaceAll('_', ' ');
    return RawChip(
      // RawChip carries both a tap (open) and a delete action.
      onPressed: link.url.trim().isEmpty ? null : () => _open(context),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: MonoPulseColors.textPrimary,
        ),
      ),
      deleteIcon: const Icon(
        Icons.close,
        size: 16,
        color: MonoPulseColors.textSecondary,
      ),
      onDeleted: onDeleted,
      backgroundColor: MonoPulseColors.surfaceOverlay,
    );
  }
}
