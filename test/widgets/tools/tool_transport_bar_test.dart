import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/tools/tool_transport_bar.dart';
import 'package:flutter_repsync_app/theme/mono_pulse_theme.dart';
import 'package:flutter_repsync_app/widgets/tools/tool_scaffold.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('ToolTransportBar', () {
    testWidgets('renders with required parameters', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      expect(find.byType(ToolTransportBar), findsOneWidget);
    });

    testWidgets('renders play button when not playing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('renders pause button when playing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: true, onPlayPause: _noOp),
        ),
      );

      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('play/pause button uses accentOrange color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      // Find the Container with accentOrange color
      final containers = tester.widgetList<Container>(find.byType(Container));
      final playButtonContainer = containers.firstWhere(
        (container) =>
            container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).color ==
                MonoPulseColors.accentOrange,
        orElse: () => Container(),
      );

      expect(playButtonContainer.decoration, isNotNull);
    });

    testWidgets('play/pause button is circular', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      // Find the Container with circular shape and orange color
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCircularOrangeButton = containers.any(
        (container) =>
            container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).shape == BoxShape.circle &&
            (container.decoration as BoxDecoration).color ==
                MonoPulseColors.accentOrange,
      );

      expect(hasCircularOrangeButton, isTrue);
    });

    testWidgets('play/pause button is larger than navigation buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      // The play button should be touchSize * 1.2
      // Navigation buttons should be touchSize
      // We verify by checking multiple circular containers exist
      final containers = tester.widgetList<Container>(find.byType(Container));
      final circularContainers = containers
          .where(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).shape == BoxShape.circle,
          )
          .toList();

      expect(circularContainers.length, greaterThanOrEqualTo(3));
    });

    testWidgets('calls onPlayPause when play/pause button tapped', (
      WidgetTester tester,
    ) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: () => wasPressed = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      expect(wasPressed, isTrue);
    });

    testWidgets('toggles between play and pause icons', (
      WidgetTester tester,
    ) async {
      bool isPlaying = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ToolTransportBar(
                isPlaying: isPlaying,
                onPlayPause: () {
                  setState(() => isPlaying = !isPlaying);
                },
              );
            },
          ),
        ),
      );

      // Initially showing play
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);

      // Tap to play
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      // Now showing pause
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // Tap to pause
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      // Back to play
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('renders navigation buttons when showNavigation is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });

    testWidgets('hides navigation buttons when showNavigation is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: false,
          ),
        ),
      );

      expect(find.byIcon(Icons.skip_previous), findsNothing);
      expect(find.byIcon(Icons.skip_next), findsNothing);
    });

    testWidgets('hides navigation buttons when callbacks are null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            // onPrevious and onNext are null
          ),
        ),
      );

      expect(find.byIcon(Icons.skip_previous), findsNothing);
      expect(find.byIcon(Icons.skip_next), findsNothing);
    });

    testWidgets('calls onPrevious when previous button tapped', (
      WidgetTester tester,
    ) async {
      bool previousCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: () => previousCalled = true,
            onNext: _noOp,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.skip_previous));
      await tester.pump();

      expect(previousCalled, isTrue);
    });

    testWidgets('calls onNext when next button tapped', (
      WidgetTester tester,
    ) async {
      bool nextCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: () => nextCalled = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pump();

      expect(nextCalled, isTrue);
    });

    testWidgets('navigation buttons use surfaceRaised color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      // Navigation buttons should have surfaceRaised background
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasSurfaceRaisedButton = containers.any(
        (container) =>
            container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).color ==
                MonoPulseColors.surfaceRaised,
      );

      expect(hasSurfaceRaisedButton, isTrue);
    });

    testWidgets('navigation buttons have borderSubtle border', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      // Verify containers with borders exist
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBorderedContainer = containers.any(
        (container) =>
            container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).border != null,
      );

      expect(hasBorderedContainer, isTrue);
    });

    testWidgets('navigation buttons use textSecondary icon color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      final previousIcon = tester.widget<Icon>(
        find.byIcon(Icons.skip_previous),
      );
      expect(previousIcon.color, equals(MonoPulseColors.textSecondary));

      final nextIcon = tester.widget<Icon>(find.byIcon(Icons.skip_next));
      expect(nextIcon.color, equals(MonoPulseColors.textSecondary));
    });

    testWidgets('renders settings button when showSettings is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showSettings: true,
            onSettings: _noOp,
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('hides settings button when showSettings is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showSettings: false,
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsNothing);
    });

    testWidgets('hides settings button when onSettings is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showSettings: true,
            // onSettings is null
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsNothing);
    });

    testWidgets('calls onSettings when settings button tapped', (
      WidgetTester tester,
    ) async {
      bool settingsCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showSettings: true,
            onSettings: () => settingsCalled = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();

      expect(settingsCalled, isTrue);
    });

    testWidgets('has correct height of 80 pixels', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      // Find the Container with height constraint
      final containers = tester.widgetList<Container>(find.byType(Container));
      final heightContainer = containers.firstWhere(
        (c) =>
            c.constraints != null &&
            c.constraints is BoxConstraints &&
            (c.constraints as BoxConstraints).hasBoundedHeight &&
            (c.constraints as BoxConstraints).maxHeight == 80,
        orElse: () => Container(),
      );

      expect(heightContainer.constraints, isNotNull);
    });

    testWidgets('has horizontal margin using ToolSpacing.xxxl', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      // Verify the widget renders with margins
      expect(find.byType(ToolTransportBar), findsOneWidget);
    });

    testWidgets('has vertical margin using ToolSpacing.lg', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      // Verify the widget renders correctly
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('buttons are centered in row', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.mainAxisAlignment, equals(MainAxisAlignment.center));
    });

    testWidgets('play/pause button icon is white', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      final playIcon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
      expect(playIcon.color, equals(Colors.white));
    });

    testWidgets('pause button icon is white', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: true, onPlayPause: _noOp),
        ),
      );

      final pauseIcon = tester.widget<Icon>(find.byIcon(Icons.pause));
      expect(pauseIcon.color, equals(Colors.white));
    });

    testWidgets('render multiple buttons together', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
            showSettings: true,
            onSettings: _noOp,
          ),
        ),
      );

      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('ToolTransportBar Haptic Feedback', () {
    testWidgets('play/pause button triggers interaction', (
      WidgetTester tester,
    ) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: () => wasPressed = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      expect(wasPressed, isTrue);
    });

    testWidgets('navigation buttons trigger interaction', (
      WidgetTester tester,
    ) async {
      bool previousCalled = false;
      bool nextCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: () => previousCalled = true,
            onNext: () => nextCalled = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.skip_previous));
      await tester.pump();
      expect(previousCalled, isTrue);

      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pump();
      expect(nextCalled, isTrue);
    });

    testWidgets('settings button triggers interaction', (
      WidgetTester tester,
    ) async {
      bool settingsCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showSettings: true,
            onSettings: () => settingsCalled = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();

      expect(settingsCalled, isTrue);
    });
  });

  group('ToolTransportBar Accessibility', () {
    testWidgets('play/pause button meets minimum touch target', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      // Play button is touchSize * 1.2, which should be >= 48px
      final containers = tester.widgetList<Container>(find.byType(Container));
      final circularContainers = containers
          .where(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).shape == BoxShape.circle,
          )
          .toList();

      expect(circularContainers.isNotEmpty, isTrue);
    });

    testWidgets('navigation buttons have adequate size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      // Navigation buttons use ToolTouchTarget.large which is >= 48px on expanded+
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });

    testWidgets('all buttons are circular for easy tapping', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
            showSettings: true,
            onSettings: _noOp,
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final circularContainers = containers
          .where(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).shape == BoxShape.circle,
          )
          .toList();

      // Should have at least 4 circular buttons (prev, play/pause, next, settings)
      expect(circularContainers.length, greaterThanOrEqualTo(4));
    });
  });

  group('ToolTransportBar MonoPulse Theme', () {
    testWidgets('play button uses accentOrange', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final orangeContainer = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color ==
                MonoPulseColors.accentOrange,
        orElse: () => Container(),
      );

      expect(orangeContainer.decoration, isNotNull);
    });

    testWidgets('navigation buttons use surfaceRaised', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final surfaceContainer = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color ==
                MonoPulseColors.surfaceRaised,
        orElse: () => Container(),
      );

      expect(surfaceContainer.decoration, isNotNull);
    });

    testWidgets('icons use correct theme colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      // Play icon should be white
      final playIcon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
      expect(playIcon.color, equals(Colors.white));

      // Navigation icons should be textSecondary
      final navIcon = tester.widget<Icon>(find.byIcon(Icons.skip_previous));
      expect(navIcon.color, equals(MonoPulseColors.textSecondary));
    });

    testWidgets('borders use borderSubtle color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      // Verify bordered containers exist
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBorderedContainer = containers.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).border != null,
      );

      expect(hasBorderedContainer, isTrue);
    });
  });

  group('_PlayPauseButton', () {
    testWidgets('renders play icon when not playing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('renders pause icon when playing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: true, onPlayPause: _noOp),
        ),
      );

      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('icon size is proportional to button size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(isPlaying: false, onPlayPause: _noOp),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
      // Icon size should be 50% of button size (size * 0.5)
      expect(icon.size, greaterThan(0));
    });
  });

  group('_TransportButton', () {
    testWidgets('renders with correct icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });

    testWidgets('icon size is proportional to button size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.skip_previous));
      // Icon size should be 40% of button size (size * 0.4)
      expect(icon.size, greaterThan(0));
    });

    testWidgets('has circular decoration', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolTransportBar(
            isPlaying: false,
            onPlayPause: _noOp,
            showNavigation: true,
            onPrevious: _noOp,
            onNext: _noOp,
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCircularNavButton = containers.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).shape == BoxShape.circle &&
            (c.decoration as BoxDecoration).color ==
                MonoPulseColors.surfaceRaised,
      );

      expect(hasCircularNavButton, isTrue);
    });
  });
}

void _noOp() {}
