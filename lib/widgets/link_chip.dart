import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/link.dart';
import '../../theme/app_theme.dart';

/// A chip widget for displaying a link.
///
/// This widget provides a consistent chip layout for displaying links
/// with type label and tap-to-open functionality.
class LinkChip extends StatelessWidget {
  /// The link to display.
  final Link link;

  /// Callback when the chip is tapped.
  final VoidCallback? onTap;

  /// Callback when the delete icon is pressed.
  final VoidCallback? onDelete;

  /// Whether to show the delete icon.
  final bool showDelete;

  /// Whether the chip is selectable.
  final bool selectable;

  /// Whether the chip is currently selected.
  final bool isSelected;

  const LinkChip({
    super.key,
    required this.link,
    this.onTap,
    this.onDelete,
    this.showDelete = false,
    this.selectable = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Chip(
      label: Text(
        _getLinkLabel(),
        style: const TextStyle(fontSize: 12),
      ),
      avatar: _getLinkIcon(),
      deleteIcon: showDelete ? const Icon(Icons.close, size: 16) : null,
      onDeleted: onDelete,
      backgroundColor: _getBackgroundColor(),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: chip,
      );
    }

    return chip;
  }

  String _getLinkLabel() {
    if (link.title != null && link.title!.isNotEmpty) {
      return link.title!;
    }
    return link.type.replaceAll('_', ' ');
  }

  Widget? _getLinkIcon() {
    IconData? icon;
    Color? color;

    switch (link.type) {
      case Link.typeSpotify:
        icon = Icons.play_circle;
        color = Colors.green;
        break;
      case Link.typeYoutubeOriginal:
      case Link.typeYoutubeCover:
        icon = Icons.video_library;
        color = Colors.red;
        break;
      case Link.typeTabs:
        icon = Icons.description;
        color = AppColors.color1;
        break;
      case Link.typeDrums:
        icon = Icons.music_note;
        color = AppColors.color5;
        break;
      case Link.typeChords:
        icon = Icons.music_note;
        color = AppColors.color1;
        break;
      default:
        icon = Icons.link;
        color = Colors.grey;
    }

    return Icon(icon, size: 16, color: color);
  }

  Color? _getBackgroundColor() {
    if (isSelected) {
      return AppColors.color1.withValues(alpha: 0.3);
    }
    return AppColors.color3;
  }

  /// Open the link URL in a browser.
  Future<void> openUrl() async {
    final uri = Uri.parse(link.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// A row of link chips for displaying multiple links.
class LinkChipRow extends StatelessWidget {
  /// The list of links to display.
  final List<Link> links;

  /// Callback when a link is tapped.
  final Function(Link link)? onTap;

  /// Callback when a link is deleted.
  final Function(Link link)? onDelete;

  /// Whether to show delete icons.
  final bool showDelete;

  const LinkChipRow({
    super.key,
    required this.links,
    this.onTap,
    this.onDelete,
    this.showDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: links
          .map(
            (link) => LinkChip(
              link: link,
              onTap: onTap != null ? () => onTap!(link) : null,
              onDelete: onDelete != null ? () => onDelete!(link) : null,
              showDelete: showDelete,
            ),
          )
          .toList(),
    );
  }
}
