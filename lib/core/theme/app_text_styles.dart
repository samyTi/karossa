import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Système de typographie modernisé basé sur Google Fonts Nunito
/// avec une hiérarchie claire et un contraste accessible (WCAG AA)
class AppTextStyles {
  const AppTextStyles._();

  // ═══════════════════════════════════════════════════════════════
  // POLICE PRINCIPALE
  // ═══════════════════════════════════════════════════════════════

  /// Police principale - Nunito (moderne, lisible, friendly)
  static const String fontFamily = 'Nunito';

  // ═══════════════════════════════════════════════════════════════
  // TITRES (Headings)
  // ═══════════════════════════════════════════════════════════════

  /// Heading 1 - Titres de page (28px, Bold)
  /// Usage : Titres principaux, en-têtes d'écran
  static TextStyle get heading1 => GoogleFonts.nunito(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.5,
      );

  /// Heading 2 - Sous-titres (22px, Bold)
  /// Usage : Sections, titres de cartes
  static TextStyle get heading2 => GoogleFonts.nunito(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
        letterSpacing: -0.3,
      );

  /// Heading 3 - Titres tertiaires (18px, SemiBold)
  /// Usage : Sous-sections, titres de groupes
  static TextStyle get heading3 => GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.35,
        letterSpacing: -0.2,
      );

  /// Heading 4 - Petits titres (16px, SemiBold)
  /// Usage : Titres de cartes, labels importants
  static TextStyle get heading4 => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  // ═══════════════════════════════════════════════════════════════
  // CORPS DE TEXTE (Body)
  // ═══════════════════════════════════════════════════════════════

  /// Body Large - Texte principal (16px, Regular)
  /// Usage : Paragraphes, descriptions
  static TextStyle get bodyLarge => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  /// Body - Texte standard (14px, Regular)
  /// Usage : Contenu principal, listes
  static TextStyle get body => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  /// Body Small - Petit texte (13px, Regular)
  /// Usage : Informations secondaires, métadonnées
  static TextStyle get bodySmall => GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  // ═══════════════════════════════════════════════════════════════
  // TEXTE SECONDAIRE
  // ═══════════════════════════════════════════════════════════════

  /// Body Secondary - Texte secondaire (14px, Regular)
  /// Usage : Sous-titres, descriptions secondaires
  static TextStyle get bodySecondary => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  /// Body Secondary Small (13px, Regular)
  static TextStyle get bodySecondarySmall => GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // ═══════════════════════════════════════════════════════════════
  // LABELS & CAPTIONS
  // ═══════════════════════════════════════════════════════════════

  /// Label - Étiquettes (12px, Medium)
  /// Usage : Labels de champs, catégories, badges
  static TextStyle get label => GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.4,
        letterSpacing: 0.3,
      );

  /// Label Small - Petites étiquettes (11px, Medium)
  static TextStyle get labelSmall => GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.3,
        letterSpacing: 0.5,
      );

  /// Caption - Légendes (11px, Regular)
  /// Usage : Notes, informations légales
  static TextStyle get caption => GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
        height: 1.4,
        letterSpacing: 0.2,
      );

  // ═══════════════════════════════════════════════════════════════
  // TEXTE SPÉCIALISÉ
  // ═══════════════════════════════════════════════════════════════

  /// Money/Prix - Affichage des prix (18px, Bold)
  /// Usage : Prix, montants, valeurs numériques importantes
  static TextStyle get money => GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
        letterSpacing: -0.3,
      );

  /// Money Large - Gros prix (24px, Bold)
  static TextStyle get moneyLarge => GoogleFonts.nunito(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.5,
      );

  /// Money Small - Petits prix (14px, SemiBold)
  static TextStyle get moneySmall => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  /// Badge - Texte pour badges (11px, SemiBold)
  static TextStyle get badge => GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
        letterSpacing: 0.3,
      );

  /// Button - Texte pour boutons (15px, SemiBold)
  static TextStyle get button => GoogleFonts.nunito(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.3,
        letterSpacing: 0.2,
      );

  /// Button Small - Petits boutons (13px, SemiBold)
  static TextStyle get buttonSmall => GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.3,
      );

  // ═══════════════════════════════════════════════════════════════
  // VARIANTS AVEC COULEURS SPÉCIFIQUES
  // ═══════════════════════════════════════════════════════════════

  /// Titre avec couleur primaire
  static TextStyle get heading1Primary => GoogleFonts.nunito(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
        height: 1.2,
        letterSpacing: -0.5,
      );

  /// Texte secondaire avec couleur d'erreur
  static TextStyle get error => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.error,
        height: 1.4,
      );

  /// Texte avec couleur de succès
  static TextStyle get success => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.success,
        height: 1.4,
      );

  /// Texte avec couleur d'avertissement
  static TextStyle get warning => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.warning,
        height: 1.4,
      );

  // ═══════════════════════════════════════════════════════════════
  // MÉTHODES UTILITAIRES
  // ═══════════════════════════════════════════════════════════════

  /// Crée un style de texte avec une couleur personnalisée
  static TextStyle withColor(TextStyle base, Color color) {
    return base.copyWith(color: color);
  }

  /// Crée un style de texte avec un poids personnalisé
  static TextStyle withWeight(TextStyle base, FontWeight weight) {
    return base.copyWith(fontWeight: weight);
  }

  /// Crée un style de texte avec une taille personnalisée
  static TextStyle withSize(TextStyle base, double size) {
    return base.copyWith(fontSize: size);
  }

  /// Style pour texte centré
  static TextStyle centered(TextStyle base) {
    return base.copyWith(
      height: 1.5,
      letterSpacing: 0.2,
    );
  }

  /// Style pour texte en gras
  static TextStyle bold(TextStyle base) {
    return base.copyWith(fontWeight: FontWeight.w700);
  }

  /// Style pour texte avec hauteur de ligne personnalisée
  static TextStyle withHeight(TextStyle base, double height) {
    return base.copyWith(height: height);
  }

  // ═══════════════════════════════════════════════════════════════
  // THÈME TEXT COMPLETE (pour ThemeData)
  // ═══════════════════════════════════════════════════════════════

  /// Retourne le TextTheme complet pour ThemeData
  static TextTheme get textTheme => GoogleFonts.nunitoTextTheme().copyWith(
        displayLarge: GoogleFonts.nunito(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.1,
        ),
        displayMedium: GoogleFonts.nunito(
          fontSize: 45,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.15,
        ),
        displaySmall: GoogleFonts.nunito(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        headlineLarge: GoogleFonts.nunito(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.25,
        ),
        headlineMedium: GoogleFonts.nunito(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.3,
        ),
        headlineSmall: GoogleFonts.nunito(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.3,
        ),
        titleLarge: GoogleFonts.nunito(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.3,
        ),
        titleMedium: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        titleSmall: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.4,
          letterSpacing: 0.1,
        ),
        bodyLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          height: 1.4,
          letterSpacing: 0.1,
        ),
        labelMedium: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          height: 1.4,
          letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          height: 1.4,
          letterSpacing: 0.5,
        ),
      );
}