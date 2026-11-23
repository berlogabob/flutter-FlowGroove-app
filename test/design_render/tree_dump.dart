import 'package:flowgroove/widgets/app_badge.dart';
import 'package:flowgroove/widgets/app_card.dart';
import 'package:flowgroove/widgets/app_filter_chip.dart';
import 'package:flowgroove/widgets/custom_button.dart';
import 'package:flowgroove/widgets/custom_text_field.dart';
import 'package:flowgroove/widgets/user_avatar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const Map<Type, String> kRenderKinds = {
  CustomButton: 'button',
  FilledButton: 'button',
  ElevatedButton: 'button',
  OutlinedButton: 'button',
  TextButton: 'button',
  AppFilterChip: 'chip',
  FilterChip: 'chip',
  ChoiceChip: 'chip',
  InputChip: 'chip',
  ActionChip: 'chip',
  Chip: 'chip',
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
  Dialog: 'dialog',
  SimpleDialog: 'dialog',
};

String? _kind(Widget widget) =>
    widget is SegmentedButton ? 'segmented' : kRenderKinds[widget.runtimeType];

double roundHalf(double value) => (value * 2).round() / 2;

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
    var offscreen = !rect.overlaps(screen);
    if (widget is Text) {
      var hidden = false;
      var scrollable = false;
      element.visitAncestorElements((ancestor) {
        final widget = ancestor.widget;
        if ((widget is Opacity && widget.opacity == 0) ||
            (widget is Visibility && !widget.visible))
          hidden = true;
        if (widget is Scrollable) scrollable = true;
        return true;
      });
      if (hidden || (offscreen && !scrollable)) continue;
      RenderObject child = render;
      var parent = child.parent;
      while (parent is RenderObject) {
        final clip = parent.describeApproximatePaintClip(child);
        if (clip != null) {
          final globalClip = MatrixUtils.transformRect(
            parent.getTransformTo(null),
            clip,
          );
          if (!rect.overlaps(globalClip)) {
            if (parent is RenderAbstractViewport && scrollable) {
              offscreen = true;
            } else {
              hidden = true;
              break;
            }
          }
        }
        child = parent;
        parent = parent.parent;
      }
      if (hidden) continue;
      final value = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      if (value.trim().isNotEmpty) {
        texts.add({
          'v': value,
          'x': roundHalf(rect.left),
          'y': roundHalf(rect.top),
          'w': roundHalf(rect.width),
          'h': roundHalf(rect.height),
          if (offscreen) 'offscreen': true,
        });
      }
    }
    if (kind != null && !offscreen) {
      var nested = false;
      element.visitAncestorElements((ancestor) {
        if (_kind(ancestor.widget) == kind) nested = true;
        return !nested;
      });
      if (!nested)
        kinds.add({
          'kind': kind,
          'x': roundHalf(rect.left),
          'y': roundHalf(rect.top),
        });
    }
  }
  int compare(Map<String, Object?> a, Map<String, Object?> b) {
    final y = (a['y'] as num).compareTo(b['y'] as num);
    if (y != 0) return y;
    final x = (a['x'] as num).compareTo(b['x'] as num);
    return x != 0
        ? x
        : (a['v'] as String? ?? '').compareTo(b['v'] as String? ?? '');
  }

  texts.sort(compare);
  kinds.sort(compare);
  return {'texts': texts, 'kinds': kinds};
}
