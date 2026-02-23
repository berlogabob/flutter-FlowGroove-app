import 'package:flutter/material.dart';
import '../../models/setlist.dart';
import 'unified_item_model.dart';

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
  DateTime get updatedAt => setlist.updatedAt;

  @override
  VoidCallback? get onEdit => () {};

  @override
  VoidCallback? get onDelete => () {};

  @override
  VoidCallback? get onTap => () {};

  @override
  Map<String, dynamic> get typeSpecificData => {
    'bandId': setlist.bandId,
    'songIds': setlist.songIds,
    'eventDate': setlist.eventDate,
    'location': setlist.location,
  };

  // Type-specific properties
  int get songIdsLength => setlist.songIds?.length ?? 0;

  String? get bandName => setlist.bandId;

  DateTime? get eventDate => setlist.eventDate;

  VoidCallback? get onExportPdf {
    return () {
      // This will be implemented in the screen level
    };
  }
}
