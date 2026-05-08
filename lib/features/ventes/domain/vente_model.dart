// lib/features/ventes/domain/vente_model.dart
// acompte/solde_restant supprimés (colonnes retirées de la DB).
// Le solde est calculé dynamiquement depuis vente_paiements.

enum VenteStatutPaiement { complet, partiel }

extension VenteStatutPaiementExt on VenteStatutPaiement {
  String get label => switch (this) {
    VenteStatutPaiement.complet => 'Soldé',
    VenteStatutPaiement.partiel => 'Partiel',
  };
}

class VentePaiement {
  final String id;
  final String venteId;
  final double montant;
  final DateTime datePaiement;
  final String? mode;
  final String? notes;

  const VentePaiement({
    required this.id, required this.venteId,
    required this.montant, required this.datePaiement,
    this.mode, this.notes,
  });

  factory VentePaiement.fromJson(Map<String, dynamic> json) => VentePaiement(
    id:           json['id'],
    venteId:      json['vente_id'],
    montant:      (json['montant'] as num).toDouble(),
    datePaiement: DateTime.parse(json['date_paiement']),
    mode:         json['mode'],
    notes:        json['notes'],
  );

  Map<String, dynamic> toJson() => {
    'vente_id':      venteId,
    'montant':       montant,
    'date_paiement': datePaiement.toIso8601String().substring(0, 10),
    'mode':          mode,
    'notes':         notes,
  };
}

class Vente {
  final String id;
  final String vehiculeId;
  final String? vehiculeNom;
  final String clientId;
  final String? clientNom;
  final double? prixCatalogue;
  final double prixVente;
  final String modePaiement;
  final double commissionGerantPct;
  final double commissionGerantMnt;
  final VenteStatutPaiement statutPaiement;
  final String? notes;
  final String? contratPdfUrl;
  final DateTime createdAt;
  final List<VentePaiement> paiements;

  const Vente({
    required this.id, required this.vehiculeId, this.vehiculeNom,
    required this.clientId, this.clientNom, this.prixCatalogue,
    required this.prixVente, required this.modePaiement,
    required this.commissionGerantPct, required this.commissionGerantMnt,
    required this.statutPaiement, this.notes, this.contratPdfUrl,
    required this.createdAt, this.paiements = const [],
  });

  double get totalPaye =>
    paiements.fold(0.0, (s, p) => s + p.montant);

  double get soldeRestant =>
    (prixVente - totalPaye).clamp(0.0, double.infinity);

  bool get isSolde => statutPaiement == VenteStatutPaiement.complet;

  factory Vente.fromJson(Map<String, dynamic> json) {
  final veh = json['vehicules'];
  final cli = json['clients'];
  final vehiculeNom = veh != null
      ? '${veh['marque']} ${veh['modele']} ${veh['annee'] ?? ''}'.trim()
      : null;
  final clientNom = cli != null
      ? '${cli['prenom']} ${cli['nom']}'
      : null;

  return Vente(
    id:                   json['id'],
    vehiculeId:           json['vehicule_id'],
    vehiculeNom:          vehiculeNom,
    clientId:             json['client_id'],
    clientNom:            clientNom,
    prixCatalogue:        (json['prix_catalogue'] as num?)?.toDouble(),
    prixVente:            (json['prix_vente'] as num? ?? 0).toDouble(),
    modePaiement:         json['mode_paiement'] ?? 'especes',
    commissionGerantPct:  (json['commission_gerant_pct'] as num? ?? 0).toDouble(),
    commissionGerantMnt:  (json['commission_gerant_mnt'] as num? ?? 0).toDouble(),
    statutPaiement:       json['statut_paiement'] == 'complet'
                            ? VenteStatutPaiement.complet
                            : VenteStatutPaiement.partiel,
    notes:                json['notes'],
    contratPdfUrl:        json['contrat_pdf_url'],
    createdAt:            DateTime.parse(json['created_at']),
    paiements:            (json['vente_paiements'] as List? ?? [])
                            .map((p) => VentePaiement.fromJson(p)).toList(),
  );
}

  // Ne jamais envoyer acompte / solde_restant (colonnes supprimées)
  Map<String, dynamic> toJson() => {
    'vehicule_id':           vehiculeId,
    'client_id':             clientId,
    'prix_catalogue':        prixCatalogue,
    'prix_vente':            prixVente,
    'mode_paiement':         modePaiement,
    'commission_gerant_pct': commissionGerantPct,
    'commission_gerant_mnt': commissionGerantMnt,
    'statut_paiement':       statutPaiement.name,
    'notes':                 notes,
  };
}
