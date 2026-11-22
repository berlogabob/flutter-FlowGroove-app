import 'package:flutter/rendering.dart'
    show MatrixUtils, RenderBox, RenderSliver;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Compares laid-out widgets that occupy the same slot before and after [act].
/// Local keys repeated across branches are matched within their branch.
/// Unkeyed widgets use their type and position, so swapped labels and icons
/// still compare with their previous rect.
Future<void> expectStableLayout(
  WidgetTester t,
  Future<void> Function() act, {
  Set<Key> allowChanged = const {},
}) async {
  final before = _snapshot(t, allowChanged);
  await act();
  await t.pump();
  final after = _snapshot(t, allowChanged);

  final beforeKeys = _uniqueKeys(before.values);
  final afterKeys = _uniqueKeys(after.values);
  final changes = <String>[];
  for (final entry in before.entries) {
    final key = entry.value.widget.key;
    final current =
        after[entry.key] ??
        (beforeKeys.containsKey(key) ? afterKeys[key] : null);
    if (current != null && current.rect != entry.value.rect) {
      changes.add(
        '${_label(entry.value.widget)} → ${_label(current.widget)}: '
        '${entry.value.rect} → ${current.rect}',
      );
    }
  }
  expect(changes, isEmpty, reason: changes.join('\n'));
}

String _label(Widget widget) => switch (widget) {
  Text(:final data, :final textSpan) =>
    'Text("${data ?? textSpan?.toPlainText()}")',
  Icon(:final icon) => 'Icon($icon)',
  _ => widget.toStringShort(),
};

typedef _Geometry = ({Widget widget, Rect rect});

Map<Key, _Geometry> _uniqueKeys(Iterable<_Geometry> widgets) {
  final unique = <Key, _Geometry>{};
  final seen = <Key>{};
  for (final entry in widgets) {
    if (entry.widget.key case final key?) {
      if (seen.add(key)) {
        unique[key] = entry;
      } else {
        unique.remove(key);
      }
    }
  }
  return unique;
}

// Record equality keeps local keys scoped to their parents and supports any
// Key subclass without relying on its debug string.
typedef _Slot = ({Object? parent, Object identity});

Map<_Slot, _Geometry> _snapshot(WidgetTester tester, Set<Key> allowed) {
  final result = <_Slot, _Geometry>{};

  void visit(Element element, _Slot slot) {
    final widget = element.widget;
    final key = widget.key;
    if ((key != null && !allowed.contains(key)) ||
        (key == null &&
            (widget is Text ||
                widget is Icon ||
                widget is ButtonStyleButton ||
                widget is IconButton ||
                widget is FloatingActionButton ||
                widget is RawMaterialButton ||
                widget is RawChip ||
                widget is InkWell ||
                (widget is Semantics && widget.properties.button == true)))) {
      final render = element.findRenderObject();
      final bounds = switch (render) {
        RenderBox(attached: true, hasSize: true, :final size) =>
          Offset.zero & size,
        RenderSliver(attached: true, geometry: _?) => render.paintBounds,
        _ => null,
      };
      if (bounds != null) {
        result[slot] = (
          widget: widget,
          rect: MatrixUtils.transformRect(render!.getTransformTo(null), bounds),
        );
      }
    }

    final occurrences = <Type, int>{};
    element.visitChildren((child) {
      final key = child.widget.key;
      final type = child.widget.runtimeType;
      final index = key == null
          ? occurrences.update(type, (n) => n + 1, ifAbsent: () => 0)
          : 0;
      visit(child, (
        parent: key is GlobalKey ? null : slot,
        identity: key ?? (type, index),
      ));
    });
  }

  final root = tester.binding.rootElement!;
  visit(root, (parent: null, identity: root.widget.runtimeType));
  return result;
}
