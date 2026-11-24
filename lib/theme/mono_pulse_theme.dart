import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

part 'mono_pulse_tokens.g.dart';

/// FlowGroove visual system: warm studio paper, dark instrument housings,
/// readable music notation, and a confident orange transport accent.

/// Theme-dependent neutrals (#132): the 14 names above that must flip
/// between dark and light. Brand accent, beat, status and section colors are
/// theme-invariant and stay on [MonoPulseColors]. Widgets read this via
/// `context.mp` — never reference the dark constants directly for neutrals.
@immutable
class MonoPulsePalette extends ThemeExtension<MonoPulsePalette> {
  const MonoPulsePalette({
    required this.black,
    required this.blackSurface,
    required this.blackElevated,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.textPrimary,
    required this.textHighEmphasis,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
  });

  /// App background ("black" keeps the historical name; it's paper in light).
  final Color black;
  final Color blackSurface;
  final Color blackElevated;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceOverlay;
  final Color borderSubtle;
  final Color borderDefault;
  final Color borderStrong;
  final Color textPrimary;
  final Color textHighEmphasis;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  static const dark = MonoPulsePalette(
    black: MonoPulseColors.black,
    blackSurface: MonoPulseColors.blackSurface,
    blackElevated: MonoPulseColors.blackElevated,
    surface: MonoPulseColors.surface,
    surfaceRaised: MonoPulseColors.surfaceRaised,
    surfaceOverlay: MonoPulseColors.surfaceOverlay,
    borderSubtle: MonoPulseColors.borderSubtle,
    borderDefault: MonoPulseColors.borderDefault,
    borderStrong: MonoPulseColors.borderStrong,
    textPrimary: MonoPulseColors.textPrimary,
    textHighEmphasis: MonoPulseColors.textHighEmphasis,
    textSecondary: MonoPulseColors.textSecondary,
    textTertiary: MonoPulseColors.textTertiary,
    textDisabled: MonoPulseColors.textDisabled,
  );

  /// Light FlowGroove: warm paper, stone hardware, and charcoal ink.
  static const light = MonoPulsePalette(
    black: MonoPulseLight.black,
    blackSurface: MonoPulseLight.blackSurface,
    blackElevated: MonoPulseLight.blackElevated,
    surface: MonoPulseLight.surface,
    surfaceRaised: MonoPulseLight.surfaceRaised,
    surfaceOverlay: MonoPulseLight.surfaceOverlay,
    borderSubtle: MonoPulseLight.borderSubtle,
    borderDefault: MonoPulseLight.borderDefault,
    borderStrong: MonoPulseLight.borderStrong,
    textPrimary: MonoPulseLight.textPrimary,
    textHighEmphasis: MonoPulseLight.textHighEmphasis,
    textSecondary: MonoPulseLight.textSecondary,
    textTertiary: MonoPulseLight.textTertiary,
    textDisabled: MonoPulseLight.textDisabled,
  );

  @override
  MonoPulsePalette copyWith({
    Color? black,
    Color? blackSurface,
    Color? blackElevated,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceOverlay,
    Color? borderSubtle,
    Color? borderDefault,
    Color? borderStrong,
    Color? textPrimary,
    Color? textHighEmphasis,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
  }) {
    return MonoPulsePalette(
      black: black ?? this.black,
      blackSurface: blackSurface ?? this.blackSurface,
      blackElevated: blackElevated ?? this.blackElevated,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textHighEmphasis: textHighEmphasis ?? this.textHighEmphasis,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
    );
  }

  @override
  MonoPulsePalette lerp(MonoPulsePalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MonoPulsePalette(
      black: l(black, other.black),
      blackSurface: l(blackSurface, other.blackSurface),
      blackElevated: l(blackElevated, other.blackElevated),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceOverlay: l(surfaceOverlay, other.surfaceOverlay),
      borderSubtle: l(borderSubtle, other.borderSubtle),
      borderDefault: l(borderDefault, other.borderDefault),
      borderStrong: l(borderStrong, other.borderStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textHighEmphasis: l(textHighEmphasis, other.textHighEmphasis),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      textDisabled: l(textDisabled, other.textDisabled),
    );
  }
}

/// `context.mp` — the theme-aware MonoPulse neutrals. Falls back to dark so
/// bare-MaterialApp widget tests (no MonoPulse theme) keep working.
extension MonoPulseContext on BuildContext {
  MonoPulsePalette get mp =>
      Theme.of(this).extension<MonoPulsePalette>() ?? MonoPulsePalette.dark;
}

/// Animation & Motion
/// Short (120-180ms), buttery-smooth, purposeful
class MonoPulseAnimation {
  static const Duration durationShort = Duration(milliseconds: 120);
  static const Duration durationMedium = Duration(milliseconds: 180);
  static const Duration durationLong = Duration(milliseconds: 240);

  static const Curve curveDefault = Curves.easeOut;
  static const Curve curveEmphasized = Curves.easeOutCubic;
  static const Curve curveDecelerate = Curves.easeOutCubic;
  static const Curve curveAccelerate = Curves.easeInCubic;

