import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../constants/app_spacing.dart';

/// Design Tokens - Système unifié de tokens pour le thème
/// Ce fichier centralise toutes les valeurs de design pour une cohérence maximale
class ThemeTokens {
  const ThemeTokens._();

  // ═══════════════════════════════════════════════════════════════
  // COLOR SCHEME (Light Mode)
  // ═══════════════════════════════════════════════════════════════

  static ColorScheme get lightColorScheme => ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryLight,
        onSecondaryContainer: AppColors.secondaryDark,
        tertiary: AppColors.accent,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.accentLight,
        onTertiaryContainer: AppColors.accentDark,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorLight,
        onErrorContainer: AppColors.errorDark,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.inputFill,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.borderLight,
      );

  // ═══════════════════════════════════════════════════════════════
  // COLOR SCHEME (Dark Mode)
  // ═══════════════════════════════════════════════════════════════

  static ColorScheme get darkColorScheme => ColorScheme.fromSeed(
        seedColor: AppColors.primaryDarkMode,
        brightness: Brightness.dark,
        primary: AppColors.primaryDarkMode,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primary,
        onPrimaryContainer: AppColors.primaryLight,
        secondary: AppColors.secondaryDarkMode,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondary,
        onSecondaryContainer: AppColors.secondaryLight,
        tertiary: AppColors.accentDarkMode,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.accent,
        onTertiaryContainer: AppColors.accentLight,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorLight,
        onErrorContainer: AppColors.errorDark,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        surfaceContainerHighest: AppColors.surfaceDarkSecondary,
        onSurfaceVariant: AppColors.textSecondaryDark,
        outline: AppColors.borderDark,
        outlineVariant: AppColors.borderDark,
      );

  // ═══════════════════════════════════════════════════════════════
  // SHADOWS (Élévation Material 3)
  // ═══════════════════════════════════════════════════════════════

  /// Niveau 1 - Élévation très subtile (cartes, boutons)
  static List<BoxShadow> get shadow1 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Niveau 2 - Élévation légère
  static List<BoxShadow> get shadow2 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Niveau 3 - Élévation moyenne (cartes survolées)
  static List<BoxShadow> get shadow3 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Niveau 4 - Élévation élevée (modales, FAB)
  static List<BoxShadow> get shadow4 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  /// Niveau 5 - Élévation maximale
  static List<BoxShadow> get shadow5 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Ombre colorée (pour cartes avec couleur primaire)
  static List<BoxShadow> coloredShadow(Color color, {double opacity = 0.15}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // ═══════════════════════════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════════════════════════

  /// Gradient primaire (pour app bar, boutons)
  static LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary,
          AppColors.primaryDark,
        ],
      );

  /// Gradient secondaire
  static LinearGradient get secondaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.secondary,
          AppColors.secondaryDark,
        ],
      );

  /// Gradient accent
  static LinearGradient get accentGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.accent,
          AppColors.accentDark,
        ],
      );

  /// Gradient doux (pour cartes, backgrounds)
  static LinearGradient subtleGradient(Color color) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.1),
          color.withValues(alpha: 0.05),
        ],
      );

  /// Gradient sombre (pour dark mode)
  static LinearGradient get darkGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surfaceDark,
          AppColors.surfaceDarkSecondary,
        ],
      );

  // ═══════════════════════════════════════════════════════════════
  // BORDER STYLES
  // ═══════════════════════════════════════════════════════════════

  /// Bordure subtile (pour cartes)
  static BorderSide get subtleBorder => const BorderSide(
        color: AppColors.border,
        width: 0.5,
      );

  /// Bordure standard
  static BorderSide get standardBorder => const BorderSide(
        color: AppColors.border,
      );

  /// Bordure focus (pour inputs actifs)
  static BorderSide focusBorder(Color color) => BorderSide(
        color: color,
        width: 2,
      );

  /// Bordure d'erreur
  static BorderSide get errorBorder => const BorderSide(
        color: AppColors.error,
        width: 1.5,
      );

  // ═══════════════════════════════════════════════════════════════
  // SHAPE THEMES
  // ═══════════════════════════════════════════════════════════════

  /// Forme pour boutons
  static RoundedRectangleBorder get buttonShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      );

  /// Forme pour cartes
  static RoundedRectangleBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: subtleBorder,
      );

  /// Forme pour inputs
  static RoundedRectangleBorder get inputShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: subtleBorder,
      );

  /// Forme pour badges
  static RoundedRectangleBorder get badgeShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      );

  // ═══════════════════════════════════════════════════════════════
  // ANIMATION CURVES
  // ═══════════════════════════════════════════════════════════════

  /// Courbe d'animation standard (smooth)
  static const Curve standardCurve = Curves.easeInOut;

  /// Courbe d'animation pour entrée (décélération)
  static const Curve decelerateCurve = Curves.easeOutCubic;

  /// Courbe d'animation pour sortie (accélération)
  static const Curve accelerateCurve = Curves.easeInCubic;

  /// Courbe d'animation élastique (rebond)
  static const Curve elasticCurve = Curves.elasticOut;

  /// Courbe d'animation fluide (Material 3)
  static const Curve smoothCurve = Curves.easeInOutCubic;

  // ═══════════════════════════════════════════════════════════════
  // ANIMATION DURATIONS
  // ═══════════════════════════════════════════════════════════════

  static Duration get fastDuration => AppSpacing.durationFast;
  static Duration get normalDuration => AppSpacing.durationNormal;
  static Duration get mediumDuration => AppSpacing.durationMedium;
  static Duration get slowDuration => AppSpacing.durationSlow;

  // ═══════════════════════════════════════════════════════════════
  // RESPONSIVE BREAKPOINTS
  // ═══════════════════════════════════════════════════════════════

  /// Téléphone portrait
  static const double phoneBreakpoint = 0;

  /// Téléphone paysage / Petite tablette
  static const double smallTabletBreakpoint = 600;

  /// Tablette
  static const double tabletBreakpoint = 800;

  /// Desktop
  static const double desktopBreakpoint = 1200;

  /// Détermine si on est sur mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < smallTabletBreakpoint;
  }

  /// Détermine si on est sur tablette
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= smallTabletBreakpoint && width < desktopBreakpoint;
  }

  /// Détermine si on est sur desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  // ═══════════════════════════════════════════════════════════════
  // ACCESSIBILITY
  // ═══════════════════════════════════════════════════════════════

  /// Taille minimale pour les éléments interactifs (WCAG)
  static const double minTouchTarget = 48.0;

  /// Contraste minimum pour texte normal (WCAG AA)
  static const double minContrastRatio = 4.5;

  /// Contraste minimum pour gros texte (WCAG AA)
  static const double minContrastRatioLargeText = 3.0;

  /// Vérifie si deux couleurs ont un contraste suffisant
  static bool hasSufficientContrast(Color foreground, Color background) {
    final luminance1 = _relativeLuminance(foreground);
    final luminance2 = _relativeLuminance(background);
    final lighter = luminance1 > luminance2 ? luminance1 : luminance2;
    final darker = luminance1 > luminance2 ? luminance2 : luminance1;
    final ratio = (lighter + 0.05) / (darker + 0.05);
    return ratio >= minContrastRatio;
  }

  static double _relativeLuminance(Color color) {
    final r = _sRGB((color.r * 255.0).round().clamp(0, 255));
    final g = _sRGB((color.g * 255.0).round().clamp(0, 255));
    final b = _sRGB((color.b * 255.0).round().clamp(0, 255));
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double _sRGB(int component) {
    final value = component / 255.0;
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }
}