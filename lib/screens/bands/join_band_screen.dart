import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/band.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/secure_storage_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/custom_app_bar.dart';

class JoinBandScreen extends ConsumerStatefulWidget {

  const JoinBandScreen({super.key, this.inviteCode});
  final String? inviteCode;

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
        if (mounted) {
          setState(() {
            _error = 'Invalid invite code';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _band = band;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading band: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinBand() async {
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;

    if (user == null) {
      // Store the join code for later and navigate to login
      final joinCode = _codeController.text.trim().toUpperCase();
      await secureStorage.write(key: 'pending_join_code', value: joinCode);
      if (mounted) {
        context.pushNamed('login');
      }
      return;
    }

    if (_band == null) {
      // Load band first
      await _loadBand();
      if (_band == null || _error != null) return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Join is performed server-side (callable Cloud Function): it is atomic,
      // idempotent (re-joining is a no-op), and keeps the derived member UID
      // arrays in sync, so it never trips the band's permission rules.
      final bandService = ref.read(bandFunctionServiceProvider);
      final result = await bandService.joinBand(
        code: _codeController.text.trim().toUpperCase(),
        bandId: _band!.id,
      );

      // Log analytics event
      await AnalyticsService.logBandJoined(
        bandId: result.bandId,
        bandName: result.bandName.isNotEmpty ? result.bandName : _band!.name,
        inviteCode: _codeController.text.trim().toUpperCase(),
      );

      if (mounted) {
        // Invalidate bands provider to ensure UI refresh
        ref.invalidate(bandsProvider);
        final name = result.bandName.isNotEmpty ? result.bandName : _band!.name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.alreadyMember
                  ? 'You are already a member of "$name"'
                  : 'Joined "$name"!',
            ),
          ),
        );
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
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
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
                      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
                      decoration: BoxDecoration(
                        color: MonoPulseColors.errorSubtle,
                        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: MonoPulseColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Invite code input (if no band loaded)
                  if (_band == null) ...[
                    Text(
                      'Join a band',
                      style: MonoPulseTypography.headlineSmall.copyWith(
                        color: MonoPulseColors.textHighEmphasis,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.inviteCode != null
                          ? 'Loading band info...'
                          : 'Enter invite code',
                      style: const TextStyle(color: MonoPulseColors.textTertiary),
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
                          ? const CircularProgressIndicator(color: MonoPulseColors.textPrimary)
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
                          ? const CircularProgressIndicator(color: MonoPulseColors.textPrimary)
                          : Text(isLoggedIn ? 'Join Band' : 'Login to Join'),
                    ),

                    if (!isLoggedIn) ...[
                      const SizedBox(height: 16),
                      Text(
                        'You need to create an account to join this band',
                        style: MonoPulseTypography.bodySmall.copyWith(
                          color: MonoPulseColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            ColoredBox(
              color: MonoPulseColors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBandInfoCard() {
    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      decoration: BoxDecoration(
        color: MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        border: Border.all(
          color: MonoPulseColors.accentOrange.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Band icon
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: MonoPulseColors.accentOrange,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _band!.name.isNotEmpty ? _band!.name[0].toUpperCase() : '?',
                style: MonoPulseTypography.headlineLarge.copyWith(
                  color: MonoPulseColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Band name
          Text(
            _band!.name,
            style: MonoPulseTypography.headlineMedium.copyWith(
              color: MonoPulseColors.textHighEmphasis,
            ),
            textAlign: TextAlign.center,
          ),

          // Band description
          if (_band!.description != null && _band!.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _band!.description!,
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
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
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
