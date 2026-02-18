import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/data_providers.dart';
import '../../models/song.dart';
import '../../models/link.dart';
import '../../theme/app_theme.dart';

class AddSongScreen extends ConsumerStatefulWidget {
  const AddSongScreen({super.key});

  @override
  ConsumerState<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends ConsumerState<AddSongScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _originalKeyController = TextEditingController();
  final _originalBpmController = TextEditingController();
  final _ourKeyController = TextEditingController();
  final _ourBpmController = TextEditingController();
  final _notesController = TextEditingController();
  final List<Link> _links = [];
  final List<String> _selectedTags = [];

  final List<String> _availableTags = [
    'ready',
    'learning',
    'hard',
    'slow',
    'fast',
  ];

  final List<String> _keys = [
    'C',
    'C#',
    'Db',
    'D',
    'D#',
    'Eb',
    'E',
    'F',
    'F#',
    'Gb',
    'G',
    'G#',
    'Ab',
    'A',
    'A#',
    'Bb',
    'B',
    'Cm',
    'C#m',
    'Dbm',
    'Dm',
    'D#m',
    'Ebm',
    'Em',
    'Fm',
    'F#m',
    'Gbm',
    'Gm',
    'G#m',
    'Abm',
    'Am',
    'A#m',
    'Bbm',
    'Bm',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _originalKeyController.dispose();
    _originalBpmController.dispose();
    _ourKeyController.dispose();
    _ourBpmController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _copyFromOriginal() {
    setState(() {
      _ourKeyController.text = _originalKeyController.text;
      _ourBpmController.text = _originalBpmController.text;
    });
  }

  void _addLink() {
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
                value: selectedType,
                items: const [
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
                onChanged: (value) {
                  selectedType = value!;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://...',
                ),
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
                  setState(() {
                    _links.add(
                      Link(type: selectedType, url: urlController.text),
                    );
                  });
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

  void _saveSong() {
    if (_formKey.currentState!.validate()) {
      final song = Song(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        originalKey: _originalKeyController.text.trim().isNotEmpty
            ? _originalKeyController.text.trim()
            : null,
        originalBPM: _originalBpmController.text.trim().isNotEmpty
            ? int.tryParse(_originalBpmController.text.trim())
            : null,
        ourKey: _ourKeyController.text.trim().isNotEmpty
            ? _ourKeyController.text.trim()
            : null,
        ourBPM: _ourBpmController.text.trim().isNotEmpty
            ? int.tryParse(_ourBpmController.text.trim())
            : null,
        links: _links,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        tags: _selectedTags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      ref.read(songsProvider.notifier).addSong(song);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${song.title} added')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Song'),
        actions: [
          TextButton(
            onPressed: _saveSong,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Song title',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _artistController,
                decoration: const InputDecoration(
                  labelText: 'Artist',
                  hintText: 'Artist name',
                ),
              ),
              const SizedBox(height: 24),
              Text('Original', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _originalKeyController.text.isEmpty
                          ? null
                          : _originalKeyController.text,
                      decoration: const InputDecoration(labelText: 'Key'),
                      items: _keys.map((key) {
                        return DropdownMenuItem(value: key, child: Text(key));
                      }).toList(),
                      onChanged: (value) {
                        _originalKeyController.text = value ?? '';
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _originalBpmController,
                      decoration: const InputDecoration(
                        labelText: 'BPM',
                        hintText: '120',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Our Key & BPM',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed: _copyFromOriginal,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy from original'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _ourKeyController.text.isEmpty
                          ? null
                          : _ourKeyController.text,
                      decoration: const InputDecoration(labelText: 'Key'),
                      items: _keys.map((key) {
                        return DropdownMenuItem(value: key, child: Text(key));
                      }).toList(),
                      onChanged: (value) {
                        _ourKeyController.text = value ?? '';
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _ourBpmController,
                      decoration: const InputDecoration(
                        labelText: 'BPM',
                        hintText: '120',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Links', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: _addLink,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Link'),
                  ),
                ],
              ),
              if (_links.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _links.asMap().entries.map((entry) {
                    return Chip(
                      label: Text(
                        entry.value.type.replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _links.removeAt(entry.key);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              Text('Notes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'Song structure, notes for band members...',
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              Text('Tags', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                    selectedColor: AppColors.color1.withOpacity(0.3),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
