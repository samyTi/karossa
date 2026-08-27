//lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Palette de couleurs modernisée suivant les principes Material Design 3
/// avec un accent sur l'accessibilité (contrastes WCAG AA) et l'harmonie visuelle
class AppColors {
  const AppColors._();

  // ═══════════════════════════════════════════════════════════════
  // IDENTITÉ DE MARQUE — NUMIDIA OS
  // ═══════════════════════════════════════════════════════════════
  // Palette officielle de la charte graphique Numidia OS :
  //   Navy   #0B132B  (fonds sombres, sidebar, splash)
  //   Blue   #2563EB  (couleur primaire, CTA)
  //   Cyan   #06B6D4  (accent de marque, "OS", dégradés)
  //   Gray   #F3F4F6  (fonds clairs, cartes neutres)

  /// Bleu principal de marque (#2563EB) — identique au logo Numidia OS
  /// Utilisé pour : actions principales, liens, éléments interactifs
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryOpacity = Color(0x1A2563EB); // 10% opacity

  /// Cyan de marque (#06B6D4) — extrémité du dégradé du logo, mot "OS"
  /// Utilisé pour : accents de marque, dégradés, éléments premium/GPS/IA
  static const Color brandCyan = Color(0xFF06B6D4);
  static const Color brandCyanLight = Color(0xFF22D3EE);
  static const Color brandCyanDark = Color(0xFF0891B2);

  /// Navy de marque (#0B132B) — fond sombre du logo Numidia OS
  static const Color brandNavy = Color(0xFF0B132B);
  static const Color brandNavyLight = Color(0xFF16213E);

  /// Gris clair de marque (#F3F4F6) — fonds neutres
  static const Color brandGray = Color(0xFFF3F4F6);

  /// Vert émeraude - Secondaire (#10B981)
  /// Utilisé pour : succès, validation, actions positives
  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color secondaryDark = Color(0xFF059669);

