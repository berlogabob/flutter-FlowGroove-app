/// Form input for email validation.
///
/// Plain value object: `pure` means the user hasn't interacted yet, so the
/// UI suppresses the error message.
class Email {
  /// Pure email input (no user interaction yet).
  const Email.pure() : this._('', true);

  /// Dirty email input (user has interacted).
  const Email.dirty([String value = '']) : this._(value, false);

  const Email._(this.value, this.isPure);

  final String value;
  final bool isPure;

  /// Regular expression for email validation.
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// User-friendly validation error, or null when valid.
  String? get errorMessage {
    if (value.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value)) return 'Please enter a valid email';
    return null;
  }

  bool get isValid => errorMessage == null;
}
