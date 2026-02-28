import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mono Pulse Design System
///
/// Core Philosophy: Clean. Confident. Premium-minimal.
/// Inspirations: Teenage Engineering, Nothing, Notion, Revolut
///
/// Color System: Strict monochrome + one hero accent (orange)

class MonoPulseColors {
  // Base - True Black
  static const Color black = Color(0xFF000000);
  static const Color blackSurface = Color(0xFF0A0A0A);
  static const Color blackElevated = Color(0xFF111111);

  // Surface / Cards
  static const Color surface = Color(0xFF121212);
  static const Color surfaceRaised = Color(0xFF1A1A1A);
  static const Color surfaceOverlay = Color(0xFF1E1E1E);

  // Borders & Dividers
  static const Color borderSubtle = Color(0xFF222222);
  static const Color borderDefault = Color(0xFF333333);
  static const Color borderStrong = Color(0xFF444444);

  // Text - Primary
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textHighEmphasis = Color(0xFFEDEDED);

  // Text - Secondary
  static const Color textSecondary = Color(0xFFA0A0A5);
  static const Color textTertiary = Color(0xFF8A8A8F);
  static const Color textDisabled = Color(0xFF555555);

  // Brand Accent - Orange (used surgically)
  static const Color accentOrange = Color(0xFFFF5E00);
  static const Color accentOrangeLight = Color(0xFFFF6B1A);
  static const Color accentOrangeDark = Color(0xFFE64E00);
  static const Color accentOrangeSubtle = Color(0x1AFF5E00); // 10% opacity

  // Beat Mode Colors
  static const Color beatModeNormal = Color(0xFFFF5E00); // Orange
  static const Color beatModeAccent = Color(0xFF00BCD4); // Cyan
  static const Color beatModeSilent = Color(0xFFE91E63); // Magenta

  // Bright versions for active state
  static const Color beatModeNormalBright = Color(0xFFFF7B33); // Bright Orange
  static const Color beatModeAccentBright = Color(0xFF26C6DA); // Bright Cyan
  static const Color beatModeSilentBright = Color(0xFFEC407A); // Bright Magenta

  // Error - Muted Red (very rare)
  static const Color error = Color(0xFFFF2D55);
  static const Color errorSubtle = Color(0x1AFF2D55);

  // Success - Orange or White
  static const Color success = accentOrange;
  static const Color successAlt = textPrimary;

  // ============================================
  // Status Colors
  // ============================================

  // Success (green - for non-orange success states)
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color successGreenSubtle = Color(0x0D4CAF50); // 5% opacity

  // Warning
  static const Color warning = Color(0xFFFF9800);
  static const Color warningSubtle = Color(0x0DFF9800); // 5% opacity

  // Info
  static const Color info = Color(0xFF2196F3);
  static const Color infoSubtle = Color(0x0D2196F3); // 5% opacity

  // ============================================
  // Role Colors
  // ============================================

  static const Color roleAdmin = Color(0xFFFF5252);
  static const Color roleEditor = Color(0xFF42A5F5);
  static const Color roleViewer = Color(0xFF9E9E9E);

  // ============================================
  // Match Grade Colors
  // ============================================

  static const Color matchExact = Color(0xFF4CAF50);
  static const Color matchHigh = Color(0xFF8BC34A);
  static const Color matchMedium = Color(0xFFFF9800);
  static const Color matchLow = Color(0xFFF57C00);
  static const Color matchNone = Color(0xFFF44336);

  // ============================================
  // Opacity Variants
  // ============================================

  // Error opacity variants
  static const Color errorSubtle5 = Color(0x0DFF2D55); // 5%
  static const Color errorSubtle20 = Color(0x33FF2D55); // 20%
  static const Color errorSubtle30 = Color(0x4DFF2D55); // 30%

  // Orange opacity variants
  static const Color orangeSubtle5 = Color(0x0DFF5E00); // 5%
  static const Color orangeSubtle20 = Color(0x33FF5E00); // 20%
  static const Color orangeSubtle30 = Color(0x4DFF5E00); // 30%

  // ============================================
  // Section Colors (for song organization)
  // ============================================
  // 14 visually distinct colors that work on dark background

