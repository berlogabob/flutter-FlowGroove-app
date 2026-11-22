import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flowgroove/widgets/app_badge.dart';
import 'package:flowgroove/widgets/app_card.dart';
import 'package:flowgroove/widgets/app_filter_chip.dart';
import 'package:flowgroove/widgets/custom_button.dart';
import 'package:flowgroove/widgets/custom_text_field.dart';
import 'package:flowgroove/widgets/user_avatar.dart';

const Map<Type, String> kRenderKinds = {
  CustomButton: 'button',
  FilledButton: 'button',
  ElevatedButton: 'button',
  OutlinedButton: 'button',
  TextButton: 'button',
  AppFilterChip: 'chip',
  FilterChip: 'chip',
  ChoiceChip: 'chip',
  AppCard: 'card',
  Card: 'card',
  ListTile: 'tile',
  CustomTextField: 'input',
  TextField: 'input',
  IconButton: 'iconbtn',
  SwitchListTile: 'switchrow',
  FloatingActionButton: 'fab',
  AppBadge: 'badge',
  UserAvatar: 'avatar',
  CircleAvatar: 'avatar',
  Slider: 'slider',
  LinearProgressIndicator: 'progress',
  Checkbox: 'checkbox',
  Switch: 'switch',
  SegmentedButton: 'segmented',
  TabBar: 'tabs',
  AppBar: 'appbar',
  Divider: 'divider',
  AlertDialog: 'dialog',
};

String? _kind(Widget widget) =>
    widget is SegmentedButton ? 'segmented' : kRenderKinds[widget.runtimeType];

Map<String, Object?> dumpTree(WidgetTester tester) {
  final texts = <Map<String, Object?>>[];
  final kinds = <Map<String, Object?>>[];
  final screen =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  for (final element in find.byWidgetPredicate((_) => true).evaluate()) {
    final widget = element.widget;
    final kind = _kind(widget);
    if (widget is! Text && kind == null) continue;
    final render = element.findRenderObject();
    if (render is! RenderBox || !render.hasSize || render.size.isEmpty)
      continue;
    final rect = render.localToGlobal(Offset.zero) & render.size;
    if (!rect.overlaps(screen)) continue;
    if (widget is Text) {
      final value = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      if (value.trim().isNotEmpty) {
        texts.add({
          'v': value,
          'x': rect.left,
          'y': rect.top,
          'w': rect.width,
          'h': rect.height,
        });
      }
    }
    if (kind != null) {
      var nested = false;
      element.visitAncestorElements((ancestor) {
        if (_kind(ancestor.widget) == kind) nested = true;
        return !nested;
      });
      if (!nested) kinds.add({'kind': kind, 'x': rect.left, 'y': rect.top});
    }
  }
  int compare(Map<String, Object?> a, Map<String, Object?> b) {
    final y = ((a['y'] as num) / 8).round().compareTo(
      ((b['y'] as num) / 8).round(),
    );
    return y != 0 ? y : (a['x'] as num).compareTo(b['x'] as num);
  }

  texts.sort(compare);
  kinds.sort(compare);
  return {'texts': texts, 'kinds': kinds};
}
