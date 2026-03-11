import 'package:formz/formz.dart';

/// Validation errors for password input.
enum PasswordValidationError {
  /// Password is empty.
  empty,

  /// Password is too short.
  tooShort,

  /// Password doesn't meet requirements.
  weak,
}

/// Form input for password validation.
///
/// Extends [FormzInput] to provide standardized validation.
///
/// Requirements:
/// - At least 8 characters
/// - At least one uppercase letter
/// - At least one lowercase letter
/// - At least one number
class Password extends FormzInput<String, PasswordValidationError> {
  /// Pure password input (no user interaction yet).
  const Password.pure() : super.pure('');

  /// Dirty password input (user has interacted).
  const Password.dirty([super.value = '']) : super.dirty();

  @override
  PasswordValidationError? validator(String value) {
    if (value.isEmpty) {
      return PasswordValidationError.empty;
    }
    if (value.length < 8) {
      return PasswordValidationError.tooShort;
    }
    if (!_hasUppercase(value) || !_hasLowercase(value) || !_hasNumber(value)) {
      return PasswordValidationError.weak;
    }
    return null;
  }

  bool _hasUppercase(String value) {
    return value.contains(RegExp(r'[A-Z]'));
  }

  bool _hasLowercase(String value) {
    return value.contains(RegExp(r'[a-z]'));
  }

  bool _hasNumber(String value) {
    return value.contains(RegExp(r'[0-9]'));
  }

  /// Get a user-friendly error message.
  String? get errorMessage {
    switch (error) {
      case PasswordValidationError.empty:
        return 'Password is required';
      case PasswordValidationError.tooShort:
        return 'Password must be at least 8 characters';
      case PasswordValidationError.weak:
        return 'Password must contain uppercase, lowercase, and number';
      case null:
        return null;
    }
  }

  /// Get password strength (0-3).
  int get strength {
    int score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (_hasUppercase(value) && _hasLowercase(value)) score++;
    if (_hasNumber(value)) score++;
    if (value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;
    return score;
  }
}
