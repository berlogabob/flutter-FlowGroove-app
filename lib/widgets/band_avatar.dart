import 'package:flutter/material.dart';

/// Renders a band's avatar from [photoURL], falling back to the first letter
/// of [bandName].
class BandAvatar extends StatelessWidget {
  const BandAvatar({
    required this.photoURL,
    required this.bandName,
    this.radius = 24,
    super.key,
  });

  final String? photoURL;
  final String? bandName;
  final double radius;

  String get _initial {
    final name = bandName?.trim() ?? '';
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  bool get _hasPhoto => photoURL != null && photoURL!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
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