  static const Color section1 = Color(0xFFE91E63); // Pink
  static const Color section2 = Color(0xFF9C27B0); // Purple
  static const Color section3 = Color(0xFF673AB7); // Deep Purple
  static const Color section4 = Color(0xFF3F51B5); // Indigo
  static const Color section5 = Color(0xFF03A9F4); // Light Blue
  static const Color section6 = Color(0xFF00BCD4); // Cyan
  static const Color section7 = Color(0xFF009688); // Teal
  static const Color section8 = Color(0xFF4CAF50); // Green
  static const Color section9 = Color(0xFF8BC34A); // Light Green
  static const Color section10 = Color(0xFFCDDC39); // Lime
  static const Color section11 = Color(0xFFFFEB3B); // Yellow
  static const Color section12 = Color(0xFFFFC107); // Amber
  static const Color section13 = Color(0xFFFF9800); // Orange
  static const Color section14 = Color(0xFFFF5722); // Deep Orange

  // Special
  static const Color transparent = Colors.transparent;
  static const Color white = Color(0xFFFFFFFF);
}

/// Typography - Inter / System SF Pro
/// Strict 4-point grid scale
class MonoPulseTypography {
  // Font Family
  static const String fontFamily = '.SF Pro Text'; // Falls back to system
  static const String fontFamilyDisplay = '.SF Pro Display';

  // Weights
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // Scale (4-point grid: 4, 8, 12, 16, 20, 24, 32, 40, 48)

  // Display - Hero titles only
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 40,
    fontWeight: semibold,
    height: 1.32,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 32,
    fontWeight: semibold,
    height: 1.35,
    letterSpacing: -0.25,
  );

  // Headings
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: semibold,
    height: 1.38,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: semibold,
    height: 1.4,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: semibold,
    height: 1.45,
  );

  // Title - For tool screens
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: semibold,
    height: 1.36,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: regular,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: regular,
    height: 1.43,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: regular,
    height: 1.33,
  );

  // Labels / Buttons
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: medium,
    height: 1.43,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: medium,
    height: 1.33,
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: medium,
    height: 1.45,
    letterSpacing: 0.5,
  );
}

/// Spacing - 4-point grid system
/// Generous padding for negative space
class MonoPulseSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 48;
}

/// Border Radius
/// 12-16px cards/buttons, 8-10px small, 20-24px large
class MonoPulseRadius {
  static const double small = 8;
  static const double medium = 10;
  static const double large = 12;
  static const double xlarge = 16;
  static const double huge = 20;
  static const double massive = 24;
}

/// Elevation & Shadows
/// Very soft, subtle depth
class MonoPulseElevation {
  static const double none = 0;
  static const double low = 2;
  static const double medium = 4;
  static const double high = 8;

  static BoxShadow shadowLow = BoxShadow(
    color: MonoPulseColors.black.withValues(alpha: 0.3),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );

  static BoxShadow shadowMedium = BoxShadow(
    color: MonoPulseColors.black.withValues(alpha: 0.4),
    blurRadius: 16,
    offset: const Offset(0, 4),
  );

  static BoxShadow shadowHigh = BoxShadow(
    color: MonoPulseColors.black.withValues(alpha: 0.5),
    blurRadius: 24,
    offset: const Offset(0, 8),
  );
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
  static const Curve curveCustom = Cubic(0.4, 0.0, 0.2, 1.0);
}

/// Icon Theme
/// 1.5-2px line weight, outline preferred
class MonoPulseIcons {
  static const double sizeSmall = 16;
  static const double sizeMedium = 20;
  static const double sizeLarge = 24;
  static const double sizeXLarge = 32;

  static const double strokeWidthDefault = 1.5;
  static const double strokeWidthBold = 2.0;
}

