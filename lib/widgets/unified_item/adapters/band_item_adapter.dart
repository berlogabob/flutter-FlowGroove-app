import 'package:flutter/material.dart';
import '../../../models/band.dart';
import '../unified_item_model.dart';

/// Adapter for Band model to work with unified item system
class BandItemAdapter extends UnifiedItemModel {
  final Band band;

  BandItemAdapter(this.band);

  @override
  String get id => band.id;

  @override
  String get title => band.name;

  @override
  String? get subtitle => band.description;

  @override
  String? get description => null;

  @override
  List<String> get tags => [];

  @override
  DateTime get createdAt => band.createdAt;

  @override
  DateTime? get updatedAt => null;

  // Callbacks are provided by the parent widget (UnifiedItemList)
  @override
  VoidCallback? get onEdit => null;

  @override
  VoidCallback? get onDelete => null;

  @override
  VoidCallback? get onTap => null;

  @override
  Map<String, dynamic> get typeSpecificData => {
    'members': band.members,
    'adminUids': band.adminUids,
    'editorUids': band.editorUids,
    'inviteCode': band.inviteCode,
  };

  // Type-specific properties
  int get membersCount => band.members.length;
  String? get bandName => band.name;

  @override
  String get deleteConfirmationMessage =>
      'Are you sure you want to leave this band?';
}
