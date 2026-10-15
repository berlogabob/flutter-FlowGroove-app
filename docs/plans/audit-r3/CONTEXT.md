# Conventions for every task (read this first)

You are editing a Flutter app (package `flowgroove`). Make the SMALLEST edit that satisfies the task.

- Edit only the files named in the task (one lib file + optionally its existing test file). Never create files unless told to.
- Do not reformat the file, do not reorder imports you did not touch, do not rename things.
- Use theme tokens, never raw colors: `MonoPulseColors.*`, `context.mp.*`, `Theme.of(context).colorScheme.*`, `Theme.of(context).textTheme.*`.
- Imports: `package:flowgroove/...` in tests, relative imports in lib. Keep `directives_ordering` (alphabetical) when you add an import.
- Style: trailing commas, `const` where possible, no `print`.
- NEVER touch `lib/services/audio/engine/*`, `firestore.rules`, `storage.rules`, `pubspec.yaml`.
- Tests: change only the assertions that your new behavior makes false. Keep test names. Tests use `package:flowgroove/...`, Riverpod `ProviderScope`/`ProviderContainer` overrides, fake `DrumPlayer` (see `test/midi/drum_practice_panel_test.dart`), and `rootScaffoldMessengerKey` for snackbars.
- You cannot run commands. The runner runs the tests for you and shows you the errors: fix only what they say.
- Existing strings that tests look for must stay exactly as they are unless the task says to change them.
- When done print DONE.

## Test trap (cost us 77 minutes once)
Widget tests pump the sheet/editor in a FIXED viewport (`tester.view.physicalSize`, e.g. 400x900). When you make the UI taller,
a button can fall out of the lazily built ListView and the test fails with `Bad state: No element` (e.g. in `ensureVisible`).
That is a TEST problem, not a bug in your change: make the test viewport taller (e.g. `Size(400, 1600)`) or call
`await tester.scrollUntilVisible(finder, 200)` before using the finder. Do not undo your UI change.
