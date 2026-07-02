/// Form input for password validation.
///
/// Plain value object: `pure` means the user hasn't interacted yet, so the
/// UI suppresses the error message.
///
/// Requirements:
/// - At least 6 characters
/// - At least one uppercase letter
/// - At least one lowercase letter
/// - At least one number
class Password {
  /// Pure password input (no user interaction yet).
  const Password.pure() : this._('', true);

  /// Dirty password input (user has interacted).
  const Password.dirty([String value = '']) : this._(value, false);

  const Password._(this.value, this.isPure);

  final String value;
  final bool isPure;

  /// User-friendly validation error, or null when valid.
  String? get errorMessage {
    if (value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    final hasUpper = value.contains(RegExp('[A-Z]'));
    final hasLower = value.contains(RegExp('[a-z]'));
    final hasNumber = value.contains(RegExp('[0-9]'));
    if (!hasUpper || !hasLower || !hasNumber) {
      return 'Password must contain uppercase, lowercase, and number';
    }
    return null;
  }

  bool get isValid => errorMessage == null;
}
