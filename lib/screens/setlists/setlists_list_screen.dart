import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../models/setlist.dart';
import '../../theme/app_theme.dart';

class SetlistsListScreen extends ConsumerWidget {
  const SetlistsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(setlistsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Setlists')),
      body: setlistsAsync.when(
        data: (setlists) => setlists.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: setlists.length,
                itemBuilder: (context, index) =>
                    _buildSetlistCard(context, setlists[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/create-setlist'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No setlists yet', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Create a setlist for your gig'),
        ],
      ),
    );
  }

  Widget _buildSetlistCard(BuildContext context, Setlist setlist) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.color3,
          child: const Icon(Icons.queue_music, color: AppColors.color4),
        ),
        title: Text(
          setlist.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${setlist.songIds.length} songs'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
