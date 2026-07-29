import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/mono_pulse_theme.dart';

/// Renders a user's avatar from [photoURL], falling back to the first letter
/// of [displayName]. Always reads from a network URL — local-file avatars are
/// no longer used (everything is mirrored to Firebase Storage).
///
/// If the network image fails to load (expired URL, offline, blocked), the
/// avatar falls back to the initial instead of rendering a blank circle.
///
/// Canonical avatar (Mono Pulse audit A8): a raised `context.mp.surfaceRaised`
/// circle with a subtle ring and a bold [MonoPulseColors.accentOrange] initial.
/// The same widget is used on the Home greeting, Profile, and band member lists.
class UserAvatar extends StatefulWidget {
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

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _imageFailed = false;

  // The URL is used as given (no sticky last-good copy): appUserProvider now
  // composes from the live users/{uid} doc and no longer blinks photoURL to
  // null mid-load, and photo removal must actually clear the avatar (#91).
  String? get _url {
    final candidate = widget.photoURL;
    return (candidate != null && candidate.startsWith('http'))
        ? candidate
        : null;
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoURL != widget.photoURL) {
      _imageFailed = false; // new avatar uploaded → retry.
    }
  }

  String get _initial {
    final name = widget.displayName?.trim() ?? '';
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  bool get _showPhoto => !_imageFailed && _url != null;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: context.mp.borderDefault),
        ),
      ),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? context.mp.surfaceRaised,
        backgroundImage: _showPhoto ? CachedNetworkImageProvider(_url!) : null,
        onBackgroundImageError: _showPhoto
            ? (_, _) {
                if (mounted) setState(() => _imageFailed = true);
              }
            : null,
        child: _showPhoto
            ? null
            : Text(
                _initial,
                style: TextStyle(
                  fontSize: widget.radius * 0.8,
                  fontWeight: FontWeight.w700,
                  color: MonoPulseColors.accentOrange,
                ),
              ),
      ),
    );
  }
}
