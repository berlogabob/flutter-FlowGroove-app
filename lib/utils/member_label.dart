/// Returns a display label for a band member.
///
/// Prioritizes: trimmed displayName (if non-empty) → email → 'Invited member'
String memberLabel({String? displayName, String? email}) {
  final trimmed = displayName?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return trimmed;
  }
  if (email != null && email.isNotEmpty) {
    return email;
  }
  return 'Invited member';
}
