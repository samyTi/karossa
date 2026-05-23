// lib/features/web_demandes/domain/web_demande_model.dart

enum DemandeWebStatut { enAttente, approuve, rejete }

/// Les 3 tables sources du site web
enum DemandeWebType {
  location, // reservations_web
  propositionVente, // propositions_vente
  demandeDevis, // demandes_devis (achat / échange / devis)
}

/// Sous-type de demandes_devis
enum DevisType { achat, echange, devis }

class WebDemande {
  final String id;
  final DemandeWebStatut statut;
  final DemandeWebType type;

  // ── Informations Client ───────────────────────────────────────────────────
  final String? clientId;
  final String? clientNom;
  final String? clientPrenom;
  final String? telephone;
  final String? message;

  // ── Véhicule Showroom ciblé (location / demande_devis) ───────────────────
  final String? vehiculeId;
  final String? vehiculeMarque;
  final String? vehiculeModele;
  final String? vehiculeImmat;
  final double? vehiculePrixLocation; // prix_location_jour pour estimation

  // ── Données Réservation Location ─────────────────────────────────────────
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final double? montantEstime;

  // ── Données Proposition de Vente (reprise client) ────────────────────────
  final String? propMarque;
  final String? propModele;
  final int? propAnnee;
  final int? propKm;
  final double? propPrixDemande;
  final List<String> propPhotos; // URLs photos proposées

  // ── Données Demande de Devis ─────────────────────────────────────────────
  final DevisType? devisType;
  final double? budgetMax;

  final DateTime? createdAt;

  const WebDemande({
    required this.id,
    required this.statut,
    required this.type,
    this.clientId,
    this.clientNom,
    this.clientPrenom,
    this.telephone,
    this.message,
    this.vehiculeId,
    this.vehiculeMarque,
    this.vehiculeModele,
    this.vehiculeImmat,
    this.vehiculePrixLocation,
    this.dateDebut,
    this.dateFin,
    this.montantEstime,
    this.propMarque,
    this.propModele,
    this.propAnnee,
    this.propKm,
    this.propPrixDemande,
    this.propPhotos = const [],
    this.devisType,
    this.budgetMax,
    this.createdAt,
  });

  // ── Getters utilitaires ──────────────────────────────────────────────────

  String get clientFullName {
    final parts = [clientPrenom, clientNom]
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.join(' ') : 'Client Anonyme';
  }

  bool get hasClient => clientNom != null || clientPrenom != null;

  /// Nombre de jours de location demandés
  int? get nbJours {
    if (dateDebut == null || dateFin == null) return null;
    return dateFin!.difference(dateDebut!).inDays;
  }

  /// Montant estimé calculé si non fourni par le web (prix_location_jour × nbJours)
  double? get montantEstimeCalcule {
    if (montantEstime != null) return montantEstime;
    final jours = nbJours;
    if (jours != null && vehiculePrixLocation != null) {
      return vehiculePrixLocation! * jours;
    }
    return null;
  }

  String get typeLabel {
    switch (type) {
      case DemandeWebType.location:
        return 'Réservation Location';
      case DemandeWebType.propositionVente:
        return 'Proposition de Reprise';
      case DemandeWebType.demandeDevis:
        switch (devisType) {
          case DevisType.achat:
            return "Demande d'Achat";
          case DevisType.echange:
            return "Demande d'Échange";
          case DevisType.devis:
            return 'Demande de Devis';
          default:
            return 'Demande Devis';
        }
    }
  }

  String get statutLabel {
    switch (statut) {
      case DemandeWebStatut.enAttente:
        return 'En attente';
      case DemandeWebStatut.approuve:
        return 'Approuvé';
      case DemandeWebStatut.rejete:
        return 'Rejeté';
    }
  }

  String get sourceTable {
    switch (type) {
      case DemandeWebType.location:
        return 'reservations_web';
      case DemandeWebType.propositionVente:
        return 'propositions_vente';
      case DemandeWebType.demandeDevis:
        return 'demandes_devis';
    }
  }

  // ── Factory depuis Map Supabase ───────────────────────────────────────────

