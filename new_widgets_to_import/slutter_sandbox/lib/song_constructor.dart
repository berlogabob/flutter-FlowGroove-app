import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../models/section.dart';
import 'widgets/section_card.dart';
import 'widgets/section_picker.dart';
import 'widgets/edit_section_dialog.dart';
import 'widgets/pill_view.dart';

/// Main widget for the Song Structure Constructor.
/// Supports collapsed (pill visualization) and expanded (vertical list) states.
class SongConstructor extends StatefulWidget {
  /// Callback when the structure changes
  final Function(List<Section>)? onChange;

  /// Initial sections (optional)
  final List<Section>? initialSections;

  const SongConstructor({
    super.key,
    this.onChange,
    this.initialSections,
  });

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
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(25),
          child: SectionPicker(
            onSectionSelected: (name) {
              setState(() {
                _sections.add(Section(
                  id: _uuid.v4(),
                  name: name,
                  duration: 2,
                ));
              });
              _notifyChange();
              Navigator.pop(context);
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
        final index = _sections.indexOf(section);
        if (index != -1) {
          _sections[index] = section.copyWith(
            name: result['name'],
            notes: result['notes'],
            duration: result['duration'],
          );
        }
      });
      _notifyChange();
    }
  }

  void _deleteSection(Section section) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section'),
        content: Text('Delete "${section.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _sections.remove(section);
              });
              _notifyChange();
              Navigator.pop(context);
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

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final section = _sections.removeAt(oldIndex);
      _sections.insert(newIndex, section);
    });
    _notifyChange();
  }

  void _autoGenerate() {
    // AGENT TODO: Enhance random generation with more musical patterns
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
    
    // Export to console for Qwen testing
    debugPrint('Auto-generated structure:');
    debugPrint(_sections.map((s) => s.toJson()).toString());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Song Structure',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Row(
                  children: [
                    if (_expanded) ...[
                      ElevatedButton.icon(
                        onPressed: _autoGenerate,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Auto-Generate'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: Icon(
                        _expanded ? Icons.expand_more : Icons.expand_less,
                      ),
                      onPressed: _toggleExpanded,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Content based on state
            if (_expanded)
              _buildExpandedState()
            else
              _buildCollapsedState(),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedState() {
    return SizedBox(
      height: 20,
      child: PillView(sections: _sections),
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
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _sections.length,
                  onReorder: _onReorder,
                  itemBuilder: (context, index) {
                    final section = _sections[index];
                    return SectionCard(
                      key: ValueKey(section.id),
                      section: section,
                      onTap: () => _editSection(section),
                      onDelete: () => _deleteSection(section),
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
