import 'package:flutter/material.dart';
import '../../../models/link.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../utils/song_tags.dart';
import '../../../widgets/tag_input_dialog.dart';
import 'bpm_selector.dart';
import 'links_editor.dart';

/// A comprehensive form widget for adding or editing songs.
///
/// This widget contains all the form fields needed for song input:
/// - Title and artist text fields
/// - Original and "our" key/BPM selectors
/// - Links editor
/// - Notes field
/// - Tags selection
class SongForm extends StatelessWidget {

  const SongForm({
    required this.formKey,
    required this.titleController,
    required this.artistController,
    required this.originalBpmController,
    required this.ourBpmController,
    required this.notesController,
    required this.links,
    required this.selectedTags,
    required this.availableTags,
    required this.originalKeyBase,
    required this.originalKeyModifier,
    required this.ourKeyBase,
    required this.ourKeyModifier,
    required this.onOriginalKeyChanged,
    required this.onOurKeyChanged,
    required this.onAddLink,
    required this.onRemoveLink,
    required this.onTagChanged,
    required this.isEditing,
    this.onCopyFromOriginal,
    super.key,
  });
  /// Form key for validation.
  final GlobalKey<FormState> formKey;

  /// Controller for the title field.
  final TextEditingController titleController;

  /// Controller for the artist field.
  final TextEditingController artistController;

  /// Controller for the original BPM field.
  final TextEditingController originalBpmController;

  /// Controller for the "our" BPM field.
  final TextEditingController ourBpmController;

  /// Controller for the notes field.
  final TextEditingController notesController;

  /// Current list of links.
  final List<Link> links;

  /// Currently selected tags.
  final List<String> selectedTags;

  /// Available tags to choose from.
  final List<String> availableTags;

  /// Original key base note.
  final String originalKeyBase;

  /// Original key modifier.
  final String originalKeyModifier;

  /// "Our" key base note.
  final String ourKeyBase;

  /// "Our" key modifier.
  final String ourKeyModifier;

  /// Callback when original key changes.
  final Function(String, String) onOriginalKeyChanged;

  /// Callback when "our" key changes.
  final Function(String, String) onOurKeyChanged;

  /// Callback when a link is added.
  final Function(Link) onAddLink;

  /// Callback when a link is removed.
  final Function(int) onRemoveLink;

  /// Callback when a tag selection changes.
  final Function(String tag, bool selected) onTagChanged;

  /// Callback when copy from original is triggered.
  final VoidCallback? onCopyFromOriginal;

  /// Whether we are in edit mode (vs. add mode).
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          // Title field
          TextFormField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title *'),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Title required' : null,
          ),
          const SizedBox(height: 16),
          // Artist field
          TextFormField(
            controller: artistController,
            decoration: const InputDecoration(labelText: 'Artist'),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          // Original key and BPM
          KeyBpmSelector(
            base: originalKeyBase,
            modifier: originalKeyModifier,
            bpmController: originalBpmController,
            label: 'Original',
            onKeyChanged: onOriginalKeyChanged,
          ),
          const SizedBox(height: 24),
          // Our key and BPM section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Our Key & BPM',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: onCopyFromOriginal,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Our key and BPM
          KeyBpmSelector(
            base: ourKeyBase,
            modifier: ourKeyModifier,
            bpmController: ourBpmController,
            label: 'Our',
            onKeyChanged: onOurKeyChanged,
          ),
          const SizedBox(height: 24),
          // Links editor
          LinksEditor(
            links: links,
            onAddLink: onAddLink,
            onRemoveLink: onRemoveLink,
          ),
          const SizedBox(height: 24),
          // Notes field
          const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: notesController,
            decoration: const InputDecoration(hintText: 'Notes...'),
            maxLines: 3,
          ),
          const SizedBox(height: MonoPulseSpacing.xxxl),
          // Tags selection
          const Text(
            'Tags',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: MonoPulseColors.textPrimary,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.md),
          Wrap(
            spacing: MonoPulseSpacing.md,
            runSpacing: MonoPulseSpacing.sm,
            children: [
              // Predefined suggestions plus any custom tags already selected.
              for (final tag in {...availableTags, ...selectedTags})
                FilterChip(
                  label: Text(
                    tag,
                    style: const TextStyle(
                      color: MonoPulseColors.textPrimary,
                    ),
                  ),
                  selected: selectedTags.contains(tag),
                  onSelected: (selected) => onTagChanged(tag, selected),
                  selectedColor: MonoPulseColors.accentOrangeSubtle,
                  checkmarkColor: MonoPulseColors.accentOrange,
                ),
              ActionChip(
                avatar: const Icon(
                  Icons.add,
                  size: 18,
                  color: MonoPulseColors.accentOrange,
                ),
                label: const Text('Add tag'),
                onPressed: () => _editTags(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Opens the tag editor so the user can add custom tags or remove existing
  /// ones, then reconciles the result through [onTagChanged].
  Future<void> _editTags(BuildContext context) async {
    final result = await TagInputDialog.show(
      context,
      initialTags: selectedTags,
      title: 'Tags',
      hintText: 'Add a tag',
      suggestions: availableTags,
    );
    if (result == null) return;

    final normalized = SongTags.normalizeAll(result);
    // Remove tags the user deselected.
    for (final tag in List<String>.from(selectedTags)) {
      if (!normalized.contains(tag)) onTagChanged(tag, false);
    }
    // Add newly entered tags.
    for (final tag in normalized) {
      if (!selectedTags.contains(tag)) onTagChanged(tag, true);
    }
  }
}
