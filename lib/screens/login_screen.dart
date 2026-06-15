import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/api_error.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/auth/error_provider.dart';
import '../theme/mono_pulse_theme.dart';
import '../widgets/error_banner.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

      // Log successful login
      final analytics = ref.read(analyticsClientProvider);
      await analytics.logLogin(loginMethod: 'email');
      await analytics.logLoginSuccess(loginMethod: 'email');

      // Check if there's a pending join code from before login.
      final pendingJoinCode = await ref
          .read(pendingJoinCodeStoreProvider)
          .getAndClearPendingJoinCode();
      if (!mounted) return;

      if (pendingJoinCode != null) {
        context.goNamed(
          'join-band',
          queryParameters: {'code': pendingJoinCode},
        );
      } else {
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
                      MaterialPageRoute(
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
