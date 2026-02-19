import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/band.dart';
import '../../theme/app_theme.dart';
import '../../widgets/band_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/confirmation_dialog.dart';

/// Screen for displaying the user's bands with search functionality.
///
/// This screen shows all bands the user is a member of with the ability
/// to search by band name.
class MyBandsScreen extends ConsumerStatefulWidget {
  const MyBandsScreen({super.key});

  @override
  ConsumerState<MyBandsScreen> createState() => _MyBandsScreenState();
}

class _MyBandsScreenState extends ConsumerState<MyBandsScreen> {
  String _searchQuery = '';

  /// Filter bands based on the search query.
  ///
  /// Searches in band name (case-insensitive).
  List<Band> _filterBands(List<Band> bands) {
    if (_searchQuery.trim().isEmpty) {
      return bands;
    }

    final query = _searchQuery.toLowerCase().trim();
    return bands.where((band) {
      return band.name.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bandsAsync = ref.watch(bandsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Bands')),
      body: bandsAsync.when(
        data: (bands) => _buildContent(context, ref, bands),
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

  Widget _buildContent(BuildContext context, WidgetRef ref, List<Band> bands) {
    final filteredBands = _filterBands(bands);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: CustomTextField(
            hint: 'Search bands...',
            prefixIcon: Icons.search,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: filteredBands.isEmpty
              ? _buildEmptyState(bands.isEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredBands.length,
                  itemBuilder: (context, index) =>
                      _buildBandCard(context, ref, filteredBands[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    if (isEmpty) {
      return EmptyState.bands(
        onCreate: () => Navigator.pushNamed(context, '/create-band'),
      );
    }
    return EmptyState.search(query: _searchQuery);
  }

  Widget _buildBandCard(BuildContext context, WidgetRef ref, Band band) {
    return BandCard(
      id: band.id,
      name: band.name,
      memberCount: band.members.length,
      description: band.description,
      onTap: () => _showInviteDialog(context, ref, band),
      onEdit: () =>
          Navigator.pushNamed(context, '/edit-band', arguments: band),
      onDelete: () => _confirmDelete(context, ref, band),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Band band) async {
    final confirmed = await ConfirmationDialog.showDeleteDialog(
      context,
      title: 'Leave Band',
      message: 'Are you sure you want to leave this band?',
      confirmLabel: 'Leave',
    );

    if (confirmed) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        final service = ref.read(firestoreServiceProvider);
        
        // Remove user from global band members
        final updatedMembers = band.members
            .where((m) => m.uid != user.uid)
            .toList();
        final updatedBand = band.copyWith(members: updatedMembers);
        await service.saveBandToGlobal(updatedBand);
        
        // Remove from user's bands collection
        await service.removeUserFromBand(band.id, user.uid);
      }
    }
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref, Band band) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) =>
          _InviteMemberDialog(band: band, currentUserId: user.uid),
    );
  }
}

class _InviteMemberDialog extends ConsumerStatefulWidget {
  final Band band;
  final String currentUserId;

  const _InviteMemberDialog({required this.band, required this.currentUserId});

  @override
  ConsumerState<_InviteMemberDialog> createState() =>
      _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<_InviteMemberDialog> {
  late String _inviteCode;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _inviteCode = widget.band.inviteCode ?? '';
    if (_inviteCode.isEmpty) {
      _generateNewCode();
    }
  }

  void _generateNewCode() async {
    setState(() => _isRegenerating = true);
    final newCode = Band.generateUniqueInviteCode();

    final updatedBand = widget.band.copyWith(inviteCode: newCode);
    
    // Save to global collection
    await ref.read(firestoreServiceProvider).saveBandToGlobal(updatedBand);
    
    // Save to user's collection
    await ref.read(firestoreProvider).saveBand(updatedBand, widget.currentUserId);

    setState(() {
      _inviteCode = newCode;
      _isRegenerating = false;
    });
  }

  Future<void> _shareInvite() async {
    final message =
        '🎸 Join my band "${widget.band.name}" on RepSync!\n\n'
        'Use code: $_inviteCode\n'
        'Or click the link to join: repsync.app/join/$_inviteCode\n\n'
        'Download RepSync: repsync.app';

    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showShareOptions(message);
    }
  }

  void _showShareOptions(String message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy to clipboard'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share via...'),
              onTap: () {
                Navigator.pop(context);
                shareText(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              onTap: () {
                Navigator.pop(context);
                final emailUri = Uri(
                  scheme: 'mailto',
                  queryParameters: {
                    'subject': 'Join my band "${widget.band.name}"',
                    'body': message,
                  },
                );
                launchUrl(emailUri);
              },
            ),
            ListTile(
              leading: const Icon(Icons.telegram),
              title: const Text('Telegram'),
              onTap: () {
                Navigator.pop(context);
                final telegramUri = Uri.parse(
                  'https://t.me/share/url?url=${Uri.encodeComponent(message)}',
                );
                launchUrl(telegramUri, mode: LaunchMode.externalApplication);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                final whatsappUri = Uri.parse(
                  'https://wa.me/?text=${Uri.encodeComponent(message)}',
                );
                launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> shareText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied! Paste in any app to share.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _inviteCode));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code copied!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Invite to ${widget.band.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Share this code with band members:'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.color2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _isRegenerating ? 'Generating...' : _inviteCode,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _generateNewCode,
                icon: const Icon(Icons.refresh),
                label: const Text('New Code'),
              ),
              TextButton.icon(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              TextButton.icon(
                onPressed: _shareInvite,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
