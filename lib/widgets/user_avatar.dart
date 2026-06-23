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
/// Canonical avatar (Mono Pulse audit A8): a raised [MonoPulseColors.surfaceRaised]
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

  /// The last real (http) photo URL we accepted. Sticky on purpose: some
  /// providers (e.g. `appUserProvider`) briefly drop photoURL to null on a
  /// rebuild before an async profile load re-supplies it, which made the
  /// avatar blink between the photo and the initial. We keep showing the last
  /// good photo and only switch when a *different* http URL arrives.
  // ponytail: a permanent photo removal (URL → null) keeps showing the old
  // image until a new URL or app restart; acceptable vs. the blink.
  String? _url;

  @override
  void initState() {
    super.initState();
    _adopt(widget.photoURL);
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _adopt(widget.photoURL);
  }

  void _adopt(String? candidate) {
    if (candidate != null &&
        candidate.startsWith('http') &&
        candidate != _url) {
      _url = candidate;
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
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: MonoPulseColors.borderDefault),
        ),
      ),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor:
            widget.backgroundColor ?? MonoPulseColors.surfaceRaised,
        backgroundImage: _showPhoto
            ? CachedNetworkImageProvider(_url!)
            : null,
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
