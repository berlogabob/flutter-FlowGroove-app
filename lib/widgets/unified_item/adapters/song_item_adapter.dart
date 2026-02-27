import 'package:flutter/material.dart';
import '../../../models/song.dart';
import '../unified_item_model.dart';

/// Adapter for Song model to work with unified item system
class SongItemAdapter extends UnifiedItemModel {
  final Song song;
  final VoidCallback? _onEdit;
  final VoidCallback? _onDelete;
  final VoidCallback? _onTap;

  SongItemAdapter(
    this.song, {
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onTap,
  }) : _onEdit = onEdit,
       _onDelete = onDelete,
       _onTap = onTap;

  @override
  String get id => song.id;

  @override
  String get title => song.title;

  @override
  String? get subtitle => song.artist.isNotEmpty ? song.artist : null;

  @override
  String? get description => song.notes;

  @override
  List<String> get tags => song.tags;

  @override
  DateTime get createdAt => song.createdAt;

  @override
  DateTime? get updatedAt => song.updatedAt;

  @override
  VoidCallback? get onEdit => _onEdit;

  @override
  VoidCallback? get onDelete => _onDelete;

  @override
  VoidCallback? get onTap => _onTap;

  @override
  Map<String, dynamic> get typeSpecificData => {
    'originalKey': song.originalKey,
    'originalBPM': song.originalBPM,
    'ourKey': song.ourKey,
    'ourBPM': song.ourBPM,
    'spotifyUrl': song.spotifyUrl,
    'bandId': song.bandId,
  };

  // Type-specific properties
  int? get ourBPM => song.ourBPM;
  int? get originalBPM => song.originalBPM;
  String? get ourKey => song.ourKey;
  String? get originalKey => song.originalKey;
  String? get spotifyUrl => song.spotifyUrl;
  bool get isShared => song.isCopy || song.bandId != null;

  /// Returns the BPM to display in the card:
  /// - If ourBPM is set, show ourBPM
  /// - Otherwise, show originalBPM (if set)
  /// - Otherwise, return null
  int? get displayBPM => ourBPM ?? originalBPM;

  @override
  String get deleteConfirmationMessage =>
      'Are you sure you want to delete "${song.title}"?';
}
