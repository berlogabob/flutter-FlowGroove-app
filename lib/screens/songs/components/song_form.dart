import 'package:flutter/material.dart';
import '../../../models/beat_mode.dart';
import '../../../models/link.dart';
import '../../../models/section.dart';
import '../../../models/song_suggestion.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../utils/song_tags.dart';
import '../../../widgets/autocomplete_type_ahead.dart';
import '../../../widgets/tag_input_dialog.dart';
import 'bpm_selector.dart';
import 'collapsible_section.dart';
import 'links_editor.dart';
import 'metronome_pattern_editor.dart';
import 'song_constructor/song_constructor.dart';
import 'song_constructor/widgets/pill_view.dart';

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
    required this.sections,
    required this.onSectionsChanged,
    required this.accentBeats,
    required this.regularBeats,
    required this.beatModes,
    required this.onBeatModeChanged,
    required this.onAccentBeatsChanged,
    required this.onRegularBeatsChanged,
    required this.isEditing,
    this.onCopyFromOriginal,
    this.onSuggestionSelected,
    this.bandId,
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
  final void Function(String, String) onOriginalKeyChanged;

  /// Callback when "our" key changes.
  final void Function(String, String) onOurKeyChanged;

  /// Callback when a link is added.
  final void Function(Link) onAddLink;

  /// Callback when a link is removed.
  final void Function(int) onRemoveLink;

  /// Callback when a tag selection changes.
  final void Function(String tag, bool selected) onTagChanged;

  /// Current song structure sections (the "song scheme").
  final List<Section> sections;

  /// Callback when the song structure changes.
  final void Function(List<Section>) onSectionsChanged;

  /// Beats per measure (metronome grid rows).
  final int accentBeats;

  /// Subdivisions per beat (metronome grid columns).
  final int regularBeats;

  /// 2D beat-mode grid (beats × subdivisions).
  final List<List<BeatMode>> beatModes;

  /// Callback when a single cell in the beat grid changes.
  final void Function(int beatIndex, int subdivisionIndex, BeatMode mode)
  onBeatModeChanged;

  /// Callback when the beats-per-measure count changes.
  final ValueChanged<int> onAccentBeatsChanged;

  /// Callback when the subdivisions-per-beat count changes.
  final ValueChanged<int> onRegularBeatsChanged;

  /// Callback when copy from original is triggered.
  final VoidCallback? onCopyFromOriginal;

  /// Whether we are in edit mode (vs. add mode).
  final bool isEditing;

  /// Callback when a song suggestion is picked from the title autocomplete.
  /// When null, the autocomplete search box is hidden.
  final ValueChanged<SongSuggestion>? onSuggestionSelected;

  /// Band context for scoping song suggestions.
  final String? bandId;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          // Song search autocomplete: type to find an existing song and
          // autofill the form. Only shown when a handler is wired (add flow).
          if (onSuggestionSelected != null && !isEditing) ...[
            AutocompleteTypeAhead(
              onSuggestionSelected: onSuggestionSelected!,
              bandId: bandId,
              hint: 'Search a song to autofill…',
            ),
            const SizedBox(height: MonoPulseSpacing.lg),
          ],
          // Title field
          TextFormField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title *'),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Title required' : null,
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          // Artist field
          TextFormField(
            controller: artistController,
            decoration: const InputDecoration(labelText: 'Artist'),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: MonoPulseSpacing.xxl),
          // Key & BPM — one collapsible bubble. Collapsed shows Our (or Original
          // when Our isn't set); expanded shows an aligned Original/Our grid.
          CollapsibleSection(
            title: 'Key & BPM',
            icon: Icons.music_note,
            initiallyExpanded: false,
            preview: _keyBpmPreview(
              originalBase: originalKeyBase,
              originalModifier: originalKeyModifier,
              originalBpm: originalBpmController.text,
              ourBase: ourKeyBase,
              ourModifier: ourKeyModifier,
              ourBpm: ourBpmController.text,
            ),
            child: KeyBpmGrid(
              originalBase: originalKeyBase,
              originalModifier: originalKeyModifier,
              originalBpmController: originalBpmController,
              onOriginalKeyChanged: onOriginalKeyChanged,
              ourBase: ourKeyBase,
              ourModifier: ourKeyModifier,
              ourBpmController: ourBpmController,
              onOurKeyChanged: onOurKeyChanged,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          // Links — collapsible bubble.
          CollapsibleSection(
            title: 'Links',
            icon: Icons.link,
            initiallyExpanded: false,
            preview: links.isEmpty
                ? _previewMuted('No links')
                : _previewMuted(
                    links.map((l) => l.type.replaceAll('_', ' ')).join('  ·  '),
                  ),
            child: LinksEditor(
              embedded: true,
              links: links,
              onAddLink: onAddLink,
              onRemoveLink: onRemoveLink,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          // Song structure ("scheme") — collapsible with a song-map preview.
          CollapsibleSection(
            title: 'Song Structure',
            icon: Icons.queue_music,
            initiallyExpanded: false,
            preview: sections.isEmpty
                ? _previewMuted('No structure yet')
                : SizedBox(height: 28, child: PillView(sections: sections)),
            child: SongConstructor(
              embedded: true,
              initialSections: sections,
              onChange: onSectionsChanged,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          // Notes — collapsible with a snippet preview.
          CollapsibleSection(
            title: 'Notes',
            icon: Icons.notes,
            initiallyExpanded: false,
            preview: notesController.text.trim().isEmpty
                ? _previewMuted('No notes')
                : _previewMuted(notesController.text.trim()),
            child: TextFormField(
              controller: notesController,
              decoration: const InputDecoration(hintText: 'Notes...'),
              maxLines: 3,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          // Tags — collapsible with the selected tags as preview.
          CollapsibleSection(
            title: 'Tags',
            icon: Icons.label_outline,
            initiallyExpanded: false,
            preview: selectedTags.isEmpty
                ? _previewMuted('No tags')
                : _previewAccent(selectedTags.join('  ·  ')),
            child: Wrap(
              spacing: MonoPulseSpacing.md,
              runSpacing: MonoPulseSpacing.sm,
              children: [
                // Predefined suggestions plus any custom tags already selected.
                for (final tag in {...availableTags, ...selectedTags})
                  FilterChip(
                    label: Text(
                      tag,
                      style: MonoPulseTypography.labelLarge.copyWith(
                        color: MonoPulseColors.textPrimary,
                      ),
                    ),
                    selected: selectedTags.contains(tag),
                    onSelected: (selected) => onTagChanged(tag, selected),
                    selectedColor: MonoPulseColors.accentOrange10,
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
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          // Metronome beat-grid editor (collapsible)
          CollapsibleSection(
            title: 'Metronome Settings',
            icon: Icons.music_note,
            initiallyExpanded: false,
            child: MetronomePatternEditor(
              accentBeats: accentBeats,
              regularBeats: regularBeats,
              beatModes: beatModes,
              onBeatModeChanged: onBeatModeChanged,
              onAccentBeatsChanged: onAccentBeatsChanged,
              onRegularBeatsChanged: onRegularBeatsChanged,
            ),
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

/// Collapsed preview for the Key & BPM bubble: just the effective scale + BPM
/// (Our when it's set — has a BPM or a key different from Original — else
/// Original), with no "Our"/"Original" label since which one it is doesn't matter
/// at a glance.
Widget _keyBpmPreview({
  required String originalBase,
  required String originalModifier,
  required String originalBpm,
  required String ourBase,
  required String ourModifier,
  required String ourBpm,
}) {
  final origKey = '$originalBase$originalModifier';
  final ourKey = '$ourBase$ourModifier';
  final oBpm = originalBpm.trim();
  final uBpm = ourBpm.trim();
  final hasOur = uBpm.isNotEmpty || ourKey != origKey;
  final key = hasOur ? ourKey : origKey;
  final bpm = hasOur ? uBpm : oBpm;
  final parts = <String>[
    key,
    if (bpm.isNotEmpty) '$bpm BPM',
  ];
  return _previewAccent(parts.join('  ·  '));
}

/// A muted collapsed-preview line (secondary colour, design-system body scale).
Widget _previewMuted(String text) => Text(
  text,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: MonoPulseTypography.bodySmall.copyWith(
    color: MonoPulseColors.textSecondary,
  ),
);

/// A highlighted collapsed-preview line (accent colour) for the "live" value.
Widget _previewAccent(String text) => Text(
  text,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: MonoPulseTypography.bodySmall.copyWith(
    color: MonoPulseColors.accentOrange,
  ),
);