/// Mono Pulse Dark Theme (ONLY THEME - dark-only)
class MonoPulseTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: MonoPulseColors.accentOrange,
        onPrimary: MonoPulseColors.black,
        primaryContainer: MonoPulseColors.accentOrangeDark,
        onPrimaryContainer: MonoPulseColors.textPrimary,

        secondary: MonoPulseColors.textSecondary,
        onSecondary: MonoPulseColors.black,

        tertiary: MonoPulseColors.surfaceRaised,
        onTertiary: MonoPulseColors.textPrimary,

        surface: MonoPulseColors.surface,
        onSurface: MonoPulseColors.textPrimary,
        surfaceContainerHighest: MonoPulseColors.surfaceRaised,
        onSurfaceVariant: MonoPulseColors.textSecondary,

        outline: MonoPulseColors.borderDefault,
        outlineVariant: MonoPulseColors.borderSubtle,

        error: MonoPulseColors.error,
        onError: MonoPulseColors.white,
        errorContainer: MonoPulseColors.errorSubtle,
        onErrorContainer: MonoPulseColors.error,

        shadow: MonoPulseColors.black,
      ),

      // Scaffold
      scaffoldBackgroundColor: MonoPulseColors.black,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: MonoPulseColors.black,
        foregroundColor: MonoPulseColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: MonoPulseTypography.headlineLarge,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Buttons - Elevated (Primary CTA)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MonoPulseColors.accentOrange,
          foregroundColor: MonoPulseColors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.xl,
            vertical: MonoPulseSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          ),
          textStyle: MonoPulseTypography.labelLarge,
        ),
      ),

      // Buttons - Outlined (Secondary)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MonoPulseColors.textPrimary,
          side: const BorderSide(
            color: MonoPulseColors.borderDefault,
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.xl,
            vertical: MonoPulseSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          ),
          textStyle: MonoPulseTypography.labelLarge,
        ),
      ),

      // Buttons - Text (Tertiary)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MonoPulseColors.accentOrange,
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.md,
            vertical: MonoPulseSpacing.sm,
          ),
          textStyle: MonoPulseTypography.labelLarge,
        ),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MonoPulseColors.surfaceRaised,
        hintStyle: const TextStyle(color: MonoPulseColors.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          borderSide: const BorderSide(color: MonoPulseColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          borderSide: const BorderSide(color: MonoPulseColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          borderSide: const BorderSide(
            color: MonoPulseColors.accentOrange,
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
        color: MonoPulseColors.surface,
        elevation: 0,
        shadowColor: MonoPulseColors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          side: const BorderSide(color: MonoPulseColors.borderSubtle),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MonoPulseColors.accentOrange,
        foregroundColor: MonoPulseColors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        ),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: MonoPulseColors.black,
        selectedItemColor: MonoPulseColors.accentOrange,
        unselectedItemColor: MonoPulseColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Navigation Bar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: MonoPulseColors.black,
        indicatorColor: MonoPulseColors.accentOrangeSubtle,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MonoPulseTypography.labelSmall.copyWith(
              color: MonoPulseColors.accentOrange,
            );
          }
          return MonoPulseTypography.labelSmall.copyWith(
            color: MonoPulseColors.textTertiary,
          );
        }),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: MonoPulseColors.surfaceRaised,
        labelStyle: const TextStyle(color: MonoPulseColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          side: const BorderSide(color: MonoPulseColors.borderDefault),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.md,
          vertical: MonoPulseSpacing.xs,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: MonoPulseColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MonoPulseColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: MonoPulseColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        ),
        actionTextColor: MonoPulseColors.accentOrange,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: MonoPulseColors.surface,
        titleTextStyle: MonoPulseTypography.headlineLarge,
        contentTextStyle: MonoPulseTypography.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: MonoPulseTypography.displayLarge,
        displayMedium: MonoPulseTypography.displayMedium,
        headlineLarge: MonoPulseTypography.headlineLarge,
        headlineMedium: MonoPulseTypography.headlineMedium,
        headlineSmall: MonoPulseTypography.headlineSmall,
        bodyLarge: MonoPulseTypography.bodyLarge,
        bodyMedium: MonoPulseTypography.bodyMedium,
        bodySmall: MonoPulseTypography.bodySmall,
        labelLarge: MonoPulseTypography.labelLarge,
        labelMedium: MonoPulseTypography.labelMedium,
        labelSmall: MonoPulseTypography.labelSmall,
      ),
    );
  }
}
