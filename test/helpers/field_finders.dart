import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/widgets/custom_text_field.dart';

/// The text field of the `CustomTextField` whose label above the field reads
/// [label] (the label is no longer part of the field's own decoration).
Finder fieldLabelled(Type type, String label) => find.descendant(
  of: find.ancestor(
    of: find.text(label),
    matching: find.byType(CustomTextField),
  ),
  matching: find.byType(type),
);
