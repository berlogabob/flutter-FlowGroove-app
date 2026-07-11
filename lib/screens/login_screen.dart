import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/api_error.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/auth/error_provider.dart';
import '../theme/mono_pulse_theme.dart';
import '../widgets/error_banner.dart';
import '../widgets/google_sign_in_button_stub.dart'
    if (dart.library.js_interop) '../widgets/google_sign_in_button_web.dart';
import 'auth/forgot_password_screen.dart';
import 'songs/models/inputs/email_input.dart';
import 'songs/models/inputs/password_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  Email _email = const Email.pure();
  Password _password = const Password.pure();
  bool _isLoading = false;
  ApiError? _currentError;

  /// Web only: the GIS button can render once GoogleSignIn.initialize is done.
  bool _webGoogleReady = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _webGoogleAuthSub;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _initWebGoogleSignIn();
  }

  @override
  void dispose() {
    _webGoogleAuthSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// On web the Google button is rendered by GIS itself and the sign-in comes
  /// back through [GoogleSignIn.authenticationEvents]; Firebase's own
  /// popup/redirect flows are unusable there (Safari popup-blocking / ITP).
  Future<void> _initWebGoogleSignIn() async {
    try {
      await ref.read(appUserProvider.notifier).ensureGoogleSignInInitialized();
    } catch (e, stackTrace) {
      _handleError(ApiError.fromException(e, stackTrace: stackTrace));
      return;
    }
    _webGoogleAuthSub = GoogleSignIn.instance.authenticationEvents.listen(
      _onWebGoogleAuthEvent,
      onError: (Object e, StackTrace stackTrace) {
        if (e is GoogleSignInException &&
            e.code == GoogleSignInExceptionCode.canceled) {
          return;
        }
        _handleError(ApiError.fromException(e, stackTrace: stackTrace));
      },
    );
    if (mounted) setState(() => _webGoogleReady = true);
  }

  Future<void> _onWebGoogleAuthEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    setState(() {
      _isLoading = true;
      _currentError = null;
    });
    try {
      final idToken = event.user.authentication.idToken;
      if (idToken == null) {
        throw ApiError.auth(message: 'Google sign-in failed: missing ID token.');
      }
      await ref.read(appUserProvider.notifier).completeWebGoogleSignIn(idToken);
      await _afterLoginSuccess('google');
    } on ApiError catch (e) {
      _handleError(e);
    } catch (e, stackTrace) {
      _handleError(ApiError.fromException(e, stackTrace: stackTrace));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shared post-login tail: analytics, pending join code, navigation.
  Future<void> _afterLoginSuccess(String loginMethod) async {
    final analytics = ref.read(analyticsClientProvider);
    await analytics.logLogin(loginMethod: loginMethod);
    await analytics.logLoginSuccess(loginMethod: loginMethod);

    // Honour a pending join code captured before login.
    final pendingJoinCode = await ref
        .read(pendingJoinCodeStoreProvider)
        .getAndClearPendingJoinCode();
    if (!mounted) return;

    if (pendingJoinCode != null) {
      context.goNamed('join-band', queryParameters: {'code': pendingJoinCode});
    } else {
      context.go('/main/home');
    }
  }

  void _onEmailChanged(String value) {
    setState(() {
      _email = Email.dirty(value);
    });
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _password = Password.dirty(value);
    });
  }

  void _clearError() {
    if (!mounted) return;
    setState(() {
      _currentError = null;
    });
    ref.read(errorStateProvider.notifier).clearError();
  }

  void _handleError(ApiError error) {
    if (!mounted) return;
    setState(() {
      _currentError = error;
    });
    ref.read(errorStateProvider.notifier).handleError(error);
  }

  Future<void> _login() async {
    setState(() {
      _email = Email.dirty(_emailController.text.trim());
      _password = Password.dirty(_passwordController.text);
    });

    // Validate using Formz
    if (!_email.isValid || !_password.isValid) return;

    setState(() {
      _isLoading = true;
      _currentError = null;
    });

    try {
      final authNotifier = ref.read(appUserProvider.notifier);
      await authNotifier.signInWithEmailAndPassword(
        email: _email.value,
        password: _password.value,
      );

      await _afterLoginSuccess('email');
    } on ApiError catch (e) {
      _handleError(e);
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      _handleError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Sign in with Google.
  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _currentError = null;
    });

    try {
      await ref.read(appUserProvider.notifier).signInWithGoogle();
      await _afterLoginSuccess('google');
    } on ApiError catch (e) {
      // Treat user-cancelled sign-in as a no-op, not an error banner.
      if (e.message == 'Google sign-in was cancelled.') return;
      _handleError(e);
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      _handleError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Quick-login for demo account (read-only).
  Future<void> _loginDemo() async {
    // Demo credentials — update these when test accounts are created
    const demoEmail = 'demo@flowgroove.app';
    const demoPassword = 'demo1234';

    setState(() {
      _isLoading = true;
      _currentError = null;
    });

    try {
      final authNotifier = ref.read(appUserProvider.notifier);
      await authNotifier.signInWithEmailAndPassword(
        email: demoEmail,
        password: demoPassword,
      );

      await ref.read(analyticsClientProvider).logDemoLogin();

      if (mounted) {
        context.go('/main/home');
      }
    } on ApiError catch (e) {
      _handleError(e);
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      _handleError(error);
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'FlowGroove',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to manage your band',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MonoPulseColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_currentError != null) ...[
                ErrorBanner(
                  message:
                      _currentError?.message ?? 'An unexpected error occurred',
                  onRetry: _clearError,
                ),
                const SizedBox(height: 24),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: _onEmailChanged,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  errorText: !_email.isPure ? _email.errorMessage : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onChanged: _onPasswordChanged,
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  errorText: !_password.isPure ? _password.errorMessage : null,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    debugPrint('🔑 Forgot Password button tapped');
                    debugPrint('🔑 Email from login: $_email.value');
                    // Use Navigator to push the route with email
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            ForgotPasswordScreen(initialEmail: _email.value),
                      ),
                    );
                  },
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.lg),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MonoPulseColors.textPrimary,
                        ),
                      )
                    : const Text('Sign In'),
              ),
              const SizedBox(height: 12),
              if (kIsWeb)
                // GIS renders this button itself; sign-in arrives via
                // authenticationEvents (see _onWebGoogleAuthEvent).
                SizedBox(
                  height: 44,
                  child: _webGoogleReady
                      ? Center(child: googleSignInButton())
                      : const SizedBox.shrink(),
                )
              else
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _loginWithGoogle,
                  icon: Image.asset(
                    'assets/google_logo.png',
                    height: 18,
                    width: 18,
                  ),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () => context.goNamed('register'),
                    child: const Text('Sign Up'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Just looking around?',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MonoPulseColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loginDemo,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Try Demo Account'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: MonoPulseColors.accentOrange,
                  side: const BorderSide(color: MonoPulseColors.accentOrange),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Read-only access to explore all features',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MonoPulseColors.textTertiary,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
