import 'package:flutter/material.dart';
import '../../../models/link.dart';
import '../../../models/beat_mode.dart';
import '../../../models/section.dart';
import '../../../theme/mono_pulse_theme.dart';
import 'bpm_selector.dart';
import 'links_editor.dart';
import 'metronome_pattern_editor.dart';
import 'song_constructor/song_constructor.dart';
import 'collapsible_section.dart';

/// A comprehensive form widget for adding or editing songs.
///
/// This widget contains all the form fields needed for song input:
/// - Title and artist text fields
/// - Original and "our" key/BPM selectors
/// - Links editor
/// - Notes field
/// - Tags selection
/// - Metronome settings (accentBeats, regularBeats, beatModes)
class SongForm extends StatelessWidget {
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

  /// Number of beats per measure (metronome).
  final int accentBeats;

  /// Number of subdivisions per beat (metronome).
  final int regularBeats;

  /// 2D list of beat modes (metronome).
  final List<List<BeatMode>> beatModes;

  /// The song structure sections.
  final List<Section> sections;

  /// Callback when sections change.
  final Function(List<Section>)? onSectionsChanged;

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

  /// Callback when accentBeats changes.
  final Function(int)? onAccentBeatsChanged;

  /// Callback when regularBeats changes.
  final Function(int)? onRegularBeatsChanged;

  /// Callback when a beat mode changes.
  final Function(int, int, dynamic)? onBeatModeChanged;

  /// Callback when form is submitted (Enter key pressed).
  final VoidCallback? onSubmit;

  /// Whether we are in edit mode (vs. add mode).
  final bool isEditing;

  const SongForm({
    super.key,
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
    this.onCopyFromOriginal,
    this.onAccentBeatsChanged,
    this.onRegularBeatsChanged,
    this.onBeatModeChanged,
    this.onSubmit,
    required this.isEditing,
    this.accentBeats = 4,
    this.regularBeats = 1,
    this.beatModes = const [],
    this.sections = const [],
    this.onSectionsChanged,
  });

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
            onFieldSubmitted: (_) => onSubmit?.call(),
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
          // Song Structure Constructor
          SongConstructor(
            initialSections: sections,
            onChange: onSectionsChanged,
          ),
          const SizedBox(height: 24),
          // Links editor (collapsible)
          CollapsibleSection(
            title: 'Links',
            icon: Icons.link,
            initiallyExpanded: true,
            child: LinksEditor(
              links: links,
              onAddLink: onAddLink,
              onRemoveLink: onRemoveLink,
            ),
          ),
          const SizedBox(height: 24),
          // Notes field (collapsible)
          CollapsibleSection(
            title: 'Notes',
            icon: Icons.note_alt,
            initiallyExpanded: true,
            child: TextFormField(
              controller: notesController,
              decoration: const InputDecoration(
                hintText: 'Add notes about this song...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              maxLines: 3,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.xxxl),
          // Tags selection (collapsible)
          CollapsibleSection(
            title: 'Tags',
            icon: Icons.label,
            initiallyExpanded: false,
            child: Wrap(
              spacing: MonoPulseSpacing.md,
              runSpacing: MonoPulseSpacing.sm,
              children: availableTags
                  .map(
                    (tag) => FilterChip(
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
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.xxxl),
          // Metronome Settings (collapsible)
          CollapsibleSection(
            title: 'Metronome Settings',
            icon: Icons.music_note,
            initiallyExpanded: false,
            child: MetronomePatternEditor(
              accentBeats: accentBeats,
              regularBeats: regularBeats,
              beatModes: beatModes,
              onBeatModeChanged: (beatIndex, subdivisionIndex, mode) {
                onBeatModeChanged?.call(beatIndex, subdivisionIndex, mode);
              },
              onAccentBeatsChanged: onAccentBeatsChanged,
              onRegularBeatsChanged: onRegularBeatsChanged,
            ),
          ),
        ],
      ),
    );
  }
}
