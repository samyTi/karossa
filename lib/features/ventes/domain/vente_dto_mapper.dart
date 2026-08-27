// lib/features/ventes/domain/vente_dto_mapper.dart

import 'dart:typed_data';

import '../../contrats/domain/contrat_vente_dto.dart';
import '../../clients/domain/client_model.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../domain/vente_model.dart';

extension VenteToDto on Vente {
  ContratVenteDto toContratDto({
    required Client client,
    required Vehicule vehicule,
    required Map<String, dynamic> settings,
    List<Map<String, String>> articlesFr = const [],
    List<Map<String, String>> articlesAr = const [],
    Uint8List? logoBytes,
  }) {
    return ContratVenteDto(
      venteId: id,
      dateEtablissement: DateTime.now(),
      
      // Données agence (Showroom)
      agenceNom: settings['nom'] as String? ?? 'Garage Auto',
      agenceAdresse: settings['adresse'] as String? ?? '',
      agenceTel: settings['tel'] as String? ?? '',
      agenceEmail: settings['email'] as String?,
      agenceVille: settings['ville'] as String?,
      agenceRc: settings['rc'] as String?,
      agenceCouleurHex: settings['couleur'] as String?,
      agenceLogoUrl: settings['logo_url'] as String?,
      agenceLogoBytes: logoBytes,
      
      // Données Acheteur (via objet Client)
      acheteurNom: client.nom,
      acheteurPrenom: client.prenom,
      acheteurTel: client.telephone,
      acheteurEmail: client.email,
      acheteurAdresse: client.adresse,
      acheteurCin: client.numCni,
      acheteurNumPermis: client.numPermis,
      
      // Données Véhicule (via objet Vehicule)
      vehiculeMarque: vehicule.marque,
      vehiculeModele: vehicule.modele,
      vehiculeAnnee: vehicule.annee,
      vehiculeCouleur: vehicule.couleur,
      vehiculeImmatriculation: vehicule.immatriculation,
      vehiculeCarburant: vehicule.carburant,
      vehiculeBoite: vehicule.boite,
      vehiculeKilometrage: vehicule.kilometrage,
      vehiculeNumChassis: vehicule.numChassis,
      
      // Données Financières (via vos getters de modèle)
      prixVente: prixVente,
      acompteVerse: totalPaye,
      soldeRestant: soldeRestant,
      modePaiement: modePaiement, // Utilisé directement depuis Vente
      statutPaiement: isSolde ? 'complet' : 'partiel',
      notes: notes,
      articlesFr: articlesFr,
      articlesAr: articlesAr,
    );
  }
}