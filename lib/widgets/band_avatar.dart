import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders a band's avatar from [photoURL], falling back to the first letter
/// of [bandName].
///
/// If the network image fails to load (expired URL, offline, blocked), the
/// avatar falls back to the initial instead of rendering a blank circle.
class BandAvatar extends StatefulWidget {
  const BandAvatar({
    required this.photoURL,
    required this.bandName,
    this.radius = 24,
    super.key,
  });

  final String? photoURL;
  final String? bandName;
  final double radius;

  @override
  State<BandAvatar> createState() => _BandAvatarState();
}

class _BandAvatarState extends State<BandAvatar> {
  bool _imageFailed = false;

  @override
  void didUpdateWidget(BandAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Retry loading when the URL changes (e.g. a new avatar was uploaded).
    if (oldWidget.photoURL != widget.photoURL) {
      _imageFailed = false;
    }
  }

  String get _initial {
    final name = widget.bandName?.trim() ?? '';
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  bool get _showPhoto =>
      !_imageFailed &&
      widget.photoURL != null &&
      widget.photoURL!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: _showPhoto
          ? CachedNetworkImageProvider(widget.photoURL!)
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
              ),
            ),
    );
  }
}
