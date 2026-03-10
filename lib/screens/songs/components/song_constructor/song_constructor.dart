import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../../../../../models/section.dart';
import '../../../../../theme/mono_pulse_theme.dart';
import 'widgets/section_card.dart';
import 'widgets/section_picker.dart';
import 'widgets/edit_section_dialog.dart';
import 'widgets/pill_view.dart';

/// Main widget for the Song Structure Constructor.
/// Supports collapsed (pill visualization) and expanded (vertical list) states.
class SongConstructor extends StatefulWidget {
  /// Callback when the structure changes.
  final Function(List<Section>)? onChange;

  /// Initial sections (optional).
  final List<Section>? initialSections;

  const SongConstructor({super.key, this.onChange, this.initialSections});

  @override
  State<SongConstructor> createState() => _SongConstructorState();
}

class _SongConstructorState extends State<SongConstructor> {
  late List<Section> _sections;
  bool _expanded = false;
  final _uuid = const Uuid();
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _sections = widget.initialSections ?? [];
  }

  void _notifyChange() {
    widget.onChange?.call(_sections);
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  void _showSectionPicker() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(25),
          child: SectionPicker(
            onSectionSelected: (name) {
              setState(() {
                // Create new list instead of mutating
                _sections = [
                  ..._sections,
                  Section(id: _uuid.v4(), name: name, duration: 2),
                ];
              });
              _notifyChange();
              Navigator.pop(dialogContext);
            },
          ),
        ),
      ),
    );
  }

  void _editSection(Section section) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditSectionDialog(section: section),
    );

    if (result != null && mounted) {
      setState(() {
        // Use indexWhere with ID comparison for reliable lookup
        final index = _sections.indexWhere((s) => s.id == section.id);
        if (index != -1) {
          _sections[index] = section.copyWith(
            name: result['name'] as String?,
            notes: result['notes'] as String?,
            duration: result['duration'] as int?,
          );
        }
      });
      _notifyChange();
    }
  }

  void _deleteSection(Section section) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Section'),
        content: Text('Delete "${section.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // Remove by index using ID comparison
                final index = _sections.indexWhere((s) => s.id == section.id);
                if (index != -1) {
                  _sections = _sections
                      .where((s) => s.id != section.id)
                      .toList();
                }
              });
              _notifyChange();
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _autoGenerate() {
    final templates = Section.templates;
    final sectionCount = _random.nextInt(5) + 3; // 3-7 sections

    setState(() {
      _sections = List.generate(sectionCount, (index) {
        final template = templates[_random.nextInt(templates.length)];
        return Section(
          id: _uuid.v4(),
          name: template,
          duration: _random.nextInt(4) + 1, // 1-4 phrases
        );
      });
    });
    _notifyChange();

    // Export to console for debugging
    debugPrint('Auto-generated structure:');
    debugPrint(_sections.map((s) => s.toJson()).toString());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MonoPulseColors.surface,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderDefault, width: 1),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            child: Container(
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              child: Row(
                children: [
                  // Expand/collapse icon
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: MonoPulseColors.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Title
                  Expanded(
                    child: Text(
                      'Song Structure',
                      style: MonoPulseTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MonoPulseColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Auto-Generate button (always rendered, just hidden when collapsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IgnorePointer(
                      ignoring: !_expanded,
                      child: AnimatedOpacity(
                        opacity: _expanded ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: TextButton.icon(
                          onPressed: _autoGenerate,
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text(
                            'Auto',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content based on state
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Visibility(
              visible: _expanded,
              maintainState: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MonoPulseSpacing.lg,
                  vertical: 8,
                ),
                child: _buildExpandedState(),
              ),
            ),
          ),
          // Pill view when collapsed
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg, vertical: 8),
              child: SizedBox(height: 36, child: PillView(sections: _sections)),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section list with constrained height
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: _sections.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _sections.length,
                  itemBuilder: (context, index) {
                    final section = _sections[index];
                    return Dismissible(
                      key: ValueKey(section.id),
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        color: MonoPulseColors.accentOrange,
                        child: const Row(
                          children: [
                            Icon(Icons.edit, color: MonoPulseColors.textPrimary),
                            SizedBox(width: 8),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: MonoPulseColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: MonoPulseColors.error,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: MonoPulseColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.delete, color: MonoPulseColors.textPrimary),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          // Swipe left - delete directly (no dialog for swipe)
                          setState(() {
                            _sections = _sections
                                .where((s) => s.id != section.id)
                                .toList();
                          });
                          _notifyChange();
                          return true; // Dismiss the item
                        } else if (direction == DismissDirection.startToEnd) {
                          // Swipe right - edit
                          _editSection(section);
                          return false; // Don't dismiss
                        }
                        return false;
                      },
                      onDismissed: (direction) {
                        // Item was dismissed - already handled in confirmDismiss
                      },
                      child: SectionCard(
                        key: ValueKey(section.id),
                        section: section,
                        onTap: () => _editSection(section),
                        onDelete: () => _deleteSection(section),
                      ),
                    );
                  },
                ),
        ),
        // Empty state message
        if (_sections.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No sections yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
        // Add button
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _showSectionPicker,
          icon: const Icon(Icons.add),
          label: const Text('Add Section'),
        ),
      ],
    );
  }

  /// Export sections as JSON string
  String exportToJson() {
    final jsonList = _sections.map((s) => s.toJson()).toList();
    return jsonList.toString();
  }

  /// Get current sections
  List<Section> get sections => List.unmodifiable(_sections);
}
