import 'package:flutter/material.dart';

/// Système d'espacements cohérent basé sur une grille de 8px
/// Cette approche assure une cohérence visuelle dans toute l'application
class AppSpacing {
  const AppSpacing._();

  // ═══════════════════════════════════════════════════════════════
  // ESPACEMENTS PRINCIPAUX (Grid 8px)
  // ═══════════════════════════════════════════════════════════════

  /// 2px - Micro espacements (icônes inline, badges)
  static const double xxxs = 2.0;

  /// 4px - Très petit espacement
  static const double xxs = 4.0;

  /// 8px - Petit espacement (entre éléments liés)
  static const double xs = 8.0;

  /// 12px - Espacement moyen-petit
  static const double sm = 12.0;

  /// 16px - Espacement standard (padding de carte, etc.)
  static const double md = 16.0;

  /// 20px - Espacement moyen-grand
  static const double lg = 20.0;

  /// 24px - Grand espacement (sections)
  static const double xl = 24.0;

  /// 32px - Très grand espacement
  static const double xxl = 32.0;

  /// 48px - Espacement extra-large
  static const double xxxl = 48.0;

  /// 64px - Espacement massif
  static const double huge = 64.0;

  // ═══════════════════════════════════════════════════════════════
  // ESPACEMENTS SPÉCIFIQUES
  // ═══════════════════════════════════════════════════════════════

  /// Espacement horizontal standard pour les écrans
  static const double screenHorizontal = 16.0;

  /// Espacement vertical standard entre sections
  static const double sectionSpacing = 24.0;

  /// Espacement entre éléments d'une liste
  static const double listItemSpacing = 12.0;

  /// Espacement entre un label et son input
  static const double labelInputSpacing = 8.0;

  /// Espacement entre deux boutons côte à côte
  static const double buttonSpacing = 12.0;

  // ═══════════════════════════════════════════════════════════════
  // PADDINGS PRÉDÉFINIS
  // ═══════════════════════════════════════════════════════════════

  /// Padding standard pour les cartes
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);

  /// Padding pour les boutons
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 20.0,
    vertical: 14.0,
  );

  /// Padding pour les inputs
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 14.0,
    vertical: 12.0,
  );

  /// Padding d'écran standard
  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);

  /// Padding horizontal uniquement
  static const EdgeInsets horizontalPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
  );

  /// Padding vertical uniquement
  static const EdgeInsets verticalPadding = EdgeInsets.symmetric(
    vertical: 16.0,
  );

  // ═══════════════════════════════════════════════════════════════
  // RAYONS (BORDER RADIUS)
  // ═══════════════════════════════════════════════════════════════

  /// 4px - Très petit rayon (badges, chips)
  static const double radiusXs = 4.0;

  /// 8px - Petit rayon (boutons secondaires)
  static const double radiusSm = 8.0;

  /// 12px - Rayon standard (boutons, inputs)
  static const double radiusMd = 12.0;

  /// 16px - Grand rayon (cartes)
  static const double radiusLg = 16.0;

  /// 20px - Très grand rayon
  static const double radiusXl = 20.0;

  /// 24px - Rayon extra-large (modales, bottom sheets)
  static const double radiusXxl = 24.0;

  /// 50% - Cercle parfait
  static const double radiusFull = 9999.0;

  // ═══════════════════════════════════════════════════════════════
  // FORMES PRÉDÉFINIES
  // ═══════════════════════════════════════════════════════════════

  /// Border radius pour les boutons
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(radiusMd));

  /// Border radius pour les cartes
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(radiusLg));

  /// Border radius pour les inputs
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(radiusMd));

  /// Border radius pour les badges
  static const BorderRadius badgeRadius = BorderRadius.all(Radius.circular(radiusXs));

  /// Border radius pour les avatars
  static BorderRadius avatarRadius(double size) => BorderRadius.all(Radius.circular(size / 2));

  // ═══════════════════════════════════════════════════════════════
  // DURÉES D'ANIMATION
  // ═══════════════════════════════════════════════════════════════

  /// 100ms - Animation très rapide
  static const Duration durationFast = Duration(milliseconds: 100);

  /// 200ms - Animation rapide (micro-interactions)
  static const Duration durationNormal = Duration(milliseconds: 200);

  /// 300ms - Animation standard
  static const Duration durationMedium = Duration(milliseconds: 300);

  /// 500ms - Animation lente (transitions de page)
  static const Duration durationSlow = Duration(milliseconds: 500);

  // ═══════════════════════════════════════════════════════════════
  // TAILLES D'ÉLÉMENTS
  // ═══════════════════════════════════════════════════════════════

  /// Hauteur standard d'un bouton
  static const double buttonHeight = 48.0;

  /// Hauteur d'un petit bouton
  static const double buttonHeightSm = 40.0;

  /// Hauteur d'un input
  static const double inputHeight = 56.0;

  /// Taille d'un avatar standard
  static const double avatarSize = 40.0;

  /// Taille d'un grand avatar
  static const double avatarSizeLg = 56.0;

  /// Taille d'un petit avatar
  static const double avatarSizeSm = 32.0;

  /// Hauteur d'une app bar
  static const double appBarHeight = 56.0;

  /// Hauteur d'une navigation bar
  static const double navigationBarHeight = 64.0;
}