  // Cubic-bezier 0.4 0 0.2 1
  static const Curve curveCustom = Cubic(0.4, 0, 0.2, 1);
}

/// Mono Pulse theme — one parameterized builder (#132): dark and light share
/// the exact ThemeData structure, differing only by [MonoPulsePalette].
class MonoPulseTheme {
  static ThemeData get lightTheme =>
      _build(MonoPulsePalette.light, Brightness.light);

  static ThemeData get theme => _build(MonoPulsePalette.dark, Brightness.dark);

  /// The ColorScheme both themes share, exposed for direct testing (the
  /// full ThemeData is heavier than a scheme test needs).
  @visibleForTesting
  static ColorScheme schemeFor(MonoPulsePalette p, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final baseScheme = dark
        ? const ColorScheme.dark()
        : const ColorScheme.light();
    return baseScheme.copyWith(
      primary: MonoPulseColors.accentOrange,
      onPrimary: MonoPulseColors.charcoal,
      primaryContainer: MonoPulseColors.accentOrangeDark,
      onPrimaryContainer: p.textPrimary,
      secondary: p.textSecondary,
      // Pin the *Container slots explicitly: ColorScheme's getters fall
      // back secondaryContainer→secondary / tertiaryContainer→tertiary,
      // and copyWith BAKES the base scheme's getter value in — leaving
      // these unset froze legacy teal #03DAC6 into tonal buttons (the
      // 0.17.0 cyan-button regression).
      secondaryContainer: p.textSecondary,
      onSecondaryContainer: dark
          ? MonoPulseColors.black
          : MonoPulseColors.white,
      tertiary: p.surfaceRaised,
      onTertiary: p.textPrimary,
      tertiaryContainer: p.surfaceRaised,
      onTertiaryContainer: p.textPrimary,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surfaceRaised,
      onSurfaceVariant: p.textSecondary,
      outline: p.borderDefault,
      outlineVariant: p.borderSubtle,
      error: MonoPulseColors.error,
      onError: MonoPulseColors.white,
      errorContainer: MonoPulseColors.error10,
      onErrorContainer: MonoPulseColors.error,
      shadow: MonoPulseColors.black,
    );
  }

