import 'package:flutter/material.dart';
import '../models/section.dart';

/// Dialog for editing a section's name, duration, and notes.
class EditSectionDialog extends StatefulWidget {
  final Section section;

  const EditSectionDialog({
    super.key,
    required this.section,
  });

  @override
  State<EditSectionDialog> createState() => _EditSectionDialogState();
}

class _EditSectionDialogState extends State<EditSectionDialog> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late int _duration;
  String? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.section.name);
    _notesController = TextEditingController(text: widget.section.notes);
    _duration = widget.section.duration;
    _selectedTemplate = Section.templates.contains(widget.section.name)
        ? widget.section.name
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Section',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Template dropdown
            Text(
              'Section Type:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedTemplate,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              ),
              hint: const Text('Select template'),
              items: Section.templates.map((template) {
                return DropdownMenuItem(value: template, child: Text(template));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTemplate = value;
                  if (value != null) {
                    _nameController.text = value;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            // Name field (for custom names)
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Custom Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedTemplate = Section.templates.contains(value)
                      ? value
                      : null;
                });
              },
            ),
            const SizedBox(height: 16),
            // Duration field with helper buttons
            Text(
              'Duration (phrases):',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (int i = 1; i <= 4; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _duration = i;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _duration == i
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          foregroundColor: _duration == i
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                        ),
                        child: Text('$i'),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 60,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Custom',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        setState(() {
                          _duration = parsed;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Notes field
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (e.g., guitar chords)',
                hintText: 'Am C G',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Section name cannot be empty')),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'name': _nameController.text.trim(),
                      'notes': _notesController.text.trim(),
                      'duration': _duration,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
