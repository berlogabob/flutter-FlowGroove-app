import 'package:flutter/material.dart';
import 'package:flowgroove/screens/settings/design_system_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';

/// Standalone entry point for previewing the app design system without signing
/// in or initializing Firebase.
void main() {
  runApp(const FlowGrooveDesignSystemPreview());
}

class FlowGrooveDesignSystemPreview extends StatelessWidget {
  const FlowGrooveDesignSystemPreview({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FlowGroove Design System Preview',
    debugShowCheckedModeBanner: false,
    theme: MonoPulseTheme.lightTheme,
    darkTheme: MonoPulseTheme.theme,
    themeMode: ThemeMode.light,
    home: const DesignSystemScreen(),
  );
}
