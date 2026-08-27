// lib/features/locations/domain/location_model.dart
import 'dart:convert';
import '../../vehicules/domain/etat_carrosserie_model.dart';

class LocationPaiement {
  final String id;
  final String locationId;
  final double montant;
  final DateTime datePaiement;
  final String? mode;
  final String? notes;

  const LocationPaiement({
    required this.id,
    required this.locationId,
    required this.montant,
    required this.datePaiement,
    this.mode,
    this.notes,
  });

  factory LocationPaiement.fromJson(Map<String, dynamic> json) =>
    LocationPaiement(
      id: json['id'] as String? ?? '',
      locationId: json['location_id'] as String? ?? '',
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      datePaiement: json['date_paiement'] != null
        ? DateTime.parse(json['date_paiement'] as String)
        : DateTime.now(),
      mode: json['mode'] as String?,
      notes: json['notes'] as String?,
    );

  Map<String, dynamic> toJson() => {
        'location_id':   locationId,
        'montant':       montant,
        'date_paiement': datePaiement.toIso8601String().substring(0, 10),
        'mode':          mode,
        'notes':         notes,
      };

  LocationPaiement copyWith({
    double? montant,
    DateTime? datePaiement,
    String? mode,
    String? notes,
  }) =>
      LocationPaiement(
        id:           id,
        locationId:   locationId,
        montant:      montant ?? this.montant,
        datePaiement: datePaiement ?? this.datePaiement,
        mode:         mode ?? this.mode,
        notes:        notes ?? this.notes,
      );
}

// ignore: constant_identifier_names
enum LocationStatut { en_cours, termine, annule, retard }

// ─────────────────────────────────────────────────────────────────────────────
// NOUVEAU : Interruption temporaire de location
// ─────────────────────────────────────────────────────────────────────────────

enum MotifInterruption {
  reparation,
  vidange,
  assurance,
  controle_technique, // ignore: constant_identifier_names
  autre;

  String get label => switch (this) {
        MotifInterruption.reparation          => 'Réparation',
        MotifInterruption.vidange             => 'Vidange',
        MotifInterruption.assurance           => 'Assurance',
        MotifInterruption.controle_technique  => 'Contrôle technique',
        MotifInterruption.autre               => 'Autre',
      };

  String get icon => switch (this) {
        MotifInterruption.reparation          => '🔧',
        MotifInterruption.vidange             => '🛢️',
        MotifInterruption.assurance           => '📋',
        MotifInterruption.controle_technique  => '✅',
        MotifInterruption.autre               => '📌',
      };
}

class LocationInterruption {
  final String id;
  final String locationId;
  final DateTime dateDebut;
  final DateTime? dateFin;   // null = interruption en cours
  final MotifInterruption motif;
  final String? notes;
  final String? reparationId;
  final DateTime createdAt;

  const LocationInterruption({
    required this.id,
    required this.locationId,
    required this.dateDebut,
    this.dateFin,
    required this.motif,
    this.notes,
    this.reparationId,
    required this.createdAt,
  });

  /// Interruption encore en cours (véhicule pas encore restitué au client)
  bool get enCours => dateFin == null;

  /// Nombre de jours d'interruption (0 si en cours → non comptabilisés)
  int get nbJours {
    if (dateFin == null) return 0;
    return dateFin!.difference(dateDebut).inDays;
  }

  factory LocationInterruption.fromJson(Map<String, dynamic> json) =>
      LocationInterruption(
        id:           json['id'] as String? ?? '',
        locationId:   json['location_id'] as String? ?? '',
        dateDebut:    DateTime.parse(json['date_debut'] as String),
        dateFin:      json['date_fin'] != null
                          ? DateTime.parse(json['date_fin'] as String)
                          : null,
        motif:        MotifInterruption.values.firstWhere(
                          (m) => m.name == json['motif'],
                          orElse: () => MotifInterruption.autre),
        notes:        json['notes'] as String?,
        reparationId: json['reparation_id'] as String?,
        createdAt:    json['created_at'] != null
                          ? DateTime.parse(json['created_at'] as String)
                          : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'location_id':  locationId,
        'date_debut':   dateDebut.toIso8601String().substring(0, 10),
        'date_fin':     dateFin?.toIso8601String().substring(0, 10),
        'motif':        motif.name,
        'notes':        notes,
        'reparation_id': reparationId,
      };

