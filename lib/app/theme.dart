/// Complete application theme for Unicorn Learning Lab.
///
/// Uses the Manrope font family and the brand colour palette defined
/// in the design system.
library;

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Brand Colours
// ═══════════════════════════════════════════════════════════════════════════

/// Centralised colour tokens that mirror the brand colour guide.
class AppColors {
  AppColors._();

  // Primary palette
  static const Color deepInkNavy = Color(0xFF101C3A);
  static const Color primaryViolet = Color(0xFF5B3DF5);
  static const Color warmGold = Color(0xFFF4B52C);

  // Surfaces
  static const Color offWhite = Color(0xFFF7F8FC);
  static const Color white = Color(0xFFFFFFFF);

  // Text
  static const Color primaryText = Color(0xFF172033);
  static const Color secondaryText = Color(0xFF667085);

  // Borders
  static const Color border = Color(0xFFE4E7EC);

  // Semantic
  static const Color success = Color(0xFF168653);
  static const Color error = Color(0xFFD92D20);

  // Soft backgrounds
  static const Color softViolet = Color(0xFFF0EDFF);
  static const Color softGold = Color(0xFFFFF6DF);

  // Derived / utility
  static const Color disabledBackground = Color(0xFFE4E7EC);
  static const Color disabledText = Color(0xFF98A2B3);
  static const Color shadowColor = Color(0x1A101C3A);
}

// ═══════════════════════════════════════════════════════════════════════════
//  Text Styles
// ═══════════════════════════════════════════════════════════════════════════

/// Pre-defined text styles using Manrope.
///
/// All styles default to [AppColors.primaryText]; override via `copyWith`.
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Manrope';

  // ── Display / Headings ────────────────────────────────────────────────

  /// 32 / ExtraBold – splash / hero headings.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.primaryText,
    height: 1.25,
    letterSpacing: -0.5,
  );

  /// 28 / Bold – screen titles.
  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryText,
    height: 1.29,
    letterSpacing: -0.3,
  );

  /// 24 / Bold – section headings.
  static const TextStyle headingLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryText,
    height: 1.33,
  );

  /// 20 / SemiBold – card titles.
  static const TextStyle headingMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    height: 1.4,
  );

  /// 18 / SemiBold – sub-section headings.
  static const TextStyle headingSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    height: 1.44,
  );

  // ── Body ──────────────────────────────────────────────────────────────

  /// 16 / Regular – primary body copy.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryText,
    height: 1.5,
  );

  /// 14 / Regular – secondary body copy.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryText,
    height: 1.43,
  );

  /// 12 / Regular – captions, timestamps.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
    height: 1.33,
  );

  // ── Labels / Buttons ──────────────────────────────────────────────────

  /// 16 / SemiBold – primary buttons.
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    height: 1.5,
  );

  /// 14 / SemiBold – secondary buttons.
  static const TextStyle buttonMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    height: 1.43,
  );

  /// 14 / Medium – form labels, table headers.
  static const TextStyle label = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
    height: 1.43,
  );

  /// 12 / Medium – chips, badges, small labels.
  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
    height: 1.33,
  );

  // ── Specialised ───────────────────────────────────────────────────────

  /// 48 / ExtraBold – large score/stat display.
  static const TextStyle scoreDisplay = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    color: AppColors.primaryViolet,
    height: 1.17,
    letterSpacing: -1,
  );

  /// 24 / Bold – question number in quiz.
  static const TextStyle questionNumber = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryViolet,
    height: 1.33,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  Spacing & Radius
// ═══════════════════════════════════════════════════════════════════════════

/// Consistent spacing scale (multiples of 4).
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double massive = 64;
}

/// Consistent border-radius scale.
class AppRadius {
  AppRadius._();

  static const double sm = 6;
  static const double md = 8;
  static const double base = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 999;
}

// ═══════════════════════════════════════════════════════════════════════════
//  Material Theme
// ═══════════════════════════════════════════════════════════════════════════

/// Builds the full [ThemeData] for the application.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => light;

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Manrope',

      // ── Colour scheme ──────────────────────────────────────────────────
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryViolet,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.softViolet,
        onPrimaryContainer: AppColors.primaryViolet,
        secondary: AppColors.warmGold,
        onSecondary: AppColors.deepInkNavy,
        secondaryContainer: AppColors.softGold,
        onSecondaryContainer: AppColors.deepInkNavy,
        surface: AppColors.white,
        onSurface: AppColors.primaryText,
        onSurfaceVariant: AppColors.secondaryText,
        error: AppColors.error,
        onError: AppColors.white,
        outline: AppColors.border,
        outlineVariant: AppColors.border,
        shadow: AppColors.shadowColor,
      ),

      scaffoldBackgroundColor: AppColors.offWhite,

      // ── App bar ────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headingMedium,
        iconTheme: IconThemeData(color: AppColors.primaryText, size: 24),
      ),

      // ── Cards ──────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Elevated button ────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryViolet,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.disabledBackground,
          disabledForegroundColor: AppColors.disabledText,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.base,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          textStyle: AppTextStyles.buttonLarge,
          minimumSize: const Size(120, 52),
        ),
      ),

      // ── Outlined button ────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryViolet,
          disabledForegroundColor: AppColors.disabledText,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.base,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          side: const BorderSide(color: AppColors.primaryViolet),
          textStyle: AppTextStyles.buttonLarge.copyWith(
            color: AppColors.primaryViolet,
          ),
          minimumSize: const Size(120, 52),
        ),
      ),

      // ── Text button ────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryViolet,
          textStyle: AppTextStyles.buttonMedium.copyWith(
            color: AppColors.primaryViolet,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      // ── Input / Text field ─────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          borderSide: const BorderSide(color: AppColors.primaryViolet, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: AppTextStyles.label.copyWith(color: AppColors.secondaryText),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.disabledText),
        errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
      ),

      // ── Chips ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.offWhite,
        selectedColor: AppColors.softViolet,
        disabledColor: AppColors.disabledBackground,
        labelStyle: AppTextStyles.labelSmall,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      // ── Bottom navigation ──────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primaryViolet,
        unselectedItemColor: AppColors.secondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTextStyles.labelSmall,
        unselectedLabelStyle: AppTextStyles.labelSmall,
      ),

      // ── Dialog ─────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: AppTextStyles.headingMedium,
        contentTextStyle: AppTextStyles.bodyLarge,
      ),

      // ── Divider ────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // ── Snackbar ───────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.deepInkNavy,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Progress indicator ─────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryViolet,
        linearTrackColor: AppColors.softViolet,
        circularTrackColor: AppColors.softViolet,
      ),

      // ── Tab bar ────────────────────────────────────────────────────────
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primaryViolet,
        unselectedLabelColor: AppColors.secondaryText,
        labelStyle: AppTextStyles.label,
        unselectedLabelStyle: AppTextStyles.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.primaryViolet, width: 2),
        ),
      ),
    );
  }
}
