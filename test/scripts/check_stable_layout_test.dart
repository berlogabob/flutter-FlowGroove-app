import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const script = 'scripts/check_stable_layout.py';

  test('the app passes the stable layout check', () async {
    final result = await Process.run('python3', [script, 'lib']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('reports each forbidden pattern at its source line', () async {
    const source = """
final side = active
    ? const BorderSide(color: selectedColor) // expect BorderSide vs BorderSide.none
    : BorderSide.none;

final border = focused
    ? null // expect Border.all vs null
    : (Border.all(
        color: focusColor,
      ));

final outline = Border.all(
  width: // expect border width
      selected ? 2 : 1,
);

final textStyle = TextStyle(
  fontWeight: // expect fontWeight
      active ? FontWeight.bold : FontWeight.normal,
  fontSize: active ? 16 : 14, // expect fontSize
);

final icon = Icon(
  Icons.play_arrow,
  size: playing ? 24 : 20, // expect icon size
);

final iconButton = IconButton(
  iconSize: playing ? 24 : 20, // expect icon size
);

final container = AnimatedContainer(
  width: // expect width
      active ? 72 : 80,
  height: active ? 48 : 56, // expect height
  padding: selected ? smallPadding : largePadding, // expect padding
);

final inset = pressed
    ? const EdgeInsets.all(4) // expect EdgeInsets
    : EdgeInsets.zero;

final nestedInset = Padding(
  padding: EdgeInsets.only(
    top: active ? 2 : 4, // expect padding
  ),
);

final directionalInset = EdgeInsetsDirectional.only(
  start: selected ? 2 : 4, // expect EdgeInsets
);

final filter = FilterChip(
  showCheckmark: /* explicit opt-in */ true, // expect FilterChip showCheckmark: true
);
final choice = material.ChoiceChip(
  showCheckmark: // expect ChoiceChip showCheckmark: true
      true,
);

final unchanged = ChoiceChip(selected: active, showCheckmark: false);
final themed = FilterChip(selected: active);
final theme = ChipThemeData(showCheckmark: true);
final fallback = SizedBox(width: preferredWidth ?? 80);
final optional = Icon(Icons.play_arrow, size: style?.iconSize);
final help = 'SizedBox(height: selected ? 48 : 56)';
/* FilterChip(showCheckmark: true) */
""";
    final directory = await Directory.systemTemp.createTemp('stable_layout_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/bad.dart');
    await file.writeAsString(source);
    await File('${directory.path}/ignored.g.dart').writeAsString(source);

    final result = await Process.run('python3', [script, directory.path]);
    final output = result.stdout as String;
    expect(result.exitCode, 1, reason: '$output${result.stderr}');

    final lines = source.split('\n');
    final expected = <String>[];
    for (final (index, line) in lines.indexed) {
      const marker = '// expect ';
      if (line.contains(marker)) {
        expected.add('${file.path}:${index + 1}: ${line.split(marker).last}');
      }
    }
    for (final diagnostic in expected) {
      expect(output, contains(diagnostic));
    }
    expect(output.trim().split('\n'), hasLength(expected.length));
  });
}
