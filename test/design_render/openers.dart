import 'package:flowgroove/widgets/confirmation_dialog.dart';
import 'package:flowgroove/widgets/role_picker_widget.dart';
import 'package:flowgroove/widgets/tag_input_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// How to show a spec that has no route of its own (sheet, dialog, picker).
///
/// Modal specs describe the modal only, so [route] is just a backdrop; parity
/// compares the top route. [open] calls the app's own show helper (or taps the
/// real trigger) after the backdrop has settled. Do not await the returned
/// Future of a show helper: it completes only when the modal closes.
class Opener {
  const Opener(this.open, {this.route = '/main/home'});

  final String route;
  final void Function(
    BuildContext context,
    WidgetTester tester,
    GoRouter router,
  )
  open;
}

BuildContext hostContext(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).last);

final kOpeners = <String, Opener>{
  'confirmation_dialog': Opener(
    (context, _, _) => showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmationDialog(
        title: 'Save trim?',
        message:
            'This replaces the original recording. The part outside the '
            'kept sections is gone for good.',
        confirmLabel: 'Trim',
        icon: Icons.content_cut,
      ),
    ),
  ),
  'role_picker_dialog': Opener(
    (context, _, _) => showRolePicker(context: context, currentRoles: const []),
  ),
  'tag_input_dialog': Opener((context, _, _) => TagInputDialog.show(context)),
};
