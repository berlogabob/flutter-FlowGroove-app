import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/song.dart';
import '../../models/link.dart';
import '../../theme/app_theme.dart';

class AddSongScreen extends ConsumerStatefulWidget {
  final Song? song;

  const AddSongScreen({super.key, this.song});

  @override
  ConsumerState<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends ConsumerState<AddSongScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _originalBpmController = TextEditingController();
  final _ourBpmController = TextEditingController();
  final _notesController = TextEditingController();
  final List<Link> _links = [];
  final List<String> _selectedTags = [];

  String _originalKeyBase = 'C';
  String _originalKeyModifier = '';
  String _ourKeyBase = 'C';
  String _ourKeyModifier = '';

  final List<String> _keyBases = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  final List<String> _keyModifiers = ['', '#', 'b', 'm'];
  final List<String> _availableTags = [
    'ready',
    'learning',
    'hard',
    'slow',
    'fast',
  ];

  bool get _isEditing => widget.song != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final song = widget.song!;
      _titleController.text = song.title;
      _artistController.text = song.artist;
      _originalBpmController.text = song.originalBPM?.toString() ?? '';
      _ourBpmController.text = song.ourBPM?.toString() ?? '';
      _notesController.text = song.notes ?? '';
      _links.addAll(song.links);
      _selectedTags.addAll(song.tags);

      if (song.originalKey != null && song.originalKey!.isNotEmpty) {
        final orig = song.originalKey!;
        if (orig.length > 1 && orig.endsWith('m')) {
          _originalKeyBase = orig[0].toUpperCase();
          _originalKeyModifier = 'm';
        } else if (orig.length > 1) {
          _originalKeyBase = orig[0].toUpperCase();
          _originalKeyModifier = orig.substring(1);
        } else {
          _originalKeyBase = orig.toUpperCase();
          _originalKeyModifier = '';
        }
      }

      if (song.ourKey != null && song.ourKey!.isNotEmpty) {
        final our = song.ourKey!;
        if (our.length > 1 && our.endsWith('m')) {
          _ourKeyBase = our[0].toUpperCase();
          _ourKeyModifier = 'm';
        } else if (our.length > 1) {
          _ourKeyBase = our[0].toUpperCase();
          _ourKeyModifier = our.substring(1);
        } else {
          _ourKeyBase = our.toUpperCase();
          _ourKeyModifier = '';
        }
      }
    }
  }

  String _buildKey(String base, String modifier) {
    if (modifier == 'm') return '${base.toLowerCase()}m';
    return '$base$modifier';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _originalBpmController.dispose();
    _ourBpmController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _copyFromOriginal() {
    setState(() {
      _ourKeyBase = _originalKeyBase;
      _ourKeyModifier = _originalKeyModifier;
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
                initialValue: selectedType,
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
                  setState(
                    () => _links.add(
                      Link(type: selectedType, url: urlController.text),
                    ),
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

  Future<void> _saveSong() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    final originalKey = _buildKey(_originalKeyBase, _originalKeyModifier);
    final ourKey = _buildKey(_ourKeyBase, _ourKeyModifier);

    try {
      final song = Song(
        id: _isEditing ? widget.song!.id : const Uuid().v4(),
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        originalKey: originalKey.isNotEmpty ? originalKey : null,
        originalBPM: _originalBpmController.text.trim().isNotEmpty
            ? int.tryParse(_originalBpmController.text.trim())
            : null,
        ourKey: ourKey.isNotEmpty ? ourKey : null,
        ourBPM: _ourBpmController.text.trim().isNotEmpty
            ? int.tryParse(_ourBpmController.text.trim())
            : null,
        links: _links,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        tags: _selectedTags,
        createdAt: _isEditing ? widget.song!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final firestore = ref.read(firestoreProvider);
      await firestore.saveSong(song, user.uid);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${song.title} ${_isEditing ? 'updated' : 'added'}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildKeyRow(
    String label,
    String base,
    String modifier,
    TextEditingController bpmController,
    Function(String, String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        ),
        const SizedBox(height: 4),
        IntrinsicHeight(
          child: Row(
            children: [
              _buildMiniDropdown(
                base,
                _keyBases,
                (v) => onChanged(v ?? 'C', modifier),
              ),
              const SizedBox(width: 4),
              _buildMiniDropdown(
                modifier,
                _keyModifiers,
                (v) => onChanged(base, v ?? ''),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: bpmController,
                  decoration: const InputDecoration(
                    labelText: 'BPM',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniDropdown(
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        underline: const SizedBox(),
        items: items
            .map(
              (k) => DropdownMenuItem(
                value: k,
                child: Text(
                  k.isEmpty ? '-' : k,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Song' : 'Add Song'),
        actions: [
          TextButton(
            onPressed: _saveSong,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title *'),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Artist'),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _saveSong(),
            ),
            const SizedBox(height: 24),
            _buildKeyRow(
              'Original',
              _originalKeyBase,
              _originalKeyModifier,
              _originalBpmController,
              (b, m) => setState(() {
                _originalKeyBase = b;
                _originalKeyModifier = m;
              }),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Our Key & BPM',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _copyFromOriginal,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildKeyRow(
              'Our',
              _ourKeyBase,
              _ourKeyModifier,
              _ourBpmController,
              (b, m) => setState(() {
                _ourKeyBase = b;
                _ourKeyModifier = m;
              }),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Links',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addLink,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (_links.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _links
                    .asMap()
                    .entries
                    .map(
                      (e) => Chip(
                        label: Text(
                          e.value.type.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setState(() => _links.removeAt(e.key)),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 24),
            const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(hintText: 'Notes...'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _availableTags
                  .map(
                    (tag) => FilterChip(
                      label: Text(tag),
                      selected: _selectedTags.contains(tag),
                      onSelected: (s) => setState(
                        () => s
                            ? _selectedTags.add(tag)
                            : _selectedTags.remove(tag),
                      ),
                      selectedColor: AppColors.color1.withValues(alpha: 0.3),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
