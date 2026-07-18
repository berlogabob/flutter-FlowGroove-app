import 'package:flowgroove/widgets/unified_item/setlist_card_actions.dart';
import 'package:flowgroove/widgets/unified_item/unified_item_model.dart';
import 'package:flutter_test/flutter_test.dart';

List<UnifiedItemAction> _build(String quick, {required bool canEdit}) =>
    buildSetlistActions(
      quick: quick,
      canEdit: canEdit,
      onMetronome: () {},
      onEdit: () {},
      onEventKit: () {},
      onShare: () {},
      onCopyLinks: () {},
      onExportPdf: () {},
      onPickQuickAction: () {},
    );

void main() {
  group('buildSetlistActions', () {
    test('returns one pinned IconAction + one overflow', () {
      final a = _build('metronome', canEdit: true);
      expect(a.length, 2);
      expect(a.first, isA<IconAction>());
      expect((a.first as IconAction).tooltip, 'Open in metronome');
      expect(a.last, isA<OverflowMenuAction>());
    });

    test('an edit-only pinned action falls back to metronome for viewers', () {
      expect((_build('edit', canEdit: false).first as IconAction).tooltip,
          'Open in metronome');
      expect((_build('eventkit', canEdit: false).first as IconAction).tooltip,
          'Open in metronome');
    });

    test('an edit-only pinned action is honored when the user can edit', () {
      expect((_build('eventkit', canEdit: true).first as IconAction).tooltip,
          'Event kit');
    });

    test('an unknown pinned key falls back to metronome', () {
      expect((_build('bogus', canEdit: true).first as IconAction).tooltip,
          'Open in metronome');
    });
  });
}
