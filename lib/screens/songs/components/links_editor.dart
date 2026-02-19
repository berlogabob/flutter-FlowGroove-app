import 'package:flutter/material.dart';
import '../../../models/link.dart';
import '../../../theme/app_theme.dart';

/// A widget for managing a collection of links.
///
/// This widget displays existing links as chips and provides
/// functionality to add and remove links through a dialog.
class LinksEditor extends StatelessWidget {
  /// The current list of links.
  final List<Link> links;

  /// Callback when a link is added.
  final Function(Link link) onAddLink;

  /// Callback when a link is removed.
  final Function(int index) onRemoveLink;

  const LinksEditor({
    super.key,
    required this.links,
    required this.onAddLink,
    required this.onRemoveLink,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Links',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
    showDialog(
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
                  onAddLink(
                    Link(type: selectedType, url: urlController.text),
                  );
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
  final Link link;
  final int index;
  final VoidCallback onDeleted;

  const _LinkChip({
    required this.link,
    required this.index,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        link.type.replaceAll('_', ' '),
        style: const TextStyle(fontSize: 12),
      ),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      backgroundColor: AppColors.color3,
    );
  }
}