  /// Ambre/Orange - Accent (#F59E0B)
  /// Utilisé pour : mises en garde, éléments importants
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFBBF24);
  static const Color accentDark = Color(0xFFD97706);

  /// Alias pour compatibilité avec l'ancien code
  static const Color amber = accent;

  // ═══════════════════════════════════════════════════════════════
  // COULEURS SÉMANTIQUES (États & Statuts)
  // ═══════════════════════════════════════════════════════════════

  /// Succès - Vert (#10B981)
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF065F46);

  /// Erreur/Danger - Rouge (#EF4444)
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFB91C1C);

  /// Avertissement - Orange (#F59E0B)
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);

  /// Information - Bleu (#3B82F6)
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF2563EB);

  // ═══════════════════════════════════════════════════════════════
  // COULEURS DE STATUT VÉHICULE (Préservées mais modernisées)
  // ═══════════════════════════════════════════════════════════════

  /// Véhicule disponible - Vert émeraude
  static const Color disponible = Color(0xFF10B981);

  /// Véhicule loué - Bleu
  static const Color loue = Color(0xFF3B82F6);

  /// Véhicule vendu - Gris
  static const Color vendu = Color(0xFF6B7280);

  /// Véhicule en réparation - Orange/Rouge
  static const Color reparation = Color(0xFFF97316);

  /// Véhicule réservé - Violet
  static const Color reserve = Color(0xFF8B5CF6);

  /// Retard - Rouge
  static const Color retard = Color(0xFFEF4444);

  // ═══════════════════════════════════════════════════════════════
  // COULEURS DE RÔLE (Préservées mais modernisées)
  // ═══════════════════════════════════════════════════════════════

  /// Admin - Rouge
  static const Color admin = Color(0xFFEF4444);

  /// Gérant - Violet
  static const Color gerant = Color(0xFF8B5CF6);

  /// Propriétaire Showroom - Orange
  static const Color proprietaireShowroom = Color(0xFFF59E0B);

  /// Propriétaire Véhicule - Vert
  static const Color proprietaireVehicule = Color(0xFF10B981);

  // ═══════════════════════════════════════════════════════════════
  // COULEURS NEUTRES (Thème clair)
  // ═══════════════════════════════════════════════════════════════

  /// Fond principal - Gris très léger (#F9FAFB)
  static const Color background = Color(0xFFF9FAFB);

  /// Surface (cartes, conteneurs) - Blanc
  static const Color surface = Colors.white;

  /// Surface secondaire (inputs) - Gris très léger
  static const Color inputFill = Color(0xFFF3F4F6);

  /// Bordures - Gris clair (#E5E7EB)
  static const Color border = Color(0xFFE5E7EB);

  /// Bordure interne - Gris très clair
  static const Color borderLight = Color(0xFFF3F4F6);

  /// Texte principal - Gris très foncé (#111827)
  /// Contraste suffisant pour WCAG AA sur fond clair
  static const Color textPrimary = Color(0xFF111827);

  /// Texte secondaire - Gris moyen (#6B7280)
  static const Color textSecondary = Color(0xFF6B7280);

  /// Texte tertiaire - Gris (#9CA3AF)
  static const Color textTertiary = Color(0xFF9CA3AF);

  /// Texte indicatif (placeholder) - Gris clair (#9CA3AF)
  static const Color textHint = Color(0xFF9CA3AF);

  /// Texte inversé (sur fond sombre) - Blanc
  static const Color textInverse = Colors.white;

  // ═══════════════════════════════════════════════════════════════
  // COULEURS NEUTRES (Thème sombre)
  // ═══════════════════════════════════════════════════════════════

  /// Fond principal sombre - Navy de marque Numidia OS (#0B132B)
  static const Color backgroundDark = Color(0xFF0B132B);

  /// Surface sombre - Navy légèrement plus clair (#111A33)
  static const Color surfaceDark = Color(0xFF111A33);

  /// Surface secondaire sombre - Navy intermédiaire (#16213E)
  static const Color surfaceDarkSecondary = Color(0xFF16213E);

  /// Input sombre - Navy foncé
  static const Color inputFillDark = Color(0xFF17203D);

  /// Bordures sombres - Navy-gris (#243050)
  static const Color borderDark = Color(0xFF243050);

  /// Texte principal sombre - Blanc cassé (#F0F0EE)
  /// Contraste suffisant pour WCAG AA sur fond sombre
  static const Color textPrimaryDark = Color(0xFFF0F0EE);

  /// Texte secondaire sombre - Gris clair (#A0A0B0)
  static const Color textSecondaryDark = Color(0xFFA0A0B0);

  /// Texte tertiaire sombre - Gris moyen (#707080)
  static const Color textTertiaryDark = Color(0xFF707080);

  /// Texte indicatif sombre
  static const Color textHintDark = Color(0xFF707080);

  // ═══════════════════════════════════════════════════════════════
  // COULEURS PRIMAIRES ADAPTÉES AU DARK MODE
  // ═══════════════════════════════════════════════════════════════

  /// Primaire sombre - Plus lumineux pour le contraste
  static const Color primaryDarkMode = Color(0xFF60A5FA);

  /// Cyan de marque sombre - Plus lumineux pour le contraste
  static const Color brandCyanDarkMode = Color(0xFF22D3EE);

  /// Secondaire sombre - Plus lumineux
  static const Color secondaryDarkMode = Color(0xFF34D399);

  /// Accent sombre - Plus lumineux
  static const Color accentDarkMode = Color(0xFFFBBF24);

  // ═══════════════════════════════════════════════════════════════
  // COULEURS SPÉCIALES
  // ═══════════════════════════════════════════════════════════════

  /// Overlay/scaffold (pour modales, drawers)
  static const Color overlay = Color(0x80000000); // 50% noir

  /// Overlay léger
  static const Color overlayLight = Color(0x40000000); // 25% noir

  /// Couleur pour les éléments désactivés
  static const Color disabled = Color(0xFFD1D5DB);

  /// Couleur pour les éléments désactivés (dark mode)
  static const Color disabledDark = Color(0xFF4B5563);

  /// const Divider(séparateurs) - thème clair
  static const Color divider = Color(0xFFE5E7EB);

  /// const Divider(séparateurs) - thème sombre
  static const Color dividerDark = Color(0xFF2A2A4A);

  // ═══════════════════════════════════════════════════════════════
  /// MÉTHODES UTILITAIRES
  // ═══════════════════════════════════════════════════════════════

  /// Retourne la couleur de texte appropriée selon le thème
  static Color textOnPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.white;
  }

  /// Retourne la couleur de surface selon le thème
  static Color getSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? surfaceDark
        : surface;
  }

  /// Retourne la couleur de fond selon le thème
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? backgroundDark
        : background;
  }

  /// Retourne la couleur de texte primaire selon le thème
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimaryDark
        : textPrimary;
  }

  /// Retourne la couleur de texte secondaire selon le thème
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSecondaryDark
        : textSecondary;
  }

  /// Retourne la couleur primaire selon le thème
  static Color getPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? primaryDarkMode
        : primary;
  }

  /// Retourne la couleur de bordure selon le thème
  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? borderDark
        : border;
  }

  /// Applique une opacité à une couleur
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Crée une couleur de surface avec overlay
  static Color surfaceWithOverlay(Color surface, double opacity) {
    return Color.alphaBlend(
      withOpacity(textPrimary, opacity),
      surface,
    );
  }
}