import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/band_function_service.dart';
import '../../services/secure_storage_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import '../../widgets/bottom_nav_or_action_bar.dart';

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
  BandInviteInfo? _band;
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
      // The public invite callable, NOT a direct band read. Band documents
      // are members-only: `read` covers `list`, so an open rule there let any
      // signed-in account enumerate every band with its member emails and its
      // inviteCode — the very secret this screen is asking for. The callable
      // returns a deliberately public subset instead.
      final code = _codeController.text.trim().toUpperCase();
      final band = await BandFunctionService().getBandInviteInfo(code);

      if (mounted) {
        setState(() {
          _band = band;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      // The callable throws not-found for an unknown code rather than returning
      // null — say "invalid code" for that, and keep real failures distinct so
      // a network problem never reads as a wrong code.
      if (mounted) {
        setState(() {
          _error = e.code == 'not-found'
              ? 'Invalid invite code'
              : 'Could not check that code. Please try again.';
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
    // The demo account is shared and read-only; it must never become a member
    // of a real band. Server-side join rules are the real boundary, but block
    // it here too so the demo UI can't even attempt it.
    //
    // `isDemoUserProvider` answers false while the user document is still
    // loading. For a *restriction* that default permits, which is the wrong
    // way round for an action: a wrong "no" costs a retry a second later, a
    // wrong "yes" is the shared account joining someone's real band. Treat
    // unknown as demo HERE only — the banner keeps the other default, because
    // flipping it globally flashes "demo mode" at every real user on every
    // cold start.
    final userStillLoading = ref.read(appUserProvider).isLoading;
    if (userStillLoading || ref.read(isDemoUserProvider)) {
      showAppSnackBar(
        context,
        'Demo accounts cannot join bands. Sign up to join.',
      );
      return;
    }

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;

    if (user == null) {
      // Store the join code for later and navigate to login
      final joinCode = _codeController.text.trim().toUpperCase();
      await secureStorage.write(key: 'pending_join_code', value: joinCode);
      if (mounted) {
        await context.pushNamed('login');
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
        bandId: _band!.bandId,
      );

      // Log analytics event
      await AnalyticsService.logBandJoined(
        bandId: result.bandId,
        bandName: result.bandName.isNotEmpty ? result.bandName : _band!.name,
        inviteCode: _codeController.text.trim().toUpperCase(),
      );

      if (mounted) {
        // No manual invalidate: bandsProvider watches `memberUids arrayContains
        // uid` in realtime, so the server-side join propagates the new band on
        // its own. Invalidating here would force a redundant full re-read.
        final name = result.bandName.isNotEmpty ? result.bandName : _band!.name;
        showAppSnackBar(
          context,
          result.alreadyMember
              ? 'You are already a member of "$name"'
              : 'Joined "$name"!',
        );
        context.goNamed('bands');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, _joinErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Maps a join failure to a message a bandmate can act on, instead of dumping
  /// a raw exception. The timeout case is the one that previously looked like a
  /// frozen screen (the callable now fails fast via a client deadline).
  String _joinErrorMessage(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'deadline-exceeded':
        case 'unavailable':
          return 'Joining timed out. Check your connection and try again.';
        case 'unauthenticated':
          return 'Your session expired. Please sign in again.';
        case 'not-found':
          return 'That band no longer exists.';
        default:
          return e.message?.isNotEmpty == true
              ? e.message!
              : 'Could not join the band. Please try again.';
      }
    }
    return 'Could not join the band. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final isLoggedIn = userAsync.value != null;
    final isDemo = ref.watch(isDemoUserProvider);

    return PopScope(
      // On a deep-link cold start this screen is the only route on the stack;
      // system back would exit the app. Send it Home instead (P0-2).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        AnalyticsService.logBackUsed(source: 'system');
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/main/home');
        }
      },
      child: Scaffold(
        // Root-pushed route (outside the shell): renders its own pushed-mode
        // bottom bar. Back mirrors the PopScope's home-fallback logic above.
        bottomNavigationBar: AppBottomBar.actions(
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/main/home');
            }
          },
          title: 'Join Band',
        ),
        body: SafeArea(
          bottom: false,
          child: Stack(
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
                            color: MonoPulseColors.error10,
                            borderRadius: BorderRadius.circular(
                              MonoPulseRadius.large,
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: MonoPulseColors.error,
                            ),
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
                            color: context.mp.textHighEmphasis,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.inviteCode != null
                              ? 'Loading band info...'
                              : 'Enter invite code',
                          style: TextStyle(color: context.mp.textTertiary),
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
                            padding: const EdgeInsets.symmetric(
                              vertical: MonoPulseSpacing.lg,
                            ),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(
                                  color: context.mp.textPrimary,
                                )
                              : const Text('Find Band'),
                        ),
                      ],

                      // Join button (if band is loaded)
                      if (_band != null) ...[
                        ElevatedButton(
                          onPressed: (_isLoading || isDemo) ? null : _joinBand,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MonoPulseColors.accentOrange,
                            padding: const EdgeInsets.symmetric(
                              vertical: MonoPulseSpacing.lg,
                            ),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(
                                  color: context.mp.textPrimary,
                                )
                              : Text(
                                  isLoggedIn ? 'Join Band' : 'Login to Join',
                                ),
                        ),

                        if (isDemo) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Demo accounts cannot join bands. Sign up to join.',
                            style: MonoPulseTypography.bodySmall.copyWith(
                              color: context.mp.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ] else if (!isLoggedIn) ...[
                          const SizedBox(height: 16),
                          Text(
                            'You need to create an account to join this band',
                            style: MonoPulseTypography.bodySmall.copyWith(
                              color: context.mp.textTertiary,
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
                  color: context.mp.black.withValues(alpha: 0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBandInfoCard() {
    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
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
                  color: context.mp.textPrimary,
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
              color: context.mp.textHighEmphasis,
            ),
            textAlign: TextAlign.center,
          ),

          // No description here on purpose: the invite callable returns only a
          // public subset, and the Welcome screen shows the same fields.

          // Member count
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                color: context.mp.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${_band!.memberCount} member${_band!.memberCount == 1 ? '' : 's'}',
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: context.mp.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
