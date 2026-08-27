// lib/features/contrats/domain/contrat_location_dto.dart

import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import '../../../features/vehicules/domain/etat_carrosserie_model.dart';

/// Les différents habillages/mises en page disponibles pour le contrat
/// de location. Le générateur PDF concret est choisi en fonction de cette
/// valeur au moment de l'appel (sélecteur affiché à l'utilisateur).
enum ContratLocationTemplate {
  /// Mise en page "maison" actuelle (2 pages, tableau départ/retour, checklist).
  standard,

  /// Mise en page inspirée d'un contrat de location classique agence
  /// (locataire/loueur en 2 colonnes, encadré kilométrage/carburant,
  /// compte rendu de fin de location + conditions générales détaillées).
  classique,
}

class ContratLocationDto {
  final String contratId;
  final DateTime dateEtablissement;

  // Agence
  final String agenceNom;
  final String agenceAdresse;
  final String agenceTel;
  final String? agenceEmail;
  final String? agenceVille;
  final String? agenceRc;
  final String? agenceCouleurHex;
  final Uint8List? agenceLogoBytes;

  // Locataire
  final String locataireNom;
  final String locatairePrenom;
  final String? locataireDateNaissance;
  final String locataireTel;
  final String? locataireEmail;
  final String? locataireAdresse;
  final String? locataireNumPermis;
  final String? locatairePermisDate;
  final String? locataireCin;

  // 2ème conducteur (optionnel)
  final String? conducteur2Nom;
  final String? conducteur2Prenom;
  final String? conducteur2DateNaissance;
  final String? conducteur2Tel;
  final String? conducteur2NumPermis;
  final String? conducteur2PermisDate;

  // Véhicule
  final String vehiculeMarque;
  final String vehiculeModele;
  final String? vehiculeCouleur;
  final String? vehiculeImmatriculation;
  final String? vehiculeAssurance;
  final String? vehiculeCarburant;
  final String? vehiculeBoite;
  final String? vehiculeCodeRadio;

  // Détails location
  final DateTime dateDepart;
  final String? heureDepart;
  final DateTime dateRetour;
  final String? heureRetour;
  final int kmDepart;
  final int? kmRetour;
  final double prixJour;
  final double caution;

  // Checklist état véhicule
  final bool etatAutoRadio;
  final bool etatRoueSecours;
  final bool etatRadiateur;
  final bool etatCarburant;
  final bool etatAvertisseur;
  final bool etatControle4Roues;
  final bool etatControleCarrosserie;
  final bool etatControleFeuxAv;
  final bool etatControleInterieur;

  final String? observations;
  final String? etatVehicule;
  final Uint8List? schemaCarrosserieImage;
  final EtatCarrosserie? etatCarrosserie;
  final pw.Widget? schemaWidget;
  /// Bytes bruts de car_blueprint.jpg pré-chargés depuis le form.
  /// Permet d'éviter un rootBundle.load() async pendant la génération PDF.
  final Uint8List? blueprintBytes;

  // ── Champs additionnels pour le template "classique" (Taltour-like) ───────
  // Tous optionnels : le template standard les ignore complètement.

  /// N° d'article / R.C additionnel de la société (2ème identifiant, en plus
  /// de agenceRc), affiché dans l'encadré LE LOUEUR.
  final String? agenceArtNo;

  /// Nom de l'agent en charge de la réservation (affiché dans l'encadré LOUEUR).
  final String? agentNom;
  final String? agentTel;

  /// Lieu de départ / retour (ex : "Oran, parking n°3").
  final String? lieuDepart;
  final String? lieuRetour;

  /// Mode de paiement libre (ex : "Espèces", "Paypal 2x", "Virement").
  final String? modePaiement;

  /// Options souscrites (assurance, contrat multiconducteurs, etc.), une
  /// ligne par option, affichées telles quelles.
  final List<String>? optionsLocation;

  /// Niveau de carburant au départ, de 0.0 (vide) à 1.0 (plein), pour la
  /// jauge graphique de l'encadré kilométrage/carburant.
  final double? carburantNiveauDepart;

  /// Remarques libres saisies sur la fiche de départ (distinctes de
  /// [observations], qui reste utilisé par le template standard).
  final String? remarquesDepart;

