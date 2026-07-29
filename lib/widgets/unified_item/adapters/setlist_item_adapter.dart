import 'package:flutter/material.dart';
import '../../../models/setlist.dart';
import '../unified_item_model.dart';

/// Adapter for Setlist model to work with unified item system
class SetlistItemAdapter extends UnifiedItemModel {

  SetlistItemAdapter(this.setlist);
  final Setlist setlist;

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
    'eventDateTime': setlist.eventDateTime?.toIso8601String(),
    'eventLocation': setlist.eventLocation,
  };

  // Type-specific properties
  //
  // Raw entry count — NOT filtered against any consumer's song corpus. An
  // entry whose songId doesn't resolve is still an entry (see setlist.dart's
  // effectiveItems); undercounting here is what made a 6-entry setlist show
  // "5 songs" on the card while the editor then deleted the 6th on save.
  int get songIdsLength => setlist.effectiveItems.length;
  String? get bandName => setlist.bandId;
  String? get eventDate => setlist.formattedEventDate;
  String? get eventLocation => setlist.eventLocation;
}
