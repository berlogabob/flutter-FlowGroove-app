import 'package:flutter/material.dart';
import '../../models/band.dart';
import 'unified_item_model.dart';

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
  DateTime get updatedAt => band.updatedAt;

  @override
  VoidCallback? get onEdit => () {};

  @override
  VoidCallback? get onDelete => () {};

  @override
  VoidCallback? get onTap => () {};

  @override
  Map<String, dynamic> get typeSpecificData => {
    'members': band.members,
    'adminUids': band.adminUids,
    'editorUids': band.editorUids,
    'inviteCode': band.inviteCode,
  };

  // Type-specific properties
  int get membersCount {
    if (band.members != null) return band.members!.length;
    return 0;
  }

  String? get bandName {
    return band.name;
  }
}