  static ThemeData _build(MonoPulsePalette p, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // White-based hover reads on dark; flip to black-based on light.
    final hover = dark ? MonoPulseColors.stateHover : const Color(0x0A000000);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: <ThemeExtension<dynamic>>[p],

      colorScheme: schemeFor(p, brightness),

      // Scaffold ("black" is the app background slot; paper in light).
      scaffoldBackgroundColor: p.black,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: p.black,
        foregroundColor: p.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: MonoPulseTypography.headlineLarge,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // Buttons - Elevated (Primary CTA): black-on-orange in both themes.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MonoPulseColors.accentOrange,
          foregroundColor: MonoPulseColors.charcoal,
          elevation: 3,
          shadowColor: dark ? MonoPulseColors.charcoal : MonoPulseColors.fog,
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.xl,
            vertical: MonoPulseSpacing.lg,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(MonoPulseRadius.button),
            ),
            side: BorderSide(color: MonoPulseColors.charcoal, width: 1.2),
          ),
          textStyle: MonoPulseTypography.labelLarge,
        ).copyWith(overlayColor: _stateOverlay(hover)),
      ),

      // Buttons - Filled. One orange CTA look app-wide: FilledButton takes
      // the same shape, charcoal border, shadow and label as the
      // ElevatedButton theme (= CustomButton primary, FigCraft Button/Primary).
      // Before 2026-11 it was radius 12 with no border, so a screen could show
      // two different orange buttons (Save Song vs Share).
      //
      // SHAPE LANGUAGE (UX audit F-018):
      //   radius button (5)  — every button that sits in a layout
      //   radius xlarge (16) — floating / transport controls (FAB)
      //   stadium            — nowhere
      //
      // Colours are deliberately not pinned: they resolve through
      // colorScheme.primary / onPrimary, so the few sites that repaint a
      // FilledButton (neutral tool buttons) keep their own background.
      // Padding stays Material's compact default: FilledButton is the
      // dialog / sheet / inline CTA; full-width form CTAs use CustomButton.
      // FilledButton.tonal shares this theme, so CustomButton's tonal variant
      // clears the border and shadow itself; use it, not a raw .tonal.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 3,
          shadowColor: dark ? MonoPulseColors.charcoal : MonoPulseColors.fog,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(MonoPulseRadius.button),
            ),
            side: BorderSide(color: MonoPulseColors.charcoal, width: 1.2),
          ),
          textStyle: MonoPulseTypography.labelLarge,
        ).copyWith(overlayColor: _stateOverlay(hover)),
      ),

      // Buttons - Outlined (Secondary)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.borderDefault),
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.xl,
            vertical: MonoPulseSpacing.lg,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(MonoPulseRadius.button),
            ),
          ),
          textStyle: MonoPulseTypography.labelLarge,
        ).copyWith(overlayColor: _stateOverlay(hover)),
      ),

      // Buttons - Text (Tertiary)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.textPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.md,
            vertical: MonoPulseSpacing.sm,
          ),
          textStyle: MonoPulseTypography.labelLarge,
        ),
      ),

      // Buttons - Segmented
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return states.contains(WidgetState.selected)
                ? MonoPulseColors.stone
                : null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return states.contains(WidgetState.selected)
                ? MonoPulseColors.charcoal
                : null;
          }),
        ),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MonoPulseColors.white,
        hintStyle: TextStyle(color: p.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          borderSide: BorderSide(color: p.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          borderSide: BorderSide(color: p.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          borderSide: const BorderSide(
            color: MonoPulseColors.charcoal,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          borderSide: const BorderSide(color: MonoPulseColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          borderSide: const BorderSide(color: MonoPulseColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.lg,
          vertical: MonoPulseSpacing.md,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 1,
        shadowColor: p.borderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.cardMaterial),
          side: BorderSide(color: p.borderDefault),
        ),
      ),

      // Floating Action Button
      // Add actions are secondary: orange stays reserved for play/primary.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MonoPulseColors.white,
        foregroundColor: MonoPulseColors.charcoal,
        elevation: 3,
        splashColor: MonoPulseColors.stone,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.fab),
          side: const BorderSide(color: MonoPulseColors.charcoal, width: 1.2),
        ),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.black,
        selectedItemColor: MonoPulseColors.selectionInk,
        unselectedItemColor: p.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Navigation Bar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.black,
        indicatorColor: dark
            ? MonoPulseColors.accentOrange10
            : MonoPulseColors.selection,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MonoPulseTypography.labelSmall.copyWith(
              color: dark
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.selectionInk,
            );
          }
          return MonoPulseTypography.labelSmall.copyWith(color: p.textTertiary);
        }),
      ),

      // Toggles: green/grey switches, charcoal checks — never orange.
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(MonoPulseColors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MonoPulseColors.successGreen
              : MonoPulseColors.fog,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MonoPulseColors.charcoal
              : null,
        ),
        checkColor: const WidgetStatePropertyAll(MonoPulseColors.white),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(p.textPrimary),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceRaised,
        labelStyle: TextStyle(color: p.textPrimary),
        secondaryLabelStyle: const TextStyle(color: MonoPulseColors.charcoal),
        selectedColor: MonoPulseColors.stone,
        checkmarkColor: MonoPulseColors.charcoal,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          side: BorderSide(color: p.borderDefault),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.md,
          vertical: MonoPulseSpacing.xs,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: p.borderSubtle,
        thickness: 1,
        space: 1,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceRaised,
        contentTextStyle: TextStyle(color: p.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        ),
        actionTextColor: MonoPulseColors.accentOrange,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        titleTextStyle: MonoPulseTypography.headlineLarge,
        contentTextStyle: MonoPulseTypography.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        ),
      ),

      // Brand fonts are bundled assets (pubspec `fonts:`), registered under
      // the exact family names the const styles use. google_fonts registered
      // them as e.g. "Marcellus_regular", so those styles never matched and
      // every screen fell back to Roboto (fixed 2026-11-19).
      textTheme: TextTheme(
        // Slots the MonoPulse set does not define.
        displaySmall: TextStyle(
          fontFamily: MonoPulseTypography.fontFamilyDisplay,
        ),
        titleLarge: TextStyle(
          fontFamily: MonoPulseTypography.fontFamilyDisplay,
        ),
        titleMedium: TextStyle(fontFamily: MonoPulseTypography.fontFamily),
        titleSmall: TextStyle(fontFamily: MonoPulseTypography.fontFamily),
        displayLarge: MonoPulseTypography.displayLarge,
        displayMedium: MonoPulseTypography.displayMedium,
        headlineLarge: MonoPulseTypography.headlineLarge,
        headlineMedium: MonoPulseTypography.headlineMedium,
        headlineSmall: MonoPulseTypography.headlineSmall,
        // Input text: TextField/TextFormField/DropdownMenu take their colour
        // from bodyLarge, and every field is white in both themes (see
        // inputDecorationTheme), so this slot is dark. Body text that wants
        // the screen's text colour sets it from context.mp.
        bodyLarge: MonoPulseTypography.bodyLarge.copyWith(
          color: MonoPulseColors.charcoal,
        ),
        bodyMedium: MonoPulseTypography.bodyMedium,
        bodySmall: MonoPulseTypography.bodySmall,
        labelLarge: MonoPulseTypography.labelLarge,
        labelMedium: MonoPulseTypography.labelMedium,
        labelSmall: MonoPulseTypography.labelSmall,
      ),
    );
  }

  /// Pressed/hover/focus/disabled overlay shared by the button themes.
  static WidgetStateProperty<Color?> _stateOverlay(Color hover) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return MonoPulseColors.statePressed;
        }
        if (states.contains(WidgetState.hovered)) return hover;
        if (states.contains(WidgetState.focused)) {
          return MonoPulseColors.stateFocus;
        }
        if (states.contains(WidgetState.disabled)) {
          return MonoPulseColors.stateDisabled;
        }
        return null;
      });
}