  const ContratLocationDto({
    required this.contratId,
    required this.dateEtablissement,
    required this.agenceNom,
    required this.agenceAdresse,
    required this.agenceTel,
    this.agenceEmail,
    this.agenceVille,
    this.agenceRc,
    this.agenceCouleurHex,
    this.agenceLogoBytes,
    required this.locataireNom,
    required this.locatairePrenom,
    this.locataireDateNaissance,
    required this.locataireTel,
    this.locataireEmail,
    this.locataireAdresse,
    this.locataireNumPermis,
    this.locatairePermisDate,
    this.locataireCin,
    this.conducteur2Nom,
    this.conducteur2Prenom,
    this.conducteur2DateNaissance,
    this.conducteur2Tel,
    this.conducteur2NumPermis,
    this.conducteur2PermisDate,
    required this.vehiculeMarque,
    required this.vehiculeModele,
    this.vehiculeCouleur,
    this.vehiculeImmatriculation,
    this.vehiculeAssurance,
    this.vehiculeCarburant,
    this.vehiculeBoite,
    this.vehiculeCodeRadio,
    required this.dateDepart,
    this.heureDepart,
    required this.dateRetour,
    this.heureRetour,
    required this.kmDepart,
    this.kmRetour,
    required this.prixJour,
    required this.caution,
    this.etatAutoRadio = false,
    this.etatRoueSecours = false,
    this.etatRadiateur = false,
    this.etatCarburant = false,
    this.etatAvertisseur = false,
    this.etatControle4Roues = false,
    this.etatControleCarrosserie = false,
    this.etatControleFeuxAv = false,
    this.etatControleInterieur = false,
    this.observations,
    this.etatVehicule,
    this.schemaCarrosserieImage,
    this.etatCarrosserie,
    this.schemaWidget,
    this.blueprintBytes,
    this.agenceArtNo,
    this.agentNom,
    this.agentTel,
    this.lieuDepart,
    this.lieuRetour,
    this.modePaiement,
    this.optionsLocation,
    this.carburantNiveauDepart,
    this.remarquesDepart,
  });

  int get nbJours => dateRetour.difference(dateDepart).inDays.clamp(1, 9999);
  double get montantTotal => prixJour * nbJours;
  String get locataireFullName => '$locatairePrenom $locataireNom';
  bool get hasConducteur2 =>
      conducteur2Nom != null && (conducteur2Nom?.isNotEmpty ?? false);

  /// Copie avec schemaWidget pré-construit (utilisé par buildBothAsync).
  ContratLocationDto withSchemaWidget(pw.Widget? widget) {
    return ContratLocationDto(
      contratId: contratId,
      dateEtablissement: dateEtablissement,
      agenceNom: agenceNom,
      agenceAdresse: agenceAdresse,
      agenceTel: agenceTel,
      agenceEmail: agenceEmail,
      agenceVille: agenceVille,
      agenceRc: agenceRc,
      agenceCouleurHex: agenceCouleurHex,
      agenceLogoBytes: agenceLogoBytes,
      locataireNom: locataireNom,
      locatairePrenom: locatairePrenom,
      locataireDateNaissance: locataireDateNaissance,
      locataireTel: locataireTel,
      locataireEmail: locataireEmail,
      locataireAdresse: locataireAdresse,
      locataireNumPermis: locataireNumPermis,
      locatairePermisDate: locatairePermisDate,
      locataireCin: locataireCin,
      conducteur2Nom: conducteur2Nom,
      conducteur2Prenom: conducteur2Prenom,
      conducteur2DateNaissance: conducteur2DateNaissance,
      conducteur2Tel: conducteur2Tel,
      conducteur2NumPermis: conducteur2NumPermis,
      conducteur2PermisDate: conducteur2PermisDate,
      vehiculeMarque: vehiculeMarque,
      vehiculeModele: vehiculeModele,
      vehiculeCouleur: vehiculeCouleur,
      vehiculeImmatriculation: vehiculeImmatriculation,
      vehiculeAssurance: vehiculeAssurance,
      vehiculeCarburant: vehiculeCarburant,
      vehiculeBoite: vehiculeBoite,
      vehiculeCodeRadio: vehiculeCodeRadio,
      dateDepart: dateDepart,
      heureDepart: heureDepart,
      dateRetour: dateRetour,
      heureRetour: heureRetour,
      kmDepart: kmDepart,
      kmRetour: kmRetour,
      prixJour: prixJour,
      caution: caution,
      etatAutoRadio: etatAutoRadio,
      etatRoueSecours: etatRoueSecours,
      etatRadiateur: etatRadiateur,
      etatCarburant: etatCarburant,
      etatAvertisseur: etatAvertisseur,
      etatControle4Roues: etatControle4Roues,
      etatControleCarrosserie: etatControleCarrosserie,
      etatControleFeuxAv: etatControleFeuxAv,
      etatControleInterieur: etatControleInterieur,
      observations: observations,
      etatVehicule: etatVehicule,
      schemaCarrosserieImage: schemaCarrosserieImage,
      etatCarrosserie: etatCarrosserie,
      schemaWidget: widget,
      blueprintBytes: blueprintBytes,
      agenceArtNo: agenceArtNo,
      agentNom: agentNom,
      agentTel: agentTel,
      lieuDepart: lieuDepart,
      lieuRetour: lieuRetour,
      modePaiement: modePaiement,
      optionsLocation: optionsLocation,
      carburantNiveauDepart: carburantNiveauDepart,
      remarquesDepart: remarquesDepart,
    );
  }
}

/// Paire de documents PDF (FR + AR) en mémoire.
class ContratLocationPdfPair {
  final pw.Document fr;
  final pw.Document ar;
  const ContratLocationPdfPair({required this.fr, required this.ar});
}