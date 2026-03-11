import 'package:formz/formz.dart';

/// Validation errors for email input.
enum EmailValidationError {
  /// Email is empty.
  empty,

  /// Email format is invalid.
  invalid,
}

/// Form input for email validation.
///
/// Extends [FormzInput] to provide standardized validation.
///
/// Usage:
/// ```dart
/// final email = Email.dirty('user@example.com');
/// if (email.valid) {
///   // Email is valid
/// }
/// ```
class Email extends FormzInput<String, EmailValidationError> {
  /// Regular expression for email validation.
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Pure email input (no user interaction yet).
  const Email.pure() : super.pure('');

  /// Dirty email input (user has interacted).
  const Email.dirty([super.value = '']) : super.dirty();

  @override
  EmailValidationError? validator(String value) {
    if (value.isEmpty) {
      return EmailValidationError.empty;
    }
    if (!_emailRegex.hasMatch(value)) {
      return EmailValidationError.invalid;
    }
    return null;
  }

  /// Get a user-friendly error message.
  String? get errorMessage {
    switch (error) {
      case EmailValidationError.empty:
        return 'Email is required';
      case EmailValidationError.invalid:
        return 'Please enter a valid email';
      case null:
        return null;
    }
  }
}
