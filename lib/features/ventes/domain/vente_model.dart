// lib/features/ventes/domain/vente_model.dart

enum VenteStatutPaiement { complet, partiel }

extension VenteStatutPaiementExt on VenteStatutPaiement {
  String get label => switch (this) {
    VenteStatutPaiement.complet  => 'Soldé',
    VenteStatutPaiement.partiel  => 'Partiel',
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
  final double acompte;
  final double soldeRestant;
  final String modePaiement;
  final double commissionGerantPct;
  final double commissionGerantMnt;
  final VenteStatutPaiement statutPaiement;
  final String? notes;
  final String? contratPdfUrl;
  final DateTime createdAt;

  const Vente({
    required this.id,
    required this.vehiculeId,
    this.vehiculeNom,
    required this.clientId,
    this.clientNom,
    this.prixCatalogue,
    required this.prixVente,
    required this.acompte,
    required this.soldeRestant,
    required this.modePaiement,
    required this.commissionGerantPct,
    required this.commissionGerantMnt,
    required this.statutPaiement,
    this.notes,
    this.contratPdfUrl,
    required this.createdAt,
  });

  bool get isSolde => statutPaiement == VenteStatutPaiement.complet;

  factory Vente.fromJson(Map<String, dynamic> json) {
    final veh = json['vehicules'];
    final cli = json['clients'];
    return Vente(
      id:                    json['id'],
      vehiculeId:            json['vehicule_id'],
      vehiculeNom:           veh != null
                               ? '${veh["marque"]} ${veh["modele"]} ${veh["annee"] ?? ""}'.trim()
                               : null,
      clientId:              json['client_id'],
      clientNom:             cli != null
                               ? '${cli["prenom"]} ${cli["nom"]}'
                               : null,
      prixCatalogue:         (json['prix_catalogue'] as num?)?.toDouble(),
      prixVente:             (json['prix_vente'] as num? ?? 0).toDouble(),
      acompte:               (json['acompte'] as num? ?? 0).toDouble(),
      soldeRestant:          (json['solde_restant'] as num? ?? 0).toDouble(),
      modePaiement:          json['mode_paiement'] ?? 'especes',
      commissionGerantPct:   (json['commission_gerant_pct'] as num? ?? 0).toDouble(),
      commissionGerantMnt:   (json['commission_gerant_mnt'] as num? ?? 0).toDouble(),
      statutPaiement:        json['statut_paiement'] == 'complet'
                               ? VenteStatutPaiement.complet
                               : VenteStatutPaiement.partiel,
      notes:                 json['notes'],
      contratPdfUrl:         json['contrat_pdf_url'],
      createdAt:             DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicule_id':            vehiculeId,
    'client_id':              clientId,
    'prix_catalogue':         prixCatalogue,
    'prix_vente':             prixVente,
    'acompte':                acompte,
    'solde_restant':          soldeRestant,
    'mode_paiement':          modePaiement,
    'commission_gerant_pct':  commissionGerantPct,
    'commission_gerant_mnt':  commissionGerantMnt,
    'statut_paiement':        statutPaiement.name,
    'notes':                  notes,
  };
}
