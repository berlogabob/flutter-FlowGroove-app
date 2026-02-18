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

    setState(() {
      _isLoading = true;
    });

    try {
      final code = _codeController.text.trim().toUpperCase();
      final bands = ref.read(bandsProvider);

      final band = bands.where((b) => b.inviteCode == code).firstOrNull;

      if (band == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid invite code')));
        }
        return;
      }

      final user = ref.read(currentUserProvider);
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Please login first')));
        }
        return;
      }

      final isMember = band.members.any((m) => m.uid == user.uid);
      if (isMember) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are already a member of this band'),
            ),
          );
        }
        return;
      }

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

      ref.read(bandsProvider.notifier).updateBand(updatedBand);

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                'Enter the invite code from your bandmate',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Invite Code *',
                  prefixIcon: Icon(Icons.vpn_key),
                  hintText: 'e.g. ABC123',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter invite code';
                  }
                  if (value.trim().length < 6) {
                    return 'Invite code is 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _joinBand,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Join Band'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
