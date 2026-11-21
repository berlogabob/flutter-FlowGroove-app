import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../models/section.dart';
import '../../theme/mono_pulse_theme.dart';
import 'song_map/song_map_letters.dart';

Future<({String name, bool move})?> showSectionNameSheet(
  BuildContext context, {
  required String initialName,
  required Map<String, SongMapLetter> groups,
}) async {
  final controller = TextEditingController(text: initialName);
  ModalRoute<dynamic>? route;
  String? sameAs;
  final result = await showModalBottomSheet<({String name, bool move})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.mp.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MonoPulseRadius.xlarge),
      ),
    ),
    builder: (sheetContext) {
      route = ModalRoute.of(sheetContext);
      void save() {
        final name = (sameAs ?? controller.text).trim();
        if (name.isNotEmpty) {
          Navigator.pop(sheetContext, (name: name, move: sameAs != null));
        }
      }

      return StatefulBuilder(
        builder: (context, setState) {
          final palette = context.mp;
          final labelStyle = MonoPulseTypography.labelMedium.copyWith(
            color: palette.textPrimary,
          );
          final outline = OutlineInputBorder(
            borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
            borderSide: BorderSide(color: palette.borderStrong),
          );
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MonoPulseSpacing.lg,
                  0,
                  MonoPulseSpacing.lg,
                  MonoPulseSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: MonoPulseSpacing.md,
                  children: [
                    Text(
                      'Rename section',
                      style: MonoPulseTypography.titleLarge.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: MonoPulseSpacing.xs,
                      children: [
                        Text('Name', style: labelStyle),
                        Semantics(
                          label: 'Name',
                          child: TextField(
                            controller: controller,
                            textInputAction: TextInputAction.done,
                            style: MonoPulseTypography.bodyLarge.copyWith(
                              color: MonoPulseColors.charcoal,
                            ),
                            cursorColor: MonoPulseColors.charcoal,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: MonoPulseColors.white,
                              enabledBorder: outline,
                              focusedBorder: outline.copyWith(
                                borderSide: const BorderSide(
                                  color: MonoPulseColors.accentOrange,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() => sameAs = null),
                            onSubmitted: (_) => save(),
                          ),
                        ),
                      ],
                    ),
                    if (groups.isNotEmpty) ...[
                      Text('Same as', style: labelStyle),
                      Wrap(
                        spacing: MonoPulseSpacing.sm,
                        runSpacing: MonoPulseSpacing.sm,
                        children: [
                          for (final MapEntry(key: name, value: letter)
                              in groups.entries)
                            _SectionGroupChip(
                              name: name,
                              letter: letter,
                              selected:
                                  (sameAs ?? controller.text).toLowerCase() ==
                                  name.toLowerCase(),
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  sameAs = name;
                                  controller.text = name;
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                    Text(
                      'Repeats share letter and colour everywhere.',
                      style: MonoPulseTypography.bodySmall.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: MonoPulseSpacing.sm,
                        children: [
                          Flexible(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(120, 54),
                                foregroundColor: palette.textPrimary,
                                side: BorderSide(color: palette.borderStrong),
                                shape: _sectionActionShape,
                              ),
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          Flexible(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(120, 54),
                                backgroundColor: MonoPulseColors.accentOrange,
                                foregroundColor: MonoPulseColors.charcoal,
                                shape: _sectionActionShape,
                              ),
                              onPressed: controller.text.trim().isEmpty
                                  ? null
                                  : save,
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
  // Keep the controller alive until the sheet finishes dismissing.
  unawaited(route?.completed.then((_) => controller.dispose()));
  return result;
}

const _sectionActionShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(MonoPulseRadius.button)),
);

class _SectionGroupChip extends StatelessWidget {
  const _SectionGroupChip({
    required this.name,
    required this.letter,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final SongMapLetter letter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.mp;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: MonoPulseSpacing.xs,
          children: [
            ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
                decoration: ShapeDecoration(
                  color: letter.color,
                  shape: const StadiumBorder(),
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    letter.label,
                    style: MonoPulseTypography.labelSmall.copyWith(
                      color: letter.textColor,
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: MonoPulseSpacing.md,
                  vertical: MonoPulseSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: selected ? MonoPulseLight.surfaceOverlay : null,
                  border: Border.all(color: palette.borderStrong),
                  borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                ),
                child: Text(
                  name,
                  style: MonoPulseTypography.labelMedium.copyWith(
                    color: selected
                        ? MonoPulseColors.charcoal
                        : palette.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> showRegionNameSheet(
  BuildContext context, {
  required String initialName,
}) async {
  final controller = TextEditingController(text: initialName);
  ModalRoute<dynamic>? sheetRoute;
  final name = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.mp.surface,
    builder: (sheetContext) {
      sheetRoute = ModalRoute.of(sheetContext);
      return StatefulBuilder(
        builder: (context, sheetSetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            MonoPulseSpacing.lg,
            MonoPulseSpacing.lg,
            MonoPulseSpacing.lg,
            MediaQuery.viewInsetsOf(context).bottom + MonoPulseSpacing.lg,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Region name',
                    style: MonoPulseTypography.titleLarge,
                  ),
                  Wrap(
                    spacing: MonoPulseSpacing.sm,
                    children: [
                      for (final template in Section.templates)
                        ChoiceChip(
                          label: Text(template),
                          selected: controller.text == template,
                          onSelected: (_) => sheetSetState(() {
                            controller.text = template;
                          }),
                        ),
                    ],
                  ),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (_) => sheetSetState(() {}),
                    onSubmitted: (value) => Navigator.pop(sheetContext, value),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(sheetContext, controller.text),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  // Keep the controller alive until the sheet finishes dismissing.
  unawaited(sheetRoute?.completed.then((_) => controller.dispose()));
  return name;
}