  factory WebDemande.fromReservationWeb(Map<String, dynamic> json) {
    // Le join retourne clients: {nom, prenom, telephone} ou null
    // (null si client_id est null OU si le client n'existe plus en base)
    final client = json['clients'] as Map<String, dynamic>?;
    final vehicule = json['vehicules'] as Map<String, dynamic>?;

    return WebDemande(
      id: json['id']?.toString() ?? '',
      statut: _parseStatut(json['statut']),
      type: DemandeWebType.location,
      clientId: json['client_id']?.toString(),
      clientNom: client?['nom'],
      clientPrenom: client?['prenom'],
      // telephone_contact prioritaire (saisi sur le site), sinon fiche client
      telephone: _nonEmpty(json['telephone_contact']) ?? client?['telephone'],
      message: json['notes'],
      vehiculeId: json['vehicule_id']?.toString(),
      vehiculeMarque: vehicule?['marque'],
      vehiculeModele: vehicule?['modele'],
      vehiculeImmat: vehicule?['immatriculation'],
      vehiculePrixLocation: _parseDouble(vehicule?['prix_location_jour']),
      dateDebut: _parseDate(json['date_debut']),
      dateFin: _parseDate(json['date_fin']),
      montantEstime: _parseDouble(json['montant_estime']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  factory WebDemande.fromPropositionVente(Map<String, dynamic> json) {
    final client = json['clients'] as Map<String, dynamic>?;

    // Les photos sont stockées en jsonb (liste d'URLs)
    final photosRaw = json['photos'];
    final List<String> photos = photosRaw is List
        ? photosRaw.map((e) => e.toString()).toList()
        : [];

    return WebDemande(
      id: json['id']?.toString() ?? '',
      statut: _parseStatut(json['statut']),
      type: DemandeWebType.propositionVente,
      clientId: json['client_id']?.toString(),
      clientNom: client?['nom'],
      clientPrenom: client?['prenom'],
      telephone: client?['telephone'],
      message: json['description'],
      propMarque: json['marque'],
      propModele: json['modele'],
      propAnnee: json['annee'] as int?,
      propKm: json['kilometrage'] as int?,
      // Le site web peut envoyer "prix_souhaite" ou "prix_demande" selon la version.
      // On accepte les deux : prix_demande (schéma BDD officiel) en priorité,
      // puis prix_souhaite (alias utilisé par certaines versions du formulaire web).
      propPrixDemande: _parseDouble(json['prix_demande']) ??
          _parseDouble(json['prix_souhaite']),
      propPhotos: photos,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  factory WebDemande.fromDemandeDevis(Map<String, dynamic> json) {
    final client = json['clients'] as Map<String, dynamic>?;
    final vehicule = json['vehicules'] as Map<String, dynamic>?;

    return WebDemande(
      id: json['id']?.toString() ?? '',
      statut: _parseStatut(json['statut']),
      type: DemandeWebType.demandeDevis,
      clientId: json['client_id']?.toString(),
      clientNom: client?['nom'],
      clientPrenom: client?['prenom'],
      telephone: client?['telephone'],
      message: json['message'],
      vehiculeId: json['vehicule_id']?.toString(),
      vehiculeMarque: vehicule?['marque'],
      vehiculeModele: vehicule?['modele'],
      vehiculeImmat: vehicule?['immatriculation'],
      vehiculePrixLocation: _parseDouble(vehicule?['prix_vente']),
      budgetMax: _parseDouble(json['budget_max']),
      devisType: _parseDevisType(json['type']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toStatutMap() => {'statut': _statutToDb(statut)};

  // ── Helpers de parsing statiques ─────────────────────────────────────────

  static DemandeWebStatut _parseStatut(dynamic raw) {
    final s = (raw ?? '').toString().toLowerCase().trim();
    if (s == 'approuve' || s == 'approved') return DemandeWebStatut.approuve;
    if (s == 'rejete' || s == 'rejected') return DemandeWebStatut.rejete;
    return DemandeWebStatut.enAttente;
  }

  static DevisType? _parseDevisType(dynamic raw) {
    switch ((raw ?? '').toString().toLowerCase()) {
      case 'achat':
        return DevisType.achat;
      case 'echange':
        return DevisType.echange;
      case 'devis':
        return DevisType.devis;
      default:
        return null;
    }
  }

  static String _statutToDb(DemandeWebStatut s) {
    switch (s) {
      case DemandeWebStatut.enAttente:
        return 'en_attente';
      case DemandeWebStatut.approuve:
        return 'approuve';
      case DemandeWebStatut.rejete:
        return 'rejete';
    }
  }

  static DateTime? _parseDate(dynamic raw) =>
      raw != null ? DateTime.tryParse(raw.toString()) : null;

  static DateTime? _parseDateTime(dynamic raw) =>
      raw != null ? DateTime.tryParse(raw.toString()) : null;

  static double? _parseDouble(dynamic raw) =>
      raw != null ? (raw as num?)?.toDouble() : null;

  static String? _nonEmpty(dynamic raw) {
    final s = raw?.toString().trim();
    return (s != null && s.isNotEmpty) ? s : null;
  }

  // ── copyWith ─────────────────────────────────────────────────────────────

  WebDemande copyWith({DemandeWebStatut? statut}) {
    return WebDemande(
      id: id,
      statut: statut ?? this.statut,
      type: type,
      clientId: clientId,
      clientNom: clientNom,
      clientPrenom: clientPrenom,
      telephone: telephone,
      message: message,
      vehiculeId: vehiculeId,
      vehiculeMarque: vehiculeMarque,
      vehiculeModele: vehiculeModele,
      vehiculeImmat: vehiculeImmat,
      vehiculePrixLocation: vehiculePrixLocation,
      dateDebut: dateDebut,
      dateFin: dateFin,
      montantEstime: montantEstime,
      propMarque: propMarque,
      propModele: propModele,
      propAnnee: propAnnee,
      propKm: propKm,
      propPrixDemande: propPrixDemande,
      propPhotos: propPhotos,
      devisType: devisType,
      budgetMax: budgetMax,
      createdAt: createdAt,
    );
  }
}