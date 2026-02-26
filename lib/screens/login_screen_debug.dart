import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_error.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/auth/error_provider.dart';
import '../widgets/error_banner.dart';
import '../theme/mono_pulse_theme.dart';

/// Login screen with comprehensive error handling and debug logging.
class LoginScreenDebug extends ConsumerStatefulWidget {
  const LoginScreenDebug({super.key});

  @override
  ConsumerState<LoginScreenDebug> createState() => _LoginScreenDebugState();
}

class _LoginScreenDebugState extends ConsumerState<LoginScreenDebug> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  ApiError? _currentError;

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 [LOGIN_SCREEN] initState() called');
  }

  @override
  void dispose() {
    debugPrint('🔍 [LOGIN_SCREEN] dispose() called');
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Clears the current error.
  void _clearError() {
    debugPrint('🔍 [LOGIN_SCREEN] _clearError() called');
    setState(() {
      _currentError = null;
    });
    ref.read(errorNotifierProvider.notifier).clearError();
  }

  /// Handles an error by updating state and showing a message.
  void _handleError(ApiError error) {
    debugPrint('🔍 [LOGIN_SCREEN] _handleError() called: ${error.type} - ${error.message}');
    setState(() {
      _currentError = error;
    });
    ref.read(errorNotifierProvider.notifier).handleError(error);
  }

  /// ⚠️ LOGIN FLOW ENTRY POINT
  Future<void> _login() async {
    debugPrint('🔍 [LOGIN_SCREEN] 🔵🔵🔵 _login() CALLED 🔵🔵🔵');
    debugPrint('🔍 [LOGIN_SCREEN] Email: ${_emailController.text.trim()}');
    debugPrint('🔍 [LOGIN_SCREEN] Password: ${_passwordController.text}');
    
    if (!_formKey.currentState!.validate()) {
      debugPrint('🔍 [LOGIN_SCREEN] Form validation failed');
      return;
    }

    debugPrint('🔍 [LOGIN_SCREEN] Form validated, starting login...');

    setState(() {
      _isLoading = true;
      _currentError = null;
    });

    try {
      debugPrint('🔍 [LOGIN_SCREEN] Reading appUserProvider.notifier');
      final authNotifier = ref.read(appUserProvider.notifier);
      debugPrint('🔍 [LOGIN_SCREEN] Calling signInWithEmailAndPassword()');
      
      await authNotifier.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      debugPrint('🔍 [LOGIN_SCREEN] Login successful, checking if mounted');
      
      if (mounted) {
        debugPrint('🔍 [LOGIN_SCREEN] Navigating to /main');
        // Navigate to main shell after successful login
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        debugPrint('🔍 [LOGIN_SCREEN] Widget not mounted, skipping navigation');
      }
    } on ApiError catch (e) {
      debugPrint('🔍 [LOGIN_SCREEN] Caught ApiError: ${e.type} - ${e.message}');
      _handleError(e);
    } catch (e, stackTrace) {
      debugPrint('🔍 [LOGIN_SCREEN] Caught Exception: $e');
      debugPrint('🔍 [LOGIN_SCREEN] Stack trace: $stackTrace');
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      _handleError(error);
    } finally {
      debugPrint('🔍 [LOGIN_SCREEN] Finally block, setting _isLoading = false');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 [LOGIN_SCREEN] build() called, _isLoading = $_isLoading');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome Back'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'RepSync',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
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
              // Error banner
              if (_currentError != null) ...[
                ErrorBanner.banner(
                  message: _currentError?.message ?? 'An unexpected error occurred',
                  onRetry: _clearError,
                ),
                const SizedBox(height: 24),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  errorText:
                      _currentError?.isValidation == true &&
                          _currentError?.message.toLowerCase().contains('email') == true
                      ? _currentError?.message
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  debugPrint('🔍 [LOGIN_SCREEN] Password field submitted');
                  _login();
                },
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    debugPrint('🔍 [LOGIN_SCREEN] Forgot Password tapped');
                    Navigator.pushNamed(context, '/forgot-password');
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
                          color: Colors.white,
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
                    onPressed: () {
                      debugPrint('🔍 [LOGIN_SCREEN] Sign Up tapped');
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text('Sign Up'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
