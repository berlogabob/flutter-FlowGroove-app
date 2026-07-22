import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../services/band_function_service.dart';
import '../../theme/mono_pulse_theme.dart';

/// Welcome screen shown when a signed-out (or demo) visitor opens a shared band
/// invite link (`https://flowgroove.app/join?code=XXXX`). It previews the band
/// they've been invited to and funnels them into login, after which the stashed
/// code auto-resumes the join (see [PendingJoinCodeStore] + login flow).
class JoinWelcomeScreen extends ConsumerStatefulWidget {
  const JoinWelcomeScreen({required this.code, super.key});

  final String code;

  @override
  ConsumerState<JoinWelcomeScreen> createState() => _JoinWelcomeScreenState();
}

class _JoinWelcomeScreenState extends ConsumerState<JoinWelcomeScreen> {
  bool _loading = true;
  BandInviteInfo? _info;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final info = await ref
          .read(bandFunctionServiceProvider)
          .getBandInviteInfo(widget.code);
      if (!mounted) return;
      setState(() {
        _info = info;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  /// Sends the visitor into login, stashing the invite code so the join resumes
  /// after they authenticate. The shared demo account is read-only and must
  /// never join a real band, so if a demo session is active we sign it out
  /// first via the app's own sign-out path.
  Future<void> _loginAndJoin() async {
    final isDemo = ref.read(isDemoUserProvider) ||
        FirebaseAuth.instance.currentUser?.email == 'demo@flowgroove.app';
    if (isDemo) {
      try {
        await ref.read(appUserProvider.notifier).signOut();
      } catch (_) {
        // Proceed to login regardless; the redirect handles the signed-out
        // state and login re-establishes a real session.
      }
    }

    await PendingJoinCodeStore().setPendingJoinCode(widget.code);
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
            child: _loading
                ? const CircularProgressIndicator()
                : _error
                    ? _buildError(context)
                    : _buildInvite(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInvite(BuildContext context) {
    final info = _info!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
          decoration: BoxDecoration(
            color: context.mp.surfaceRaised,
            borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
            border: Border.all(
              color: MonoPulseColors.accentOrange.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              const Text('🎸', style: TextStyle(fontSize: 48)),
              const SizedBox(height: MonoPulseSpacing.lg),
              Text(
                "You've been invited to join",
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: context.mp.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MonoPulseSpacing.sm),
              Text(
                info.name.isNotEmpty ? info.name : 'a band',
                style: MonoPulseTypography.headlineLarge.copyWith(
                  color: context.mp.textHighEmphasis,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MonoPulseSpacing.sm),
              Text(
                _subtitle(info),
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: context.mp.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: MonoPulseSpacing.xxl),
        ElevatedButton(
          onPressed: _loginAndJoin,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.lg),
          ),
          child: const Text('Log in & Join'),
        ),
      ],
    );
  }

  String _subtitle(BandInviteInfo info) {
    final members =
        '· ${info.memberCount} member${info.memberCount == 1 ? '' : 's'}';
    final admin = info.adminName;
    if (admin != null && admin.isNotEmpty) {
      return '$members · by $admin';
    }
    return members;
  }

  Widget _buildError(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.link_off,
          size: 48,
          color: context.mp.textTertiary,
        ),
        const SizedBox(height: MonoPulseSpacing.lg),
        Text(
          'This invite link is invalid or has expired.',
          style: MonoPulseTypography.bodyLarge.copyWith(
            color: context.mp.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MonoPulseSpacing.xxl),
        OutlinedButton(
          onPressed: () => context.go('/login'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.lg),
          ),
          child: const Text('Go to app'),
        ),
      ],
    );
  }
}
