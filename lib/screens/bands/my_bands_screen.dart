import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
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
                    _buildBandCard(context, ref, bands[index]),
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

  Widget _buildBandCard(BuildContext context, WidgetRef ref, Band band) {
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () =>
                  Navigator.pushNamed(context, '/edit-band', arguments: band),
              tooltip: 'Edit band',
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _showInviteDialog(context, ref, band),
              tooltip: 'Invite members',
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
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
    final newCode = const Uuid().v4().substring(0, 8).toUpperCase();

    final updatedBand = widget.band.copyWith(inviteCode: newCode);
    await ref
        .read(firestoreProvider)
        .saveBand(updatedBand, widget.currentUserId);

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
