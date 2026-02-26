import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/auth/auth_provider.dart';
import '../../models/band.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/custom_app_bar.dart';

class JoinBandScreen extends ConsumerStatefulWidget {
  final String? inviteCode;

  const JoinBandScreen({super.key, this.inviteCode});

  @override
  ConsumerState<JoinBandScreen> createState() => _JoinBandScreenState();
}

class _JoinBandScreenState extends ConsumerState<JoinBandScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  Band? _band;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null) {
      _codeController.text = widget.inviteCode!;
      _loadBand();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadBand() async {
    if (_codeController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(firestoreProvider);
      final code = _codeController.text.trim().toUpperCase();
      final band = await service.getBandByInviteCode(code);

      if (band == null) {
        setState(() {
          _error = 'Invalid invite code';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _band = band;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading band: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _joinBand() async {
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;

    if (user == null) {
      // Navigate to login, then come back
      context.goNamed('login');
      return;
    }

    if (_band == null) {
      // Load band first
      await _loadBand();
      if (_band == null || _error != null) return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if already a member
      if (_band!.members.any((m) => m.uid == user.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already a member')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Add user to band members
      final updatedBand = _band!.copyWith(
        members: [
          ..._band!.members,
          BandMember(
            uid: user.uid,
            role: BandMember.roleEditor,
            displayName: user.displayName,
            email: user.email,
          ),
        ],
      );

      final service = ref.read(firestoreProvider);

      // Save to global collection
      await service.saveBandToGlobal(updatedBand);

      // Add to user's bands collection (for quick access)
      await service.addUserToBand(_band!.id, userId: user.uid);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Joined "${_band!.name}"!')));
        context.goNamed('bands');
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
    final userAsync = ref.watch(currentUserProvider);
    final isLoggedIn = userAsync.value != null;

    return Scaffold(
      appBar: CustomAppBar.buildSimple(context, title: 'Join Band'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Band info card (if loaded)
              if (_band != null) ...[
                _buildBandInfoCard(),
                const SizedBox(height: 24),
              ],

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Invite code input (if no band loaded)
              if (_band == null) ...[
                Text(
                  'Join a band',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.inviteCode != null
                      ? 'Loading band info...'
                      : 'Enter invite code',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _loadBand(),
                  decoration: const InputDecoration(
                    labelText: 'Invite Code *',
                    prefixIcon: Icon(Icons.vpn_key),
                    hintText: 'ABC123',
                  ),
                  validator: (v) => (v == null || v.trim().length < 6)
                      ? 'Enter 6-char code'
                      : null,
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _loadBand,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Find Band'),
                ),
              ],

              // Join button (if band is loaded)
              if (_band != null) ...[
                ElevatedButton(
                  onPressed: _isLoading ? null : _joinBand,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MonoPulseColors.accentOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isLoggedIn ? 'Join Band' : 'Login to Join'),
                ),

                if (!isLoggedIn) ...[
                  const SizedBox(height: 16),
                  Text(
                    'You need to create an account to join this band',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBandInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MonoPulseColors.accentOrange.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Band icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: MonoPulseColors.accentOrange,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _band!.name.isNotEmpty ? _band!.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Band name
          Text(
            _band!.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: MonoPulseColors.textHighEmphasis,
            ),
            textAlign: TextAlign.center,
          ),

          // Band description
          if (_band!.description != null && _band!.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _band!.description!,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Member count
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.people_outline,
                color: MonoPulseColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${_band!.members.length} member${_band!.members.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: MonoPulseColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
