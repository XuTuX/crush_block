import 'package:link_your_area/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color ink = Color(0xFF161A23);
  static const Color textMuted = Color(0xA8161A23);
  static const Color textSubtle = Color(0x7A161A23);

  static const Color background = Color(0xFFF6F7FB);
  static const Color backgroundSoft = Color(0xFFEEF2F8);
  static const Color backgroundWash = Color(0xFFFBFCFE);
  static const Color surface = Color(0xFFF2F4FA);
  static const Color surfaceMuted = Color(0xFFF8F9FC);
  static const Color borderSoft = Color(0xFFDCE2F0);
  static const Color overlay = Color(0x8C161A23);

  static const Color primary = Color(0xFF3563F0);
  static const Color primarySoft = Color(0xFFE6ECFF);
  static const Color secondary = Color(0xFF6FA7B7);
  static const Color secondarySoft = Color(0xFFE6F1F4);
  static const Color success = Color(0xFF61A89E);
  static const Color successSoft = Color(0xFFE6F3F0);
  static const Color danger = Color(0xFFE08A63);
  static const Color dangerSoft = Color(0xFFF8EBE4);
  static const Color onPrimary = backgroundWash;

  static const Color accentPeach = danger;
  static const Color accentSage = success;
  static const Color accentGold = Color(0xFFD3A36E);
  static const Color accentCoral = danger;
  static const Color accentApricot = danger;
  static const Color accentLemon = Color(0xFFF1E5D8);
  static const Color accentMint = Color(0xFFBCD8E1);
  static const Color accentSky = primary;

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundWash, backgroundSoft],
  );
}

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

class AppRadius {
  AppRadius._();

  static const double sm = 14;
  static const double md = 20;
  static const double lg = 20;
  static const double xl = 20;
  static const double round = 999;
}

class AppStroke {
  AppStroke._();

  static const double soft = 1;
  static const double strong = 1.5;
}

class AppShadows {
  AppShadows._();

  static final List<BoxShadow> softCard = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.045),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> liftedCard = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.06),
      blurRadius: 26,
      offset: const Offset(0, 12),
    ),
  ];
}

class AppDecorations {
  AppDecorations._();

  static BoxDecoration card({
    Color color = AppColors.surface,
    double radius = AppRadius.lg,
    bool outlined = false,
    bool lifted = false,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ??
            (outlined
                ? AppColors.ink.withValues(alpha: 0.14)
                : AppColors.borderSoft),
        width: outlined ? AppStroke.strong : AppStroke.soft,
      ),
      boxShadow: lifted ? AppShadows.liftedCard : AppShadows.softCard,
    );
  }

  static BoxDecoration pill({
    Color color = AppColors.surfaceMuted,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    );
  }

  static BoxDecoration playfulCard({
    Color color = AppColors.surface,
  }) {
    return card(
      color: color,
      radius: AppRadius.md,
      outlined: true,
      lifted: true,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.danger,
      onError: AppColors.onPrimary,
    );

    final baseTextTheme = GoogleFonts.notoSansKrTextTheme(
      const TextTheme(
        displayLarge: AppTypography.display,
        headlineMedium: AppTypography.headline,
        titleLarge: AppTypography.title,
        titleMedium: AppTypography.subtitle,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.bodySmall,
        labelLarge: AppTypography.button,
        labelMedium: AppTypography.label,
        bodySmall: AppTypography.caption,
      ),
    );

    return ThemeData(
      useMaterial3: false,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerColor: AppColors.borderSoft,
      textTheme: baseTextTheme,
      iconTheme: const IconThemeData(
        color: AppColors.ink,
        size: 20,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.textSubtle,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(
            color: AppColors.borderSoft,
            width: AppStroke.soft,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: AppStroke.strong,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(
            color: AppColors.danger,
            width: AppStroke.strong,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(
            color: AppColors.danger,
            width: AppStroke.strong,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          disabledForegroundColor: AppColors.onPrimary.withValues(alpha: 0.7),
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTypography.button.copyWith(color: AppColors.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.textSubtle,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: const BorderSide(
            color: AppColors.borderSoft,
            width: AppStroke.soft,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTypography.button,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return AppColors.backgroundWash;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderSoft;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle:
            AppTypography.bodySmall.copyWith(color: AppColors.onPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
