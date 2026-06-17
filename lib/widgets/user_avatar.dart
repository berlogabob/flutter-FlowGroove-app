import 'package:flutter/material.dart';

/// Renders a user's avatar from [photoURL], falling back to the first letter
/// of [displayName]. Always reads from a network URL — local-file avatars are
/// no longer used (everything is mirrored to Firebase Storage).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.photoURL,
    required this.displayName,
    this.radius = 24,
    this.backgroundColor,
    super.key,
  });

  final String? photoURL;
  final String? displayName;
  final double radius;

  /// Background shown behind the initials fallback (and while a network image
  /// loads). Defaults to the theme's [CircleAvatar] background.
  final Color? backgroundColor;

  String get _initial {
    final name = displayName?.trim() ?? '';
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  bool get _hasPhoto => photoURL != null && photoURL!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: _hasPhoto ? NetworkImage(photoURL!) : null,
      child: _hasPhoto
          ? null
          : Text(
              _initial,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
