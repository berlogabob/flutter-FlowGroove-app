import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../models/setlist.dart';
import '../../theme/app_theme.dart';

class SetlistsListScreen extends ConsumerWidget {
  const SetlistsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlists = ref.watch(setlistsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Setlists')),
      body: setlists.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: setlists.length,
              itemBuilder: (context, index) {
                final setlist = setlists[index];
                return _buildSetlistCard(context, setlist);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/create-setlist'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No setlists yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a setlist for your next gig',
            style: TextStyle(color: Colors.grey[500]),
          ),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${setlist.songIds.length} songs'),
            if (setlist.eventDate != null) Text('📅 ${setlist.eventDate}'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: setlist.eventDate != null,
        onTap: () {
          Navigator.pushNamed(context, '/edit-setlist', arguments: setlist);
        },
      ),
    );
  }
}
