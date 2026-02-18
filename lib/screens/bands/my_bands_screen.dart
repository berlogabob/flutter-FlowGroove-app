import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../models/band.dart';
import '../../theme/app_theme.dart';

class MyBandsScreen extends ConsumerWidget {
  const MyBandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandsAsync = ref.watch(bandsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Bands')),
      body: bandsAsync.when(
        data: (bands) => bands.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bands.length,
                itemBuilder: (context, index) =>
                    _buildBandCard(context, bands[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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
          const Text('No bands yet', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Create or join a band'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/create-band'),
            icon: const Icon(Icons.add),
            label: const Text('Create Band'),
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
      ),
    );
  }
}
