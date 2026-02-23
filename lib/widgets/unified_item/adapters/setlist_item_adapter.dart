import 'package:flutter/material.dart';
import '../../../models/setlist.dart';
import '../unified_item_model.dart';

/// Adapter for Setlist model to work with unified item system
class SetlistItemAdapter extends UnifiedItemModel {
  final Setlist setlist;

  SetlistItemAdapter(this.setlist);

  @override
  String get id => setlist.id;

  @override
  String get title => setlist.name;

  @override
  String? get subtitle => setlist.description;

  @override
  String? get description => null;

  @override
  List<String> get tags => [];

  @override
  DateTime get createdAt => setlist.createdAt;

  @override
  DateTime? get updatedAt => setlist.updatedAt;

  @override
  VoidCallback? get onEdit => null;

  @override
  VoidCallback? get onDelete => null;

  @override
  VoidCallback? get onTap => null;

  @override
  Map<String, dynamic> get typeSpecificData => {
    'bandId': setlist.bandId,
    'songIds': setlist.songIds,
    'eventDate': setlist.eventDate,
    'eventLocation': setlist.eventLocation,
  };

  // Type-specific properties
  int get songIdsLength => setlist.songIds.length;
  String? get bandName => setlist.bandId;
  String? get eventDate => setlist.eventDate;
  String? get eventLocation => setlist.eventLocation;
}
