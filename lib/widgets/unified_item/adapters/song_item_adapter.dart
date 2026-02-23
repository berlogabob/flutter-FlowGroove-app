import 'package:flutter/material.dart';
import '../../models/song.dart';
import 'unified_item_model.dart';

/// Adapter for Song model to work with unified item system
class SongItemAdapter extends UnifiedItemModel {
  final Song song;

  SongItemAdapter(this.song);

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
  VoidCallback? get onEdit => null;

  @override
  VoidCallback? get onDelete => null;

  @override
  VoidCallback? get onTap => null;

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
  String? get ourKey => song.ourKey;
  String? get spotifyUrl => song.spotifyUrl;
}
