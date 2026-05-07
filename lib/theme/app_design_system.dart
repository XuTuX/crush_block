import 'package:crush_block/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color ink = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0x8A1A1A1A);
  static const Color textSubtle = Color(0x591A1A1A);

  static const Color background = Color(0xFFF8F9FA);
  static const Color backgroundSoft = Color(0xFFF1F5F9);
  static const Color backgroundWash = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F4F6);
  static const Color borderSoft = Color(0x1F1A1A1A);
  static const Color overlay = Color(0xD91A1A1A);

  static const Color primary = Color(0xFF0095FF);
  static const Color primarySoft = Color(0xFFEFF6FF);
  static const Color secondary = Color(0xFF2563EB);
  static const Color secondarySoft = Color(0xFFE0F2FE);
  static const Color reward = Color(0xFFF59E0B);
  static const Color rewardSoft = Color(0xFFFFFBEB);
  static const Color success = Color(0xFF00D47C);
  static const Color successSoft = Color(0xFFE9FFF4);
  static const Color warning = Color(0xFFF97316);
  static const Color warningSoft = Color(0xFFFFF7ED);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerStrong = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEF2F2);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color rankFirst = Color(0xFFFB7185);
  static const Color rankSecond = Color(0xFFFB923C);
  static const Color rankThird = Color(0xFFFBBF24);
  static const Color participation = Color(0xFFE2E8F0);

  static const Color tileCoral = Color(0xFFFF4D4D);
  static const Color tileAmber = Color(0xFFFFB300);
  static const Color tileMint = Color(0xFF00D47C);
  static const Color tileAzure = Color(0xFF0095FF);
  static const Color tileViolet = Color(0xFF8F00FF);

  static const List<Color> areaPalette = [
    Color(0xFFFF7F7F),
    Color(0xFFFFB27A),
    Color(0xFFF9D86D),
    Color(0xFFA3D9A5),
    Color(0xFFA3CFFF),
    Color(0xFFC4A3FF),
  ];

  static const Color accentPeach = rankFirst;
  static const Color accentSage = success;
  static const Color accentGold = reward;
  static const Color accentCoral = tileCoral;
  static const Color accentApricot = warning;
  static const Color accentLemon = rewardSoft;
  static const Color accentMint = successSoft;
  static const Color accentSky = primary;

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [background, backgroundWash],
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

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double round = 999;
}

class AppStroke {
  AppStroke._();

  static const double soft = 1.5;
  static const double strong = 2.5;
  static const double heavy = 3;
}

class AppShadows {
  AppShadows._();

  static final List<BoxShadow> softCard = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.95),
      blurRadius: 0,
      offset: const Offset(3, 3),
    ),
  ];

  static final List<BoxShadow> liftedCard = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.95),
      blurRadius: 0,
      offset: const Offset(5, 5),
    ),
  ];

  static List<BoxShadow> hard({double offset = 3}) {
    return [
      BoxShadow(
        color: AppColors.ink.withValues(alpha: 0.95),
        blurRadius: 0,
        offset: Offset(offset, offset),
      ),
    ];
  }
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
        color: borderColor ?? AppColors.ink,
        width: AppStroke.strong,
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
      border: Border.all(color: AppColors.ink, width: AppStroke.soft),
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
        fillColor: AppColors.surface,
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
            color: AppColors.ink,
            width: AppStroke.strong,
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
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(
              color: AppColors.ink,
              width: AppStroke.strong,
            ),
          ),
          textStyle: AppTypography.button.copyWith(color: AppColors.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.textSubtle,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: const BorderSide(
            color: AppColors.ink,
            width: AppStroke.strong,
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
          minimumSize: const Size(0, 56),
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
