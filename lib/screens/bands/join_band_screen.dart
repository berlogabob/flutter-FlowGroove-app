import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/band.dart';

class JoinBandScreen extends ConsumerStatefulWidget {
  const JoinBandScreen({super.key});

  @override
  ConsumerState<JoinBandScreen> createState() => _JoinBandScreenState();
}

class _JoinBandScreenState extends ConsumerState<JoinBandScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinBand() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login first')));
        return;
      }

      final service = ref.read(firestoreProvider);
      final code = _codeController.text.trim().toUpperCase();

      // Search in GLOBAL bands collection
      final band = await service.getBandByInviteCode(code);

      if (band == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid invite code')));
        return;
      }

      // Check if already a member
      if (band.members.any((m) => m.uid == user.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already a member')),
        );
        return;
      }

      // Add user to band members
      final updatedBand = band.copyWith(
        members: [
          ...band.members,
          BandMember(
            uid: user.uid,
            role: BandMember.roleEditor,
            displayName: user.displayName,
            email: user.email,
          ),
        ],
      );

      // Save to global collection
      await service.saveBandToGlobal(updatedBand);

      // Add to user's bands collection (for quick access)
      await service.addUserToBand(band.id, user.uid);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Joined "${band.name}"!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Band')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join a band',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter invite code',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _joinBand(),
                decoration: const InputDecoration(
                  labelText: 'Invite Code *',
                  prefixIcon: Icon(Icons.vpn_key),
                  hintText: 'ABC123',
                ),
                validator: (v) => (v == null || v.trim().length < 6)
                    ? 'Enter 6-char code'
                    : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _joinBand,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Join Band'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
