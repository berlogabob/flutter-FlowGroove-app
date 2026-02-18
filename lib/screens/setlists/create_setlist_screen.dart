import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';

class CreateSetlistScreen extends ConsumerStatefulWidget {
  const CreateSetlistScreen({super.key});

  @override
  ConsumerState<CreateSetlistScreen> createState() =>
      _CreateSetlistScreenState();
}

class _CreateSetlistScreenState extends ConsumerState<CreateSetlistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _eventLocationController = TextEditingController();
  List<Song> _selectedSongs = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _eventDateController.dispose();
    _eventLocationController.dispose();
    super.dispose();
  }

  void _showSongPicker() async {
    final songsAsync = ref.read(songsProvider);
    final songs = songsAsync.valueOrNull ?? [];

    final result = await showModalBottomSheet<List<Song>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _SongPickerSheet(
          songs: songs,
          selectedSongs: _selectedSongs,
          scrollController: scrollController,
          onConfirm: (selected) {
            setState(() => _selectedSongs = selected);
            Navigator.pop(context);
          },
        ),
      ),
    );
    if (result != null) setState(() => _selectedSongs = result);
  }

  Future<void> _createSetlist() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    final setlist = Setlist(
      id: const Uuid().v4(),
      bandId: '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      eventDate: _eventDateController.text.trim().isNotEmpty
          ? _eventDateController.text.trim()
          : null,
      eventLocation: _eventLocationController.text.trim().isNotEmpty
          ? _eventLocationController.text.trim()
          : null,
      songIds: _selectedSongs.map((s) => s.id).toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.read(firestoreProvider).saveSetlist(setlist, user.uid);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setlist "${setlist.name}" created')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Setlist'),
        actions: [
          TextButton(
            onPressed: _createSetlist,
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
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Setlist Name *',
                prefixIcon: Icon(Icons.queue_music),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _eventDateController,
              decoration: const InputDecoration(
                labelText: 'Event Date',
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _eventLocationController,
              decoration: const InputDecoration(
                labelText: 'Event Location',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Songs (${_selectedSongs.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _showSongPicker,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedSongs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.music_note, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No songs added'),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedSongs.length,
                itemBuilder: (context, index) {
                  final song = _selectedSongs[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(song.title),
                      subtitle: Text(song.artist),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (song.ourBPM != null) Text('${song.ourBPM} '),
                          if (song.ourKey != null) Text(song.ourKey!),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _selectedSongs.removeAt(index)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SongPickerSheet extends StatefulWidget {
  final List<Song> songs;
  final List<Song> selectedSongs;
  final ScrollController scrollController;
  final Function(List<Song>) onConfirm;

  const _SongPickerSheet({
    required this.songs,
    required this.selectedSongs,
    required this.scrollController,
    required this.onConfirm,
  });

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  late List<Song> _tempSelected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.selectedSongs);
  }

  @override
  Widget build(BuildContext context) {
    final filteredSongs = widget.songs
        .where(
          (s) =>
              _searchQuery.isEmpty ||
              s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.artist.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Songs (${_tempSelected.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton(
                onPressed: () => widget.onConfirm(_tempSelected),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: filteredSongs.length,
            itemBuilder: (context, index) {
              final song = filteredSongs[index];
              final isSelected = _tempSelected.any((s) => s.id == song.id);
              return CheckboxListTile(
                value: isSelected,
                onChanged: (v) => setState(
                  () => v == true
                      ? _tempSelected.add(song)
                      : _tempSelected.removeWhere((s) => s.id == song.id),
                ),
                title: Text(song.title),
                subtitle: Text(song.artist),
              );
            },
          ),
        ),
      ],
    );
  }
}
