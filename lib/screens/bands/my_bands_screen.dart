import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/band.dart';
import '../../theme/app_theme.dart';

class MyBandsScreen extends ConsumerWidget {
  const MyBandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bands = ref.watch(bandsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Bands')),
      body: bands.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bands.length,
              itemBuilder: (context, index) {
                final band = bands[index];
                return _buildBandCard(context, band);
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'create',
            onPressed: () => Navigator.pushNamed(context, '/create-band'),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'join',
            onPressed: () => Navigator.pushNamed(context, '/join-band'),
            child: const Icon(Icons.group_add),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No bands yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create or join a band to get started',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/create-band'),
            icon: const Icon(Icons.add),
            label: const Text('Create Band'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/join-band'),
            icon: const Icon(Icons.group_add),
            label: const Text('Join Band'),
          ),
        ],
      ),
    );
  }

  Widget _buildBandCard(BuildContext context, Band band) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.color5,
          child: Text(
            band.name.isNotEmpty ? band.name[0].toUpperCase() : 'B',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          band.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${band.members.length} members'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pushNamed(context, '/band-settings', arguments: band);
        },
      ),
    );
  }
}
