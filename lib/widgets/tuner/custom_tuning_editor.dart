import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instrument.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Custom Tuning Editor - Bottom sheet for creating custom tunings.
///
/// Visual interface: One row per string with a note selector.
/// User picks note name + octave for each string.
/// Saves to in-memory custom tunings list.
class CustomTuningEditor extends ConsumerStatefulWidget {
  const CustomTuningEditor({super.key});

  @override
  ConsumerState<CustomTuningEditor> createState() => _CustomTuningEditorState();
}

class _CustomTuningEditorState extends ConsumerState<CustomTuningEditor> {
  final _nameController = TextEditingController();
  late List<String> _selectedNotes;
  late int _stringCount;
  late List<String> _stringLabels;

  // Available note names for picker
  static const _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  // Available octaves
  static const _octaves = [1, 2, 3, 4, 5];

  @override
  void initState() {
    super.initState();
    _initFromState();
  }

  void _initFromState() {
    final state = ref.read(tunerProvider);
    final instrument = state.selectedInstrument;

    _stringCount = instrument?.stringCount ?? 6;
    _stringLabels = instrument?.stringLabels ??
        List.generate(_stringCount, (i) => '${i + 1}');

    // Initialize with the current tuning's notes or defaults
    final currentTuning = state.selectedTuning;
    _selectedNotes = currentTuning != null && currentTuning.notes.isNotEmpty
        ? List.from(currentTuning.notes)
        : List.generate(_stringCount, (_) => 'E2');

    // Pad or trim to match string count
    while (_selectedNotes.length < _stringCount) {
      _selectedNotes.add('E2');
    }
    if (_selectedNotes.length > _stringCount) {
      _selectedNotes = _selectedNotes.sublist(0, _stringCount);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: MonoPulseColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MonoPulseRadius.xlarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: MonoPulseSpacing.sm),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MonoPulseColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MonoPulseSpacing.xl,
              MonoPulseSpacing.lg,
              MonoPulseSpacing.xl,
              MonoPulseSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Custom Tuning',
                  style: MonoPulseTypography.headlineSmall.copyWith(
                    color: MonoPulseColors.textHighEmphasis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  color: MonoPulseColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: MonoPulseColors.borderSubtle),

          // Tuning name input
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MonoPulseSpacing.xl,
              vertical: MonoPulseSpacing.md,
            ),
            child: TextField(
              controller: _nameController,
              style: MonoPulseTypography.bodyLarge.copyWith(
                color: MonoPulseColors.textHighEmphasis,
              ),
              decoration: InputDecoration(
                hintText: 'Tuning name (e.g., My Open G)',
                hintStyle: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.textTertiary,
                ),
                filled: true,
                fillColor: MonoPulseColors.surfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MonoPulseSpacing.lg,
                  vertical: MonoPulseSpacing.md,
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),

          // String editors
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xl),
              itemCount: _stringCount,
              itemBuilder: (context, index) {
                final label = index < _stringLabels.length
                    ? _stringLabels[index]
                    : '${index + 1}';
                final currentNote = _selectedNotes[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
                  child: _StringNotePicker(
                    stringLabel: label,
                    currentNote: currentNote,
                    noteNames: _noteNames,
                    octaves: _octaves,
                    onNoteChanged: (note) {
                      setState(() {
                        _selectedNotes[index] = note;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1, color: MonoPulseColors.borderSubtle),

          // Save button
          Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.xl),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveCustomTuning,
                child: const Text('Save Custom Tuning'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveCustomTuning() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a name for this tuning',
            style: MonoPulseTypography.bodyMedium.copyWith(
              color: MonoPulseColors.white,
            ),
          ),
          backgroundColor: MonoPulseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          ),
        ),
      );
      return;
    }

    final tuningId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final tuning = Tuning(
      id: tuningId,
      name: name,
      notes: List.from(_selectedNotes),
    );

    final notifier = ref.read(tunerProvider.notifier);
    notifier.addCustomTuning(tuning);
    notifier.selectTuning(tuning);

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }
}

class _StringNotePicker extends StatefulWidget {
  final String stringLabel;
  final String currentNote;
  final List<String> noteNames;
  final List<int> octaves;
  final void Function(String) onNoteChanged;

  const _StringNotePicker({
    required this.stringLabel,
    required this.currentNote,
    required this.noteNames,
    required this.octaves,
    required this.onNoteChanged,
  });

  @override
  State<_StringNotePicker> createState() => _StringNotePickerState();
}

class _StringNotePickerState extends State<_StringNotePicker> {
  late String _selectedNoteName;
  late int _selectedOctave;

  @override
  void initState() {
    super.initState();
    _parseCurrentNote();
  }

  void _parseCurrentNote() {
    // Parse "E2" -> noteName="E", octave=2
    final note = widget.currentNote;
    final match = RegExp(r'^([A-G]#?)(\d)$').firstMatch(note);
    if (match != null) {
      _selectedNoteName = match.group(1) ?? 'E';
      _selectedOctave = int.tryParse(match.group(2) ?? '2') ?? 2;
    } else {
      _selectedNoteName = 'E';
      _selectedOctave = 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // String label
        SizedBox(
          width: 32,
          child: Text(
            widget.stringLabel,
            style: MonoPulseTypography.labelMedium.copyWith(
              color: MonoPulseColors.textTertiary,
              fontWeight: MonoPulseTypography.semibold,
            ),
          ),
        ),
        const SizedBox(width: MonoPulseSpacing.md),

        // Note name dropdown
        Expanded(
          flex: 2,
          child: _DropdownSelector<String>(
            value: _selectedNoteName,
            items: widget.noteNames,
            onChanged: (value) {
              setState(() {
                _selectedNoteName = value!;
                _updateNote();
              });
            },
          ),
        ),
        const SizedBox(width: MonoPulseSpacing.md),

        // Octave dropdown
        Expanded(
          child: _DropdownSelector<int>(
            value: _selectedOctave,
            items: widget.octaves,
            onChanged: (value) {
              setState(() {
                _selectedOctave = value!;
                _updateNote();
              });
            },
          ),
        ),
      ],
    );
  }

  void _updateNote() {
    final note = '$_selectedNoteName$_selectedOctave';
    widget.onNoteChanged(note);
  }
}

class _DropdownSelector<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _DropdownSelector({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          dropdownColor: MonoPulseColors.surfaceRaised,
          style: MonoPulseTypography.bodyMedium.copyWith(
            color: MonoPulseColors.textHighEmphasis,
          ),
          icon: const Icon(
            Icons.arrow_drop_down,
            color: MonoPulseColors.textTertiary,
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