  LocationInterruption copyWith({
    DateTime? dateFin,
    String? notes,
  }) =>
      LocationInterruption(
        id:           id,
        locationId:   locationId,
        dateDebut:    dateDebut,
        dateFin:      dateFin ?? this.dateFin,
        motif:        motif,
        notes:        notes ?? this.notes,
        reparationId: reparationId,
        createdAt:    createdAt,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class LocationRepartition {
  final String beneficiaireId;
  final String beneficiaireNom;
  final String typePart;
  final double pourcentage;
  final double montant;

  const LocationRepartition({
    required this.beneficiaireId,
    required this.beneficiaireNom,
    required this.typePart,
    required this.pourcentage,
    required this.montant,
  });

  factory LocationRepartition.fromJson(Map<String, dynamic> json) =>
      LocationRepartition(
        beneficiaireId:  json['beneficiaire_id'] as String? ?? '',
        beneficiaireNom: (json['profiles']?['prenom'] as String?) ?? '',
        typePart:        json['type_part'] as String? ?? '',
        pourcentage:     (json['pourcentage'] as num? ?? 0).toDouble(),
        montant:         (json['montant'] as num? ?? 0).toDouble(),
      );
}

class Location {
  final String id;
  final String vehiculeId;
  final String? vehiculeNom;
  final String clientId;
  final String? clientNom;
  final String? clientTel;
  final DateTime dateDebut;
  final DateTime? dateFinPrevue;
  final DateTime? dateFinReelle;
  final int kmDepart;
  final int? kmRetour;
  final double prixJour;
  final int nbJours;
  final double? montantBrut;
  final double caution;
  final double retenueCaution;
  final LocationStatut statut;
  final String? notesDepart;
  final String? notesRetour;
  final String? etatCarrosserieDepart;
  final String? etatCarrosserieRetour;

  // ── Heures de départ / retour ────────────────────────────────────────────
  final String? heureDepart;
  final String? heureRetour;

  // ── 2ème conducteur (optionnel) ──────────────────────────────────────────
  final String? conducteur2Nom;
  final String? conducteur2Prenom;
  final String? conducteur2Tel;
  final String? conducteur2NumPermis;
  final String? conducteur2PermisDate;
  final String? conducteur2DateNaissance;

  final List<LocationRepartition> repartitions;
  final List<LocationPaiement> paiements;

  // ── NOUVEAU ──────────────────────────────────────────────────────────────
  final List<LocationInterruption> interruptions;

  final DateTime createdAt;

  const Location({
    required this.id,
    required this.vehiculeId,
    this.vehiculeNom,
    required this.clientId,
    this.clientNom,
    this.clientTel,
    required this.dateDebut,
    this.dateFinPrevue,
    this.dateFinReelle,
    required this.kmDepart,
    this.kmRetour,
    required this.prixJour,
    required this.nbJours,
    this.montantBrut,
    required this.caution,
    this.retenueCaution = 0,
    required this.statut,
    this.notesDepart,
    this.notesRetour,
    this.etatCarrosserieDepart,
    this.etatCarrosserieRetour,
    this.heureDepart,
    this.heureRetour,
    this.conducteur2Nom,
    this.conducteur2Prenom,
    this.conducteur2Tel,
    this.conducteur2NumPermis,
    this.conducteur2PermisDate,
    this.conducteur2DateNaissance,
    this.repartitions = const [],
    this.paiements = const [],
    this.interruptions = const [],   // ← NOUVEAU
    required this.createdAt,
  });

  bool get isContratOuvert => dateFinPrevue == null;

  bool get hasConducteur2 =>
      conducteur2Nom != null && (conducteur2Nom?.isNotEmpty ?? false);

  bool get isOverdue =>
      !isContratOuvert &&
      statut == LocationStatut.en_cours &&
      DateTime.now().isAfter(dateFinPrevue!);

  int get joursRetard =>
      isOverdue ? DateTime.now().difference(dateFinPrevue!).inDays : 0;

  // ── Gestion des interruptions ─────────────────────────────────────────────

  /// Somme des jours d'interruption terminées (véhicule restitué au client)
  int get joursInterruption =>
      interruptions.fold(0, (sum, i) => sum + i.nbJours);

  /// Y a-t-il une interruption active en ce moment ?
  bool get hasInterruptionActive =>
      interruptions.any((i) => i.enCours);

  /// L'interruption active courante (null si aucune)
  LocationInterruption? get interruptionActive =>
      interruptions.cast<LocationInterruption?>().firstWhere(
            (i) => i!.enCours,
            orElse: () => null,
          );

  // ── Calculs de durée effectifs ─────────────────────────────────────────────

  int get joursActuels {
    if (!isContratOuvert) return nbJours;
    final fin = dateFinReelle ?? DateTime.now();
    return fin.difference(dateDebut).inDays.clamp(1, 9999);
  }

  /// Jours facturables = jours totaux − jours d'interruption terminées
  int get joursFacturables => (joursActuels - joursInterruption).clamp(0, 9999);

  /// Montant calculé sur les jours effectifs (hors interruptions)
  double get montantCalcule => prixJour * joursFacturables;

  double get totalPaiements =>
      paiements.fold(0.0, (s, p) => s + p.montant);

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        id: json['id'] as String? ?? '',
        vehiculeId: json['vehicule_id'] as String? ?? '',
        vehiculeNom: json['vehicules'] != null
            ? '${json['vehicules']['marque']} ${json['vehicules']['modele']}'
            : null,
        clientId: json['client_id'] as String? ?? '',
        clientNom: json['clients'] != null
            ? '${json['clients']['prenom']} ${json['clients']['nom']}'
            : null,
        clientTel: json['clients']?['telephone'] as String?,
        dateDebut: json['date_debut'] != null
          ? DateTime.parse(json['date_debut'] as String)
          : DateTime.now(),
        dateFinPrevue: json['date_fin_prevue'] != null
            ? DateTime.parse(json['date_fin_prevue'])
            : null,
        dateFinReelle: json['date_fin_reelle'] != null
            ? DateTime.parse(json['date_fin_reelle'])
            : null,
        kmDepart:      json['km_depart'] ?? 0,
        kmRetour:      json['km_retour'],
        prixJour:      (json['prix_jour'] as num).toDouble(),
        nbJours:       json['nb_jours'] ?? 1,
        montantBrut:   json['montant_brut'] != null
            ? (json['montant_brut'] as num).toDouble()
            : null,
        caution:       (json['caution'] as num? ?? 0).toDouble(),
        retenueCaution: (json['retenue_caution'] as num? ?? 0).toDouble(),
        statut: LocationStatut.values.firstWhere(
            (s) => s.name == json['statut'],
            orElse: () => LocationStatut.en_cours),
        notesDepart:  json['notes_depart'] as String?,
        notesRetour:  json['notes_retour'] as String?,
        // 🔧 Les deux champs utilisent désormais le même parseur défensif
        // (EtatCarrosserie.fromDynamic), qui accepte indifféremment une
        // Map (jsonb déjà décodé par Supabase) ou une String JSON, puis on
        // re-sérialise en String pour le stockage local du modèle. Avant
        // ce correctif, seul le champ "depart" gérait le cas Map — le
        // champ "retour" faisait un cast direct `as String?` qui échouait
        // silencieusement dès que Supabase renvoyait un Map, ce qui
        // vidait l'état carrosserie retour à chaque rechargement/édition.
        // On garde `null` tel quel (≠ "aucun dommage constaté") pour ne
        // pas casser la logique qui teste `!= null` pour savoir si un
        // état retour a déjà été saisi (cf. `_hasEtatRetour` côté écran).
        etatCarrosserieDepart: json['etat_carrosserie_depart'] == null
            ? null
            : EtatCarrosserie.fromDynamic(json['etat_carrosserie_depart'])
                .toJsonString(),
        etatCarrosserieRetour: json['etat_carrosserie_retour'] == null
            ? null
            : EtatCarrosserie.fromDynamic(json['etat_carrosserie_retour'])
                .toJsonString(),
        heureDepart: json['heure_depart'] as String?,
        heureRetour: json['heure_retour'] as String?,
        conducteur2Nom: json['conducteur2_nom'] as String?,
        conducteur2Prenom: json['conducteur2_prenom'] as String?,
        conducteur2Tel: json['conducteur2_tel'] as String?,
        conducteur2NumPermis: json['conducteur2_num_permis'] as String?,
        conducteur2PermisDate: json['conducteur2_permis_date'] as String?,
        conducteur2DateNaissance:
            json['conducteur2_date_naissance'] as String?,
        repartitions: (json['location_repartitions'] as List? ?? [])
            .map((r) => LocationRepartition.fromJson(r))
            .toList(),
        paiements: (json['location_paiements'] as List? ?? [])
            .map((p) => LocationPaiement.fromJson(p))
            .toList(),
        // ── NOUVEAU ────────────────────────────────────────────────────────
        interruptions: (json['location_interruptions'] as List? ?? [])
            .map((i) => LocationInterruption.fromJson(i))
            .toList(),
        createdAt: DateTime.parse(json['created_at']),
      );
}