import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/widgets/app_menu_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FixedUser extends AppUserNotifier {
  @override
  AsyncValue<AppUser?> build() =>
      AsyncValue.data(
    AppUser(uid: 'u1', displayName: 'Dana', createdAt: DateTime(2026)),
  );
}

void main() {
  testWidgets('menu opened without a ref still shows the user name', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appUserProvider.overrideWith(_FixedUser.new)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppMenuSheet(
                context,
                title: 'Recorder',
                items: const [],
                showProfileRow: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Dana'), findsOneWidget);
  });
}
