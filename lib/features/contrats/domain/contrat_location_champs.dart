// lib/features/contrats/domain/contrat_location_champs.dart
//
// Registre des champs affichables sur le contrat de location, et de leurs
// valeurs par défaut. Sert à la fois de source de vérité pour l'écran de
// sélection (contrat_location_champs_screen.dart) et pour les générateurs
// PDF (contrat_location_pdf_generator.dart / _classique_pdf_generator.dart),
// qui ne doivent jamais connaître autre chose qu'un Set<String> de clés
// activées.
//
// Persisté dans showrooms.contrat_location_champs (jsonb), sous la forme
// {"cle": true/false, ...}. Toute clé absente retombe sur [defaultValue].

class ContratLocationChampDef {
  final String key;
  final String label;
  final String section;
  final bool defaultValue;

  /// Si renseigné, ce champ n'a d'effet que sur ce template précis
  /// ('standard' ou 'classique'). Si null, il s'applique aux deux quand le
  /// générateur concerné le supporte.
  final String? templateScope;

  const ContratLocationChampDef({
    required this.key,
    required this.label,
    required this.section,
    required this.defaultValue,
    this.templateScope,
  });
}

class ContratLocationChamps {
  ContratLocationChamps._();

  static const String sectionLocataire = 'Locataire';
  static const String sectionLoueur = 'Loueur / Agence';
  static const String sectionVehicule = 'Véhicule';
  static const String sectionLocation = 'Location';
  static const String sectionDivers = 'Divers';

  /// Registre complet, dans l'ordre d'affichage voulu dans l'écran de réglages.
  static const List<ContratLocationChampDef> registry = [
    // ── Locataire ──────────────────────────────────────────────
    ContratLocationChampDef(
      key: 'locataire_adresse',
      label: 'Adresse du locataire',
      section: sectionLocataire,
      defaultValue: true,
    ),
    ContratLocationChampDef(
      key: 'locataire_naissance',
      label: 'Date de naissance',
      section: sectionLocataire,
      defaultValue: true,
    ),
    ContratLocationChampDef(
      key: 'locataire_permis',
      label: 'N° et date de permis',
      section: sectionLocataire,
      defaultValue: true,
    ),
    ContratLocationChampDef(
      key: 'locataire_email',
      label: 'Email du locataire',
      section: sectionLocataire,
      defaultValue: true,
      templateScope: 'classique',
    ),
    ContratLocationChampDef(
      key: 'locataire_conducteur2',
      label: '2ème conducteur',
      section: sectionLocataire,
      defaultValue: true,
    ),

    // ── Loueur / Agence ────────────────────────────────────────
    ContratLocationChampDef(
      key: 'agence_rc',
      label: 'Registre de commerce (R.C)',
      section: sectionLoueur,
      defaultValue: true,
    ),
    ContratLocationChampDef(
      key: 'agence_email',
      label: 'Email agence',
      section: sectionLoueur,
      defaultValue: true,
    ),
    ContratLocationChampDef(
      key: 'agence_art',
      label: 'N° ART',
      section: sectionLoueur,
      defaultValue: false,
      templateScope: 'classique',
    ),
    ContratLocationChampDef(
      key: 'agent',
      label: 'Agent en charge',
      section: sectionLoueur,
      defaultValue: false,
      templateScope: 'classique',
    ),

    // ── Véhicule ───────────────────────────────────────────────
    ContratLocationChampDef(
      key: 'vehicule_couleur',
      label: 'Couleur',
      section: sectionVehicule,
      defaultValue: true,
    ),
    ContratLocationChampDef(
      key: 'vehicule_carburant',
      label: 'Type de carburant',
      section: sectionVehicule,
      defaultValue: true,
    ),
    ContratLocationChampDef(
      key: 'vehicule_boite',
      label: 'Boîte de vitesse',
      section: sectionVehicule,
      defaultValue: true,
      templateScope: 'classique',
    ),
    ContratLocationChampDef(
      key: 'vehicule_assurance',
      label: 'Assurance véhicule',
      section: sectionVehicule,
      defaultValue: true,
      templateScope: 'standard',
    ),
    ContratLocationChampDef(
      key: 'vehicule_code_radio',
      label: 'Code radio',
      section: sectionVehicule,
      defaultValue: true,
      templateScope: 'standard',
    ),

    // ── Location ───────────────────────────────────────────────
    ContratLocationChampDef(
      key: 'location_lieu',
      label: 'Lieu de départ / retour',
      section: sectionLocation,
      defaultValue: true,
      templateScope: 'classique',
    ),
    ContratLocationChampDef(
      key: 'location_mode_paiement',
      label: 'Mode de paiement',
      section: sectionLocation,
      defaultValue: true,
      templateScope: 'classique',
    ),
    ContratLocationChampDef(
      key: 'location_options',
      label: 'Options souscrites',
      section: sectionLocation,
      defaultValue: true,
      templateScope: 'classique',
    ),
    ContratLocationChampDef(
      key: 'location_caution',
      label: 'Caution',
      section: sectionLocation,
      defaultValue: true,
    ),
    ContratLocationChampDef(
      key: 'location_montant_total',
      label: 'Somme à payer (prix total)',
      section: sectionLocation,
      defaultValue: true,
      templateScope: 'classique',
    ),

    // ── Divers ─────────────────────────────────────────────────
    ContratLocationChampDef(
      key: 'km_carburant_jauge',
      label: 'Jauge carburant (graphique)',
      section: sectionDivers,
      defaultValue: true,
      templateScope: 'classique',
    ),
    ContratLocationChampDef(
      key: 'remarques',
      label: 'Remarques / observations',
      section: sectionDivers,
      defaultValue: true,
    ),
  ];

  /// Valeurs par défaut (clé → activé), utilisées quand le showroom n'a
  /// encore rien configuré, ou pour compléter une config partielle.
  static Map<String, bool> get defaults => {
        for (final c in registry) c.key: c.defaultValue,
      };

  /// Fusionne la config sauvegardée avec les défauts (rétrocompatible :
  /// un nouveau champ ajouté au registre plus tard aura automatiquement
  /// sa valeur par défaut tant que le showroom ne l'a pas modifié).
  static Map<String, bool> resolve(Map<String, dynamic>? saved) {
    final result = defaults;
    if (saved != null) {
      for (final entry in saved.entries) {
        if (result.containsKey(entry.key) && entry.value is bool) {
          result[entry.key] = entry.value as bool;
        }
      }
    }
    return result;
  }

  /// Convertit une Map résolue en Set des clés activées, pratique côté
  /// générateur PDF (`if (champs.contains('xxx')) ...`).
  static Set<String> toActiveSet(Map<String, bool> resolved) =>
      resolved.entries.where((e) => e.value).map((e) => e.key).toSet();

  static List<ContratLocationChampDef> forSection(String section) =>
      registry.where((c) => c.section == section).toList();

  static const List<String> sectionsOrder = [
    sectionLocataire,
    sectionLoueur,
    sectionVehicule,
    sectionLocation,
    sectionDivers,
  ];
}
