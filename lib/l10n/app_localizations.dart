import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @navAccueil.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navAccueil;

  /// No description provided for @navClients.
  ///
  /// In fr, this message translates to:
  /// **'Clients'**
  String get navClients;

  /// No description provided for @navLocations.
  ///
  /// In fr, this message translates to:
  /// **'Locations'**
  String get navLocations;

  /// No description provided for @navPlus.
  ///
  /// In fr, this message translates to:
  /// **'Plus'**
  String get navPlus;

  /// No description provided for @navVehicules.
  ///
  /// In fr, this message translates to:
  /// **'Véhicules'**
  String get navVehicules;

  /// No description provided for @tabActifs.
  ///
  /// In fr, this message translates to:
  /// **'Actifs'**
  String get tabActifs;

  /// No description provided for @tabEnCours.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get tabEnCours;

  /// No description provided for @tabHistorique.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get tabHistorique;

  /// No description provided for @tabStatistiques.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get tabStatistiques;

  /// No description provided for @tabTermines.
  ///
  /// In fr, this message translates to:
  /// **'Terminés'**
  String get tabTermines;

  /// No description provided for @titreAchats.
  ///
  /// In fr, this message translates to:
  /// **'Achats'**
  String get titreAchats;

  /// No description provided for @titreCaisse.
  ///
  /// In fr, this message translates to:
  /// **'Caisse'**
  String get titreCaisse;

  /// No description provided for @titreClients.
  ///
  /// In fr, this message translates to:
  /// **'Clients'**
  String get titreClients;

  /// No description provided for @titreContrats.
  ///
  /// In fr, this message translates to:
  /// **'Contrats'**
  String get titreContrats;

  /// No description provided for @titreDashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get titreDashboard;

  /// No description provided for @titreEchanges.
  ///
  /// In fr, this message translates to:
  /// **'Échanges'**
  String get titreEchanges;

  /// No description provided for @titreEntretien.
  ///
  /// In fr, this message translates to:
  /// **'Entretien & Alertes'**
  String get titreEntretien;

  /// No description provided for @titreFinance.
  ///
  /// In fr, this message translates to:
  /// **'Finance Propriétaires'**
  String get titreFinance;

  /// No description provided for @titreGps.
  ///
  /// In fr, this message translates to:
  /// **'GPS & Tracking'**
  String get titreGps;

  /// No description provided for @titreLocations.
  ///
  /// In fr, this message translates to:
  /// **'Locations'**
  String get titreLocations;

  /// No description provided for @titreNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get titreNotifications;

  /// No description provided for @titreParametres.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get titreParametres;

  /// No description provided for @titreReparations.
  ///
  /// In fr, this message translates to:
  /// **'Réparations'**
  String get titreReparations;

  /// No description provided for @titreUtilisateurs.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get titreUtilisateurs;

  /// No description provided for @titreVehicules.
  ///
  /// In fr, this message translates to:
  /// **'Véhicules'**
  String get titreVehicules;

  /// No description provided for @titreVentes.
  ///
  /// In fr, this message translates to:
  /// **'Ventes'**
  String get titreVentes;

  /// No description provided for @aRisque.
  ///
  /// In fr, this message translates to:
  /// **'A risque'**
  String get aRisque;

  /// No description provided for @accesAuxPerformances.
  ///
  /// In fr, this message translates to:
  /// **'Accès aux performances et suivi des véhicules associés'**
  String get accesAuxPerformances;

  /// No description provided for @alerteControleTechnique.
  ///
  /// In fr, this message translates to:
  /// **'Contrôle technique'**
  String get alerteControleTechnique;

  /// No description provided for @analyseDesRendementsEtStatutsDe.
  ///
  /// In fr, this message translates to:
  /// **'Analyse des rendements et statuts de contrats'**
  String get analyseDesRendementsEtStatutsDe;

  /// No description provided for @annule.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get annule;

  /// No description provided for @annulee.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get annulee;

  /// No description provided for @annulees.
  ///
  /// In fr, this message translates to:
  /// **'Annulées'**
  String get annulees;

  /// No description provided for @associe.
  ///
  /// In fr, this message translates to:
  /// **'Associé'**
  String get associe;

  /// No description provided for @aucunAchatEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Aucun achat en cours'**
  String get aucunAchatEnCours;

  /// No description provided for @aucunVehiculeAssocieACetteReservation.
  ///
  /// In fr, this message translates to:
  /// **'Aucun véhicule associé à cette réservation.'**
  String get aucunVehiculeAssocieACetteReservation;

  /// No description provided for @aucunVehiculeAssocieLaLocationNe.
  ///
  /// In fr, this message translates to:
  /// **'⚠️ Aucun véhicule associé — la location ne peut pas être créée.'**
  String get aucunVehiculeAssocieLaLocationNe;

  /// No description provided for @boiteAutomatique.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get boiteAutomatique;

  /// No description provided for @boiteManuelle.
  ///
  /// In fr, this message translates to:
  /// **'Manuelle'**
  String get boiteManuelle;

  /// No description provided for @btnAnnuler.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get btnAnnuler;

  /// No description provided for @carburantDiesel.
  ///
  /// In fr, this message translates to:
  /// **'Diesel'**
  String get carburantDiesel;

  /// No description provided for @carburantElectrique.
  ///
  /// In fr, this message translates to:
  /// **'Électrique'**
  String get carburantElectrique;

  /// No description provided for @carburantEssence.
  ///
  /// In fr, this message translates to:
  /// **'Essence'**
  String get carburantEssence;

  /// No description provided for @carburantHybride.
  ///
  /// In fr, this message translates to:
  /// **'Hybride'**
  String get carburantHybride;

  /// No description provided for @carburantPropreteDegradationsConstatees.
  ///
  /// In fr, this message translates to:
  /// **'Carburant, propreté, dégradations constatées…'**
  String get carburantPropreteDegradationsConstatees;

  /// No description provided for @champStatut.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get champStatut;

  /// No description provided for @changerLeStatut.
  ///
  /// In fr, this message translates to:
  /// **'Changer le statut'**
  String get changerLeStatut;

  /// No description provided for @cheque.
  ///
  /// In fr, this message translates to:
  /// **'Chèque'**
  String get cheque;

  /// No description provided for @clientBlacklist.
  ///
  /// In fr, this message translates to:
  /// **'Liste noire'**
  String get clientBlacklist;

  /// No description provided for @clientFiable.
  ///
  /// In fr, this message translates to:
  /// **'Client fiable'**
  String get clientFiable;

  /// No description provided for @clientRisque.
  ///
  /// In fr, this message translates to:
  /// **'Risqué'**
  String get clientRisque;

  /// No description provided for @commissionGerant.
  ///
  /// In fr, this message translates to:
  /// **'Commission gérant'**
  String get commissionGerant;

  /// No description provided for @commissionsDuGerant.
  ///
  /// In fr, this message translates to:
  /// **'Commissions du gérant'**
  String get commissionsDuGerant;

  /// No description provided for @comptesGerantsAssociesEtProprietaires.
  ///
  /// In fr, this message translates to:
  /// **'Comptes gérants, associés et propriétaires'**
  String get comptesGerantsAssociesEtProprietaires;

  /// No description provided for @disponibles.
  ///
  /// In fr, this message translates to:
  /// **'Disponibles'**
  String get disponibles;

  /// No description provided for @enCours.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get enCours;

  /// No description provided for @enRetard.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get enRetard;

  /// No description provided for @especes.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get especes;

  /// No description provided for @gerant.
  ///
  /// In fr, this message translates to:
  /// **'Gérant'**
  String get gerant;

  /// No description provided for @gestionCompleteDuShowroom.
  ///
  /// In fr, this message translates to:
  /// **'Gestion complète du showroom au quotidien'**
  String get gestionCompleteDuShowroom;

  /// No description provided for @indisponibleALaLocationPendantLes.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible a la location pendant les travaux'**
  String get indisponibleALaLocationPendantLes;

  /// No description provided for @interruptionControleTechnique.
  ///
  /// In fr, this message translates to:
  /// **'Contrôle technique'**
  String get interruptionControleTechnique;

  /// No description provided for @leGerant.
  ///
  /// In fr, this message translates to:
  /// **'Le Gérant'**
  String get leGerant;

  /// No description provided for @locationAnnule.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get locationAnnule;

  /// No description provided for @locationEnCours.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get locationEnCours;

  /// No description provided for @locationRetard.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get locationRetard;

  /// No description provided for @locationTermine.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get locationTermine;

  /// No description provided for @locationsEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Locations en cours'**
  String get locationsEnCours;

  /// No description provided for @marquerDisponible.
  ///
  /// In fr, this message translates to:
  /// **'Marquer disponible'**
  String get marquerDisponible;

  /// No description provided for @modeCheque.
  ///
  /// In fr, this message translates to:
  /// **'Chèque'**
  String get modeCheque;

  /// No description provided for @modeEspeces.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get modeEspeces;

  /// No description provided for @modeVirement.
  ///
  /// In fr, this message translates to:
  /// **'Virement'**
  String get modeVirement;

  /// No description provided for @paiementComplet.
  ///
  /// In fr, this message translates to:
  /// **'Paiement complet'**
  String get paiementComplet;

  /// No description provided for @paiementPartiel.
  ///
  /// In fr, this message translates to:
  /// **'Paiement partiel'**
  String get paiementPartiel;

  /// No description provided for @partProprietaireS.
  ///
  /// In fr, this message translates to:
  /// **'Part propriétaire(s)'**
  String get partProprietaireS;

  /// No description provided for @proprietaire.
  ///
  /// In fr, this message translates to:
  /// **'Propriétaire'**
  String get proprietaire;

  /// No description provided for @proprietaireDuShowroom.
  ///
  /// In fr, this message translates to:
  /// **'Propriétaire du showroom et de la flotte de véhicules'**
  String get proprietaireDuShowroom;

  /// No description provided for @repElectrique.
  ///
  /// In fr, this message translates to:
  /// **'Électrique'**
  String get repElectrique;

  /// No description provided for @retardDeRetour.
  ///
  /// In fr, this message translates to:
  /// **'Retard de retour'**
  String get retardDeRetour;

  /// No description provided for @roleAssocie.
  ///
  /// In fr, this message translates to:
  /// **'Associé'**
  String get roleAssocie;

  /// No description provided for @roleGerant.
  ///
  /// In fr, this message translates to:
  /// **'Gérant'**
  String get roleGerant;

  /// No description provided for @roleProprietaire.
  ///
  /// In fr, this message translates to:
  /// **'Propriétaire'**
  String get roleProprietaire;

  /// No description provided for @statutClient.
  ///
  /// In fr, this message translates to:
  /// **'Statut client'**
  String get statutClient;

  /// No description provided for @statutDeLaFlotteAuto.
  ///
  /// In fr, this message translates to:
  /// **'Statut de la Flotte Auto'**
  String get statutDeLaFlotteAuto;

  /// No description provided for @statutDeLaLocation.
  ///
  /// In fr, this message translates to:
  /// **'Statut de la location'**
  String get statutDeLaLocation;

  /// No description provided for @statutDisponible.
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get statutDisponible;

  /// No description provided for @statutFinal.
  ///
  /// In fr, this message translates to:
  /// **'Statut final'**
  String get statutFinal;

  /// No description provided for @statutLoue.
  ///
  /// In fr, this message translates to:
  /// **'Loué'**
  String get statutLoue;

  /// No description provided for @statutReparation.
  ///
  /// In fr, this message translates to:
  /// **'En réparation'**
  String get statutReparation;

  /// No description provided for @statutReserve.
  ///
  /// In fr, this message translates to:
  /// **'Réservé'**
  String get statutReserve;

  /// No description provided for @statutVendu.
  ///
  /// In fr, this message translates to:
  /// **'Vendu'**
  String get statutVendu;

  /// No description provided for @termine.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get termine;

  /// No description provided for @terminee.
  ///
  /// In fr, this message translates to:
  /// **'Terminée'**
  String get terminee;

  /// No description provided for @terminees.
  ///
  /// In fr, this message translates to:
  /// **'Terminées'**
  String get terminees;

  /// No description provided for @vehiculeVendu.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule vendu'**
  String get vehiculeVendu;

  /// No description provided for @votreRole.
  ///
  /// In fr, this message translates to:
  /// **'Votre rôle'**
  String get votreRole;

  /// No description provided for @achatsDeVehicules.
  ///
  /// In fr, this message translates to:
  /// **'Achats de véhicules'**
  String get achatsDeVehicules;

  /// No description provided for @annee.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get annee;

  /// No description provided for @anneeInvalide.
  ///
  /// In fr, this message translates to:
  /// **'Année invalide'**
  String get anneeInvalide;

  /// No description provided for @anneeMax.
  ///
  /// In fr, this message translates to:
  /// **'Année max'**
  String get anneeMax;

  /// No description provided for @anneeMin.
  ///
  /// In fr, this message translates to:
  /// **'Année min'**
  String get anneeMin;

  /// No description provided for @aucunContratTrouvePourCeVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contrat trouvé pour ce véhicule'**
  String get aucunContratTrouvePourCeVehicule;

  /// No description provided for @aucunHistoriquePourCeVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Aucun historique pour ce véhicule'**
  String get aucunHistoriquePourCeVehicule;

  /// No description provided for @carrosserieVehiculeCede.
  ///
  /// In fr, this message translates to:
  /// **'Carrosserie — Véhicule cédé'**
  String get carrosserieVehiculeCede;

  /// No description provided for @carrosserieVehiculeRepris.
  ///
  /// In fr, this message translates to:
  /// **'Carrosserie — Véhicule repris'**
  String get carrosserieVehiculeRepris;

  /// No description provided for @champKilometrage.
  ///
  /// In fr, this message translates to:
  /// **'Kilométrage'**
  String get champKilometrage;

  /// No description provided for @champPrixAchat.
  ///
  /// In fr, this message translates to:
  /// **'Prix d\'achat'**
  String get champPrixAchat;

  /// No description provided for @champPrixVente.
  ///
  /// In fr, this message translates to:
  /// **'Prix de vente'**
  String get champPrixVente;

  /// No description provided for @checkInVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Check-in Véhicule'**
  String get checkInVehicule;

  /// No description provided for @choisirUnVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un véhicule'**
  String get choisirUnVehicule;

  /// No description provided for @contratsDuVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Contrats du véhicule'**
  String get contratsDuVehicule;

  /// No description provided for @detailParCategorie.
  ///
  /// In fr, this message translates to:
  /// **'Détail par catégorie'**
  String get detailParCategorie;

  /// No description provided for @deviceIdFlespiManquantPourCe.
  ///
  /// In fr, this message translates to:
  /// **'Device ID Flespi manquant pour ce véhicule.'**
  String get deviceIdFlespiManquantPourCe;

  /// No description provided for @etatDuVehicule.
  ///
  /// In fr, this message translates to:
  /// **'État du véhicule'**
  String get etatDuVehicule;

  /// No description provided for @etatDuVehiculeAuRetourOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'État du véhicule au retour (optionnel)'**
  String get etatDuVehiculeAuRetourOptionnel;

  /// No description provided for @etatDuVehiculeDommagesAvantLocation.
  ///
  /// In fr, this message translates to:
  /// **'ÉTAT DU VÉHICULE — DOMMAGES AVANT LOCATION'**
  String get etatDuVehiculeDommagesAvantLocation;

  /// No description provided for @historiqueDuVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Historique du véhicule'**
  String get historiqueDuVehicule;

  /// No description provided for @immatriculation.
  ///
  /// In fr, this message translates to:
  /// **'Immatriculation'**
  String get immatriculation;

  /// No description provided for @kilometrage.
  ///
  /// In fr, this message translates to:
  /// **'Kilométrage'**
  String get kilometrage;

  /// No description provided for @kilometrageEcheanceOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Kilometrage echeance (optionnel)'**
  String get kilometrageEcheanceOptionnel;

  /// No description provided for @laDureeSeraCalculeeAuRetour.
  ///
  /// In fr, this message translates to:
  /// **'La durée sera calculée au retour du véhicule'**
  String get laDureeSeraCalculeeAuRetour;

  /// No description provided for @laDureeSeraCalculeeLorsDu.
  ///
  /// In fr, this message translates to:
  /// **'La durée sera calculée lors du retour du véhicule'**
  String get laDureeSeraCalculeeLorsDu;

  /// No description provided for @leMontantTotalSeraCalculeAu.
  ///
  /// In fr, this message translates to:
  /// **'Le montant total sera calculé au moment du retour du véhicule.'**
  String get leMontantTotalSeraCalculeAu;

  /// No description provided for @marque.
  ///
  /// In fr, this message translates to:
  /// **'Marque *'**
  String get marque;

  /// No description provided for @marquerCommeSoldee.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme soldée'**
  String get marquerCommeSoldee;

  /// No description provided for @marquerGpsCommeLues.
  ///
  /// In fr, this message translates to:
  /// **'Marquer GPS comme lues'**
  String get marquerGpsCommeLues;

  /// No description provided for @marquezLesDommagesConstatesAuRetour.
  ///
  /// In fr, this message translates to:
  /// **'Marquez les dommages constatés au retour'**
  String get marquezLesDommagesConstatesAuRetour;

  /// No description provided for @modele.
  ///
  /// In fr, this message translates to:
  /// **'Modèle'**
  String get modele;

  /// No description provided for @modeleGemini.
  ///
  /// In fr, this message translates to:
  /// **'Modèle Gemini'**
  String get modeleGemini;

  /// No description provided for @nChassis.
  ///
  /// In fr, this message translates to:
  /// **'N° Chassis'**
  String get nChassis;

  /// No description provided for @notesEtatDuVehiculeAuDepart.
  ///
  /// In fr, this message translates to:
  /// **'Notes état du véhicule au départ'**
  String get notesEtatDuVehiculeAuDepart;

  /// No description provided for @notesEtatDuVehiculeAuRetour.
  ///
  /// In fr, this message translates to:
  /// **'Notes état du véhicule au retour'**
  String get notesEtatDuVehiculeAuRetour;

  /// No description provided for @nouveauVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau véhicule'**
  String get nouveauVehicule;

  /// No description provided for @parcAutomobilesVehicules.
  ///
  /// In fr, this message translates to:
  /// **'Parc Automobiles (Véhicules)'**
  String get parcAutomobilesVehicules;

  /// No description provided for @passerLeVehiculeEnReparation.
  ///
  /// In fr, this message translates to:
  /// **'Passer le vehicule en Reparation'**
  String get passerLeVehiculeEnReparation;

  /// No description provided for @prixCatalogue.
  ///
  /// In fr, this message translates to:
  /// **'Prix catalogue'**
  String get prixCatalogue;

  /// No description provided for @prixLocationJour.
  ///
  /// In fr, this message translates to:
  /// **'Prix location / jour'**
  String get prixLocationJour;

  /// No description provided for @rechercherClientTelephoneVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher (client, téléphone, véhicule…)'**
  String get rechercherClientTelephoneVehicule;

  /// No description provided for @rechercherUnVehiculeMarqueModeleImmatriculation.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un véhicule (marque, modèle, immatriculation...)'**
  String get rechercherUnVehiculeMarqueModeleImmatriculation;

  /// No description provided for @rechercherVehiculeOuClient.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher véhicule ou client…'**
  String get rechercherVehiculeOuClient;

  /// No description provided for @recupererLeVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Récupérer le véhicule'**
  String get recupererLeVehicule;

  /// No description provided for @remarquesObservations.
  ///
  /// In fr, this message translates to:
  /// **'Remarques / observations'**
  String get remarquesObservations;

  /// No description provided for @repartitionDuParc.
  ///
  /// In fr, this message translates to:
  /// **'Répartition du parc'**
  String get repartitionDuParc;

  /// No description provided for @retourVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Retour véhicule'**
  String get retourVehicule;

  /// No description provided for @selectionnerLeCatalogueDeVehicules.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner le catalogue de véhicules'**
  String get selectionnerLeCatalogueDeVehicules;

  /// No description provided for @selectionnerLeVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner le véhicule'**
  String get selectionnerLeVehicule;

  /// No description provided for @selectionnezLeTypeCorrespondantAuDommage.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez le type correspondant au dommage marqué'**
  String get selectionnezLeTypeCorrespondantAuDommage;

  /// No description provided for @seraDeduitDesRevenusDuVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Sera deduit des revenus du vehicule'**
  String get seraDeduitDesRevenusDuVehicule;

  /// No description provided for @toucherPourMarquer.
  ///
  /// In fr, this message translates to:
  /// **'Toucher pour marquer'**
  String get toucherPourMarquer;

  /// No description provided for @trajetParcouru.
  ///
  /// In fr, this message translates to:
  /// **'Trajet parcouru'**
  String get trajetParcouru;

  /// No description provided for @vehicule.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule'**
  String get vehicule;

  /// No description provided for @vehiculeAjouteAuStock.
  ///
  /// In fr, this message translates to:
  /// **'✅ Véhicule ajouté au stock !'**
  String get vehiculeAjouteAuStock;

  /// No description provided for @vehiculeCedeDuMagasin.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule cédé (du magasin)'**
  String get vehiculeCedeDuMagasin;

  /// No description provided for @vehiculeCible.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule ciblé'**
  String get vehiculeCible;

  /// No description provided for @vehiculeExistant.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule existant'**
  String get vehiculeExistant;

  /// No description provided for @vehiculeId.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule ID'**
  String get vehiculeId;

  /// No description provided for @vehiculePropose.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule proposé'**
  String get vehiculePropose;

  /// No description provided for @vehiculeReprisDuClient.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule repris (du client)'**
  String get vehiculeReprisDuClient;

  /// No description provided for @vehicules.
  ///
  /// In fr, this message translates to:
  /// **'Véhicules'**
  String get vehicules;

  /// No description provided for @aucuneInterruptionEnregistree.
  ///
  /// In fr, this message translates to:
  /// **'Aucune interruption enregistrée'**
  String get aucuneInterruptionEnregistree;

  /// No description provided for @aucuneLocationActive.
  ///
  /// In fr, this message translates to:
  /// **'Aucune location active'**
  String get aucuneLocationActive;

  /// No description provided for @aucuneLocationTrouvee.
  ///
  /// In fr, this message translates to:
  /// **'Aucune location trouvée.'**
  String get aucuneLocationTrouvee;

  /// No description provided for @aucuneRepartitionEnregistreePourCetteLocation.
  ///
  /// In fr, this message translates to:
  /// **'Aucune répartition enregistrée pour cette location.'**
  String get aucuneRepartitionEnregistreePourCetteLocation;

  /// No description provided for @cetteActionVaCreerUneLocation.
  ///
  /// In fr, this message translates to:
  /// **'Cette action va créer une location depuis cette réservation web.'**
  String get cetteActionVaCreerUneLocation;

  /// No description provided for @champCaution.
  ///
  /// In fr, this message translates to:
  /// **'Caution'**
  String get champCaution;

  /// No description provided for @champPrixJour.
  ///
  /// In fr, this message translates to:
  /// **'Prix / jour'**
  String get champPrixJour;

  /// No description provided for @conditionsGeneralesDeLocation.
  ///
  /// In fr, this message translates to:
  /// **'CONDITIONS GENERALES DE LOCATION'**
  String get conditionsGeneralesDeLocation;

  /// No description provided for @configurerLesMentionsLegalesLocationVente.
  ///
  /// In fr, this message translates to:
  /// **'Configurer les mentions légales (location, vente, échange)'**
  String get configurerLesMentionsLegalesLocationVente;

  /// No description provided for @contratDeLocation.
  ///
  /// In fr, this message translates to:
  /// **'CONTRAT DE LOCATION'**
  String get contratDeLocation;

  /// No description provided for @convertirEnLocation.
  ///
  /// In fr, this message translates to:
  /// **'Convertir en Location'**
  String get convertirEnLocation;

  /// No description provided for @creerLaLocation.
  ///
  /// In fr, this message translates to:
  /// **'Créer la location'**
  String get creerLaLocation;

  /// No description provided for @detailsDeLaLocation.
  ///
  /// In fr, this message translates to:
  /// **'Détails de la location'**
  String get detailsDeLaLocation;

  /// No description provided for @enLocation.
  ///
  /// In fr, this message translates to:
  /// **'En Location'**
  String get enLocation;

  /// No description provided for @erreurCreationLocationHistoriqueReponseInattendue.
  ///
  /// In fr, this message translates to:
  /// **'Erreur création location historique : réponse inattendue'**
  String get erreurCreationLocationHistoriqueReponseInattendue;

  /// No description provided for @erreurCreationLocationReponseInattendue.
  ///
  /// In fr, this message translates to:
  /// **'Erreur création location : réponse inattendue'**
  String get erreurCreationLocationReponseInattendue;

  /// No description provided for @gererLesInterruptions.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les interruptions'**
  String get gererLesInterruptions;

  /// No description provided for @interruptionAssurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance'**
  String get interruptionAssurance;

  /// No description provided for @interruptionAutre.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get interruptionAutre;

  /// No description provided for @interruptionReparation.
  ///
  /// In fr, this message translates to:
  /// **'Réparation'**
  String get interruptionReparation;

  /// No description provided for @interruptionVidange.
  ///
  /// In fr, this message translates to:
  /// **'Vidange'**
  String get interruptionVidange;

  /// No description provided for @interruptions.
  ///
  /// In fr, this message translates to:
  /// **'Interruptions'**
  String get interruptions;

  /// No description provided for @interruptionsDeContrat.
  ///
  /// In fr, this message translates to:
  /// **'Interruptions de contrat'**
  String get interruptionsDeContrat;

  /// No description provided for @journalDeBord.
  ///
  /// In fr, this message translates to:
  /// **'Journal de bord'**
  String get journalDeBord;

  /// No description provided for @journalDesReparations.
  ///
  /// In fr, this message translates to:
  /// **'Journal des réparations'**
  String get journalDesReparations;

  /// No description provided for @joursFacturables.
  ///
  /// In fr, this message translates to:
  /// **'Jours facturables'**
  String get joursFacturables;

  /// No description provided for @kmDepart.
  ///
  /// In fr, this message translates to:
  /// **'Km départ'**
  String get kmDepart;

  /// No description provided for @kmRetour.
  ///
  /// In fr, this message translates to:
  /// **'Km retour'**
  String get kmRetour;

  /// No description provided for @laLocationSeDerouleSansInterruption.
  ///
  /// In fr, this message translates to:
  /// **'La location se déroule sans interruption.'**
  String get laLocationSeDerouleSansInterruption;

  /// No description provided for @locationCreeeAvecSucces.
  ///
  /// In fr, this message translates to:
  /// **'✅ Location créée avec succès !'**
  String get locationCreeeAvecSucces;

  /// No description provided for @locationIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Location introuvable'**
  String get locationIntrouvable;

  /// No description provided for @locationSigneeBmwSerie3.
  ///
  /// In fr, this message translates to:
  /// **'Location signée - BMW Série 3'**
  String get locationSigneeBmwSerie3;

  /// No description provided for @modifierLaLocation.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la location'**
  String get modifierLaLocation;

  /// No description provided for @moyenneLocation.
  ///
  /// In fr, this message translates to:
  /// **'Moyenne / location'**
  String get moyenneLocation;

  /// No description provided for @nouvelleLocation.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle location'**
  String get nouvelleLocation;

  /// No description provided for @prixJour.
  ///
  /// In fr, this message translates to:
  /// **'Prix / jour'**
  String get prixJour;

  /// No description provided for @recapitulatifInterne.
  ///
  /// In fr, this message translates to:
  /// **'RÉCAPITULATIF INTERNE'**
  String get recapitulatifInterne;

  /// No description provided for @retenueCaution.
  ///
  /// In fr, this message translates to:
  /// **'Retenue caution'**
  String get retenueCaution;

  /// No description provided for @revenusLocatifs.
  ///
  /// In fr, this message translates to:
  /// **'Revenus locatifs'**
  String get revenusLocatifs;

  /// No description provided for @revenusLocations.
  ///
  /// In fr, this message translates to:
  /// **'Revenus locations'**
  String get revenusLocations;

  /// No description provided for @selectionnerLes50DernieresLocations.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner les 50 dernières locations'**
  String get selectionnerLes50DernieresLocations;

  /// No description provided for @selectionnezLeMemeClientPourDupliquer.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez le même client pour dupliquer la location'**
  String get selectionnezLeMemeClientPourDupliquer;

  /// No description provided for @supprimerLaLocation.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la location'**
  String get supprimerLaLocation;

  /// No description provided for @totalLocations.
  ///
  /// In fr, this message translates to:
  /// **'Total locations'**
  String get totalLocations;

  /// No description provided for @uniteJour.
  ///
  /// In fr, this message translates to:
  /// **'jour'**
  String get uniteJour;

  /// No description provided for @uniteJours.
  ///
  /// In fr, this message translates to:
  /// **'jours'**
  String get uniteJours;

  /// No description provided for @urgentMoinsDe7Jours.
  ///
  /// In fr, this message translates to:
  /// **'URGENT - moins de 7 jours'**
  String get urgentMoinsDe7Jours;

  /// No description provided for @adresseOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse (optionnel)'**
  String get adresseOptionnel;

  /// No description provided for @aucunClientEnregistre.
  ///
  /// In fr, this message translates to:
  /// **'Aucun client enregistré'**
  String get aucunClientEnregistre;

  /// No description provided for @champAdresse.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get champAdresse;

  /// No description provided for @champEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get champEmail;

  /// No description provided for @champTelephone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get champTelephone;

  /// No description provided for @clientEnregistre.
  ///
  /// In fr, this message translates to:
  /// **'Client enregistre'**
  String get clientEnregistre;

  /// No description provided for @clientIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Client introuvable'**
  String get clientIntrouvable;

  /// No description provided for @clientNormal.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get clientNormal;

  /// No description provided for @clientsrepositoryAucunShowroomSelectionne.
  ///
  /// In fr, this message translates to:
  /// **'ClientsRepository: Aucun showroom sélectionné.'**
  String get clientsrepositoryAucunShowroomSelectionne;

  /// No description provided for @complementClient.
  ///
  /// In fr, this message translates to:
  /// **'Complément client'**
  String get complementClient;

  /// No description provided for @dateDeRestitutionAuClient.
  ///
  /// In fr, this message translates to:
  /// **'Date de restitution au client'**
  String get dateDeRestitutionAuClient;

  /// No description provided for @documentInterneConfidentielNePasRemettre.
  ///
  /// In fr, this message translates to:
  /// **'DOCUMENT INTERNE — CONFIDENTIEL — Ne pas remettre au client'**
  String get documentInterneConfidentielNePasRemettre;

  /// No description provided for @emailOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Email (optionnel)'**
  String get emailOptionnel;

  /// No description provided for @gestionDesClients.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Clients'**
  String get gestionDesClients;

  /// No description provided for @leClient.
  ///
  /// In fr, this message translates to:
  /// **'Le Client'**
  String get leClient;

  /// No description provided for @nCni.
  ///
  /// In fr, this message translates to:
  /// **'N° CNI'**
  String get nCni;

  /// No description provided for @nPermis.
  ///
  /// In fr, this message translates to:
  /// **'N° Permis'**
  String get nPermis;

  /// No description provided for @noteInterne.
  ///
  /// In fr, this message translates to:
  /// **'Note interne'**
  String get noteInterne;

  /// No description provided for @nouveauClient.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau client'**
  String get nouveauClient;

  /// No description provided for @portefeuilleClients.
  ///
  /// In fr, this message translates to:
  /// **'Portefeuille Clients'**
  String get portefeuilleClients;

  /// No description provided for @rechercherUnClient.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un client...'**
  String get rechercherUnClient;

  /// No description provided for @restituerAuClient.
  ///
  /// In fr, this message translates to:
  /// **'Restituer au client'**
  String get restituerAuClient;

  /// No description provided for @selectionnerLeClient.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner le client'**
  String get selectionnerLeClient;

  /// No description provided for @telephone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get telephone;

  /// No description provided for @telephoneCopie.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone copié'**
  String get telephoneCopie;

  /// No description provided for @vosPermissionsAcces.
  ///
  /// In fr, this message translates to:
  /// **'Vos permissions accès'**
  String get vosPermissionsAcces;

  /// No description provided for @achatsVentes.
  ///
  /// In fr, this message translates to:
  /// **'Achats / Ventes'**
  String get achatsVentes;

  /// No description provided for @aucuneVenteEnregistree.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vente enregistrée'**
  String get aucuneVenteEnregistree;

  /// No description provided for @aucuneVenteTrouvee.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vente trouvée.'**
  String get aucuneVenteTrouvee;

  /// No description provided for @contratDeVente.
  ///
  /// In fr, this message translates to:
  /// **'CONTRAT DE VENTE'**
  String get contratDeVente;

  /// No description provided for @erreurLorsDeLaCreationDe.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création de la vente'**
  String get erreurLorsDeLaCreationDe;

  /// No description provided for @nouveauBonDeVente.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau bon de vente'**
  String get nouveauBonDeVente;

  /// No description provided for @nouvelleVente.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle vente'**
  String get nouvelleVente;

  /// No description provided for @prixDeVente.
  ///
  /// In fr, this message translates to:
  /// **'Prix de vente *'**
  String get prixDeVente;

  /// No description provided for @venteIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Vente introuvable'**
  String get venteIntrouvable;

  /// No description provided for @achatsReprises.
  ///
  /// In fr, this message translates to:
  /// **'Achats & Reprises'**
  String get achatsReprises;

  /// No description provided for @aucunEchangeEnregistre.
  ///
  /// In fr, this message translates to:
  /// **'Aucun échange enregistré'**
  String get aucunEchangeEnregistre;

  /// No description provided for @aucunEchangeTrouve.
  ///
  /// In fr, this message translates to:
  /// **'Aucun échange trouvé.'**
  String get aucunEchangeTrouve;

  /// No description provided for @changerLeType.
  ///
  /// In fr, this message translates to:
  /// **'Changer le type :'**
  String get changerLeType;

  /// No description provided for @dossierEchangeReprise.
  ///
  /// In fr, this message translates to:
  /// **'Dossier échange / reprise'**
  String get dossierEchangeReprise;

  /// No description provided for @echangeReprise.
  ///
  /// In fr, this message translates to:
  /// **'Échange / Reprise'**
  String get echangeReprise;

  /// No description provided for @echangesReprises.
  ///
  /// In fr, this message translates to:
  /// **'Échanges / Reprises'**
  String get echangesReprises;

  /// No description provided for @echangesrepositoryAucunShowroomSelectionne.
  ///
  /// In fr, this message translates to:
  /// **'EchangesRepository: Aucun showroom sélectionné.'**
  String get echangesrepositoryAucunShowroomSelectionne;

  /// No description provided for @nouvelAchatReprise.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel achat / reprise'**
  String get nouvelAchatReprise;

  /// No description provided for @nouvelEchange.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel échange'**
  String get nouvelEchange;

  /// No description provided for @observationsComplementaires.
  ///
  /// In fr, this message translates to:
  /// **'Observations complémentaires'**
  String get observationsComplementaires;

  /// No description provided for @propositionDeReprise.
  ///
  /// In fr, this message translates to:
  /// **'Proposition de reprise'**
  String get propositionDeReprise;

  /// No description provided for @reservationsAchatsEtEchangesDuSite.
  ///
  /// In fr, this message translates to:
  /// **'Réservations, achats et échanges du site'**
  String get reservationsAchatsEtEchangesDuSite;

  /// No description provided for @valeurReprise.
  ///
  /// In fr, this message translates to:
  /// **'Valeur reprise'**
  String get valeurReprise;

  /// No description provided for @achatIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Achat introuvable'**
  String get achatIntrouvable;

  /// No description provided for @aucunAchat.
  ///
  /// In fr, this message translates to:
  /// **'Aucun achat'**
  String get aucunAchat;

  /// No description provided for @aucunAchatEnregistre.
  ///
  /// In fr, this message translates to:
  /// **'Aucun achat enregistré'**
  String get aucunAchatEnregistre;

  /// No description provided for @aucunAchatValide.
  ///
  /// In fr, this message translates to:
  /// **'Aucun achat validé'**
  String get aucunAchatValide;

  /// No description provided for @dateAchat.
  ///
  /// In fr, this message translates to:
  /// **'Date achat'**
  String get dateAchat;

  /// No description provided for @detailAchat.
  ///
  /// In fr, this message translates to:
  /// **'Détail achat'**
  String get detailAchat;

  /// No description provided for @informationsVendeur.
  ///
  /// In fr, this message translates to:
  /// **'Informations vendeur'**
  String get informationsVendeur;

  /// No description provided for @negociation.
  ///
  /// In fr, this message translates to:
  /// **'Négociation'**
  String get negociation;

  /// No description provided for @nomDuVendeur.
  ///
  /// In fr, this message translates to:
  /// **'Nom du vendeur *'**
  String get nomDuVendeur;

  /// No description provided for @nouvelAchat.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel achat'**
  String get nouvelAchat;

  /// No description provided for @prixAccorde.
  ///
  /// In fr, this message translates to:
  /// **'Prix accordé *'**
  String get prixAccorde;

  /// No description provided for @totalAchats.
  ///
  /// In fr, this message translates to:
  /// **'Total achats'**
  String get totalAchats;

  /// No description provided for @aucuneOperationEnregistree.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération enregistrée'**
  String get aucuneOperationEnregistree;

  /// No description provided for @caisserepositoryAucunShowroomidTrouve.
  ///
  /// In fr, this message translates to:
  /// **'CaisseRepository: Aucun showroomId trouvé.'**
  String get caisserepositoryAucunShowroomidTrouve;

  /// No description provided for @dateDuVersement.
  ///
  /// In fr, this message translates to:
  /// **'Date du versement'**
  String get dateDuVersement;

  /// No description provided for @encaisse.
  ///
  /// In fr, this message translates to:
  /// **'Encaissé'**
  String get encaisse;

  /// No description provided for @entree.
  ///
  /// In fr, this message translates to:
  /// **'Entrée (+)'**
  String get entree;

  /// No description provided for @entrees.
  ///
  /// In fr, this message translates to:
  /// **'Entrées'**
  String get entrees;

  /// No description provided for @garageAutoReleveMensuel.
  ///
  /// In fr, this message translates to:
  /// **'Garage Auto - Releve mensuel'**
  String get garageAutoReleveMensuel;

  /// No description provided for @gestionDeCaisse.
  ///
  /// In fr, this message translates to:
  /// **'Gestion de Caisse'**
  String get gestionDeCaisse;

  /// No description provided for @gestionDeLaCaisse.
  ///
  /// In fr, this message translates to:
  /// **'Gestion de la Caisse'**
  String get gestionDeLaCaisse;

  /// No description provided for @msgSucces.
  ///
  /// In fr, this message translates to:
  /// **'Opération réussie'**
  String get msgSucces;

  /// No description provided for @nouveauVersement.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau versement'**
  String get nouveauVersement;

  /// No description provided for @nouvelleOperation.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle opération'**
  String get nouvelleOperation;

  /// No description provided for @rapportsReleves.
  ///
  /// In fr, this message translates to:
  /// **'Rapports & Relevés'**
  String get rapportsReleves;

  /// No description provided for @soldeEstime.
  ///
  /// In fr, this message translates to:
  /// **'Solde estimé'**
  String get soldeEstime;

  /// No description provided for @sortie.
  ///
  /// In fr, this message translates to:
  /// **'Sortie (-)'**
  String get sortie;

  /// No description provided for @supprimerCeVersement.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce versement ?'**
  String get supprimerCeVersement;

  /// No description provided for @totalEncaisse.
  ///
  /// In fr, this message translates to:
  /// **'Total encaissé'**
  String get totalEncaisse;

  /// No description provided for @caisseOperationSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Entrée ou sortie de la caisse du showroom'**
  String get caisseOperationSubtitle;

  /// No description provided for @transfertEntreUtilisateurs.
  ///
  /// In fr, this message translates to:
  /// **'Transfert entre utilisateurs'**
  String get transfertEntreUtilisateurs;

  /// No description provided for @transfertSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Un utilisateur donne de l\'argent à un autre'**
  String get transfertSubtitle;

  /// No description provided for @payePar.
  ///
  /// In fr, this message translates to:
  /// **'Payé par'**
  String get payePar;

  /// No description provided for @showroomCaisse.
  ///
  /// In fr, this message translates to:
  /// **'Showroom (caisse)'**
  String get showroomCaisse;

  /// No description provided for @aRembourser.
  ///
  /// In fr, this message translates to:
  /// **'(à rembourser)'**
  String get aRembourser;

  /// No description provided for @quiDonne.
  ///
  /// In fr, this message translates to:
  /// **'Qui donne'**
  String get quiDonne;

  /// No description provided for @quiRecoit.
  ///
  /// In fr, this message translates to:
  /// **'Qui reçoit'**
  String get quiRecoit;

  /// No description provided for @remboursable.
  ///
  /// In fr, this message translates to:
  /// **'Remboursable'**
  String get remboursable;

  /// No description provided for @transfertRemboursableSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le bénéficiaire devra rendre cet argent'**
  String get transfertRemboursableSubtitle;

  /// No description provided for @transfertDonSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Don définitif, aucun remboursement prévu'**
  String get transfertDonSubtitle;

  /// No description provided for @alerteAssurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance'**
  String get alerteAssurance;

  /// No description provided for @alerteCreee.
  ///
  /// In fr, this message translates to:
  /// **'Alerte creee'**
  String get alerteCreee;

  /// No description provided for @alertePneus.
  ///
  /// In fr, this message translates to:
  /// **'Pneus'**
  String get alertePneus;

  /// No description provided for @alerteVidange.
  ///
  /// In fr, this message translates to:
  /// **'Vidange'**
  String get alerteVidange;

  /// No description provided for @alerteVignette.
  ///
  /// In fr, this message translates to:
  /// **'Vignette'**
  String get alerteVignette;

  /// No description provided for @alertesGps.
  ///
  /// In fr, this message translates to:
  /// **'Alertes GPS'**
  String get alertesGps;

  /// No description provided for @aucuneAlerteD.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte d'**
  String get aucuneAlerteD;

  /// No description provided for @aucuneAlerteGpsToutesLesAlertes.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte GPS — toutes les alertes apparaîtront ici'**
  String get aucuneAlerteGpsToutesLesAlertes;

  /// No description provided for @aucuneReparationEnregistree.
  ///
  /// In fr, this message translates to:
  /// **'Aucune réparation enregistrée'**
  String get aucuneReparationEnregistree;

  /// No description provided for @carrosserieDepart.
  ///
  /// In fr, this message translates to:
  /// **'Carrosserie départ'**
  String get carrosserieDepart;

  /// No description provided for @carrosserieRetour.
  ///
  /// In fr, this message translates to:
  /// **'Carrosserie retour'**
  String get carrosserieRetour;

  /// No description provided for @depensesReparations.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses réparations'**
  String get depensesReparations;

  /// No description provided for @entretienPeriodique.
  ///
  /// In fr, this message translates to:
  /// **'Entretien periodique'**
  String get entretienPeriodique;

  /// No description provided for @entretienRevisions.
  ///
  /// In fr, this message translates to:
  /// **'Entretien & Révisions'**
  String get entretienRevisions;

  /// No description provided for @etatCarrosserie.
  ///
  /// In fr, this message translates to:
  /// **'État carrosserie'**
  String get etatCarrosserie;

  /// No description provided for @etatCarrosserieAuDepart.
  ///
  /// In fr, this message translates to:
  /// **'État carrosserie au départ'**
  String get etatCarrosserieAuDepart;

  /// No description provided for @etatCarrosserieAuRetour.
  ///
  /// In fr, this message translates to:
  /// **'État carrosserie au retour'**
  String get etatCarrosserieAuRetour;

  /// No description provided for @etatCarrosserieDepart.
  ///
  /// In fr, this message translates to:
  /// **'État carrosserie — Départ'**
  String get etatCarrosserieDepart;

  /// No description provided for @etatCarrosserieRetour.
  ///
  /// In fr, this message translates to:
  /// **'État carrosserie — Retour'**
  String get etatCarrosserieRetour;

  /// No description provided for @etatDeLaCarrosserie.
  ///
  /// In fr, this message translates to:
  /// **'ÉTAT DE LA CARROSSERIE'**
  String get etatDeLaCarrosserie;

  /// No description provided for @exPneuAvantUseJanteRayee.
  ///
  /// In fr, this message translates to:
  /// **'Ex: pneu avant usé, jante rayée…'**
  String get exPneuAvantUseJanteRayee;

  /// No description provided for @exPneuUseJanteRayee.
  ///
  /// In fr, this message translates to:
  /// **'Ex: pneu usé, jante rayée…'**
  String get exPneuUseJanteRayee;

  /// No description provided for @notificationsAlertes.
  ///
  /// In fr, this message translates to:
  /// **'Notifications & Alertes'**
  String get notificationsAlertes;

  /// No description provided for @nouvelleAlerte.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle alerte'**
  String get nouvelleAlerte;

  /// No description provided for @nouvelleReparation.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle reparation'**
  String get nouvelleReparation;

  /// No description provided for @prestataire.
  ///
  /// In fr, this message translates to:
  /// **'Prestataire'**
  String get prestataire;

  /// No description provided for @repCarrosserie.
  ///
  /// In fr, this message translates to:
  /// **'Carrosserie'**
  String get repCarrosserie;

  /// No description provided for @repMecanique.
  ///
  /// In fr, this message translates to:
  /// **'Mécanique'**
  String get repMecanique;

  /// No description provided for @repPneus.
  ///
  /// In fr, this message translates to:
  /// **'Pneus'**
  String get repPneus;

  /// No description provided for @reparationEnregistree.
  ///
  /// In fr, this message translates to:
  /// **'Reparation enregistree'**
  String get reparationEnregistree;

  /// No description provided for @reparations.
  ///
  /// In fr, this message translates to:
  /// **'Réparations'**
  String get reparations;

  /// No description provided for @reparationsrepositoryAucunShowroomSelectionne.
  ///
  /// In fr, this message translates to:
  /// **'ReparationsRepository: Aucun showroom sélectionné.'**
  String get reparationsrepositoryAucunShowroomSelectionne;

  /// No description provided for @totalDepensesReparations.
  ///
  /// In fr, this message translates to:
  /// **'Total dépenses réparations'**
  String get totalDepensesReparations;

  /// No description provided for @modifierReparation.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la réparation'**
  String get modifierReparation;

  /// No description provided for @requis.
  ///
  /// In fr, this message translates to:
  /// **'Requis'**
  String get requis;

  /// No description provided for @reste.
  ///
  /// In fr, this message translates to:
  /// **'Reste'**
  String get reste;

  /// No description provided for @depasse.
  ///
  /// In fr, this message translates to:
  /// **'Dépasse de'**
  String get depasse;

  /// No description provided for @enregistrementEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement...'**
  String get enregistrementEnCours;

  /// No description provided for @enregistrerModifications.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get enregistrerModifications;

  /// No description provided for @enregistrerReparation.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la réparation'**
  String get enregistrerReparation;

  /// No description provided for @payeePar.
  ///
  /// In fr, this message translates to:
  /// **'Payée par'**
  String get payeePar;

  /// No description provided for @payeur.
  ///
  /// In fr, this message translates to:
  /// **'Payeur'**
  String get payeur;

  /// No description provided for @doitSupporterMontant.
  ///
  /// In fr, this message translates to:
  /// **'Doit réellement supporter ce montant'**
  String get doitSupporterMontant;

  /// No description provided for @helperDebiteur.
  ///
  /// In fr, this message translates to:
  /// **'Si différent des copropriétaires, ce montant sera déduit de cette personne et remboursé au payeur.'**
  String get helperDebiteur;

  /// No description provided for @coProprietairesParDefaut.
  ///
  /// In fr, this message translates to:
  /// **'Copropriétaires du véhicule (par défaut)'**
  String get coProprietairesParDefaut;

  /// No description provided for @ajouterPayeur.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un payeur'**
  String get ajouterPayeur;

  /// No description provided for @choisirProprietairePaiement.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez le propriétaire pour chaque ligne de paiement.'**
  String get choisirProprietairePaiement;

  /// No description provided for @erreurSommePaiements.
  ///
  /// In fr, this message translates to:
  /// **'La somme des paiements ({somme} DA) doit être égale au coût total ({cout} DA).'**
  String erreurSommePaiements(String somme, String cout);

  /// No description provided for @reparationModifiee.
  ///
  /// In fr, this message translates to:
  /// **'Réparation modifiée'**
  String get reparationModifiee;

  /// No description provided for @apercuDuContrat.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu du contrat'**
  String get apercuDuContrat;

  /// No description provided for @apercuDuPdf.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu du PDF'**
  String get apercuDuPdf;

  /// No description provided for @articlesDesContrats.
  ///
  /// In fr, this message translates to:
  /// **'Articles des contrats'**
  String get articlesDesContrats;

  /// No description provided for @aucunArticleTrouve.
  ///
  /// In fr, this message translates to:
  /// **'Aucun article trouvé.'**
  String get aucunArticleTrouve;

  /// No description provided for @btnGenererPdf.
  ///
  /// In fr, this message translates to:
  /// **'Générer PDF'**
  String get btnGenererPdf;

  /// No description provided for @btnNouveauContrat.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contrat'**
  String get btnNouveauContrat;

  /// No description provided for @clausesArticlesDesContrats.
  ///
  /// In fr, this message translates to:
  /// **'Clauses & Articles des contrats'**
  String get clausesArticlesDesContrats;

  /// No description provided for @contratOuvertSansDateDeFin.
  ///
  /// In fr, this message translates to:
  /// **'Contrat ouvert (sans date de fin prévue)'**
  String get contratOuvertSansDateDeFin;

  /// No description provided for @contratsPdf.
  ///
  /// In fr, this message translates to:
  /// **'Contrats PDF'**
  String get contratsPdf;

  /// No description provided for @dateDeSignature.
  ///
  /// In fr, this message translates to:
  /// **'Date de signature'**
  String get dateDeSignature;

  /// No description provided for @documentCertifieKarossa.
  ///
  /// In fr, this message translates to:
  /// **'Document certifié - Karossa'**
  String get documentCertifieKarossa;

  /// No description provided for @documentGenereParKarossa.
  ///
  /// In fr, this message translates to:
  /// **'Document généré par Karossa'**
  String get documentGenereParKarossa;

  /// No description provided for @erreurLorsDuChargementDesContrats.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du chargement des contrats'**
  String get erreurLorsDuChargementDesContrats;

  /// No description provided for @exArticle1Responsabilites.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Article 1 — Responsabilités'**
  String get exArticle1Responsabilites;

  /// No description provided for @exporterPdf.
  ///
  /// In fr, this message translates to:
  /// **'Exporter PDF'**
  String get exporterPdf;

  /// No description provided for @garageAutoDocumentOfficiel.
  ///
  /// In fr, this message translates to:
  /// **'Garage Auto - Document officiel'**
  String get garageAutoDocumentOfficiel;

  /// No description provided for @genererContrat.
  ///
  /// In fr, this message translates to:
  /// **'Générer contrat'**
  String get genererContrat;

  /// No description provided for @genererEtPartagerLeContratPdf.
  ///
  /// In fr, this message translates to:
  /// **'Générer et partager le contrat PDF'**
  String get genererEtPartagerLeContratPdf;

  /// No description provided for @genererLeContratPdf.
  ///
  /// In fr, this message translates to:
  /// **'Générer le contrat PDF'**
  String get genererLeContratPdf;

  /// No description provided for @gestionDesClausesArticles.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des clauses (Articles)'**
  String get gestionDesClausesArticles;

  /// No description provided for @gestionDesDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Documents'**
  String get gestionDesDocuments;

  /// No description provided for @informationsInternesNonAfficheesDansLe.
  ///
  /// In fr, this message translates to:
  /// **'Informations internes non affichées dans le contrat'**
  String get informationsInternesNonAfficheesDansLe;

  /// No description provided for @langueDuContrat.
  ///
  /// In fr, this message translates to:
  /// **'Langue du contrat'**
  String get langueDuContrat;

  /// No description provided for @nouveauContrat.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contrat'**
  String get nouveauContrat;

  /// No description provided for @nouvelArticle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel article'**
  String get nouvelArticle;

  /// No description provided for @numeroDeContrat.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de contrat'**
  String get numeroDeContrat;

  /// No description provided for @optionsDuContrat.
  ///
  /// In fr, this message translates to:
  /// **'Options du contrat'**
  String get optionsDuContrat;

  /// No description provided for @partagerLePdf.
  ///
  /// In fr, this message translates to:
  /// **'Partager le PDF'**
  String get partagerLePdf;

  /// No description provided for @telechargerLePdf.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger le PDF'**
  String get telechargerLePdf;

  /// No description provided for @afficherLeTrajet.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le trajet'**
  String get afficherLeTrajet;

  /// No description provided for @analyseDeLaCarteGrise.
  ///
  /// In fr, this message translates to:
  /// **'Analyse de la carte grise...'**
  String get analyseDeLaCarteGrise;

  /// No description provided for @appuyezSurRafraichirPourChargerLa.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur rafraîchir pour charger la position.'**
  String get appuyezSurRafraichirPourChargerLa;

  /// No description provided for @carteFlotte.
  ///
  /// In fr, this message translates to:
  /// **'Carte flotte'**
  String get carteFlotte;

  /// No description provided for @carteGpsFlotte.
  ///
  /// In fr, this message translates to:
  /// **'Carte GPS — Flotte'**
  String get carteGpsFlotte;

  /// No description provided for @chargementDuTrajet.
  ///
  /// In fr, this message translates to:
  /// **'Chargement du trajet…'**
  String get chargementDuTrajet;

  /// No description provided for @choisirUnePhotoDeLaCarte.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo de la carte grise'**
  String get choisirUnePhotoDeLaCarte;

  /// No description provided for @clesApiGeminiFlespiEtCoordonnees.
  ///
  /// In fr, this message translates to:
  /// **'Clés API Gemini, Flespi et coordonnées'**
  String get clesApiGeminiFlespiEtCoordonnees;

  /// No description provided for @dernierePosition.
  ///
  /// In fr, this message translates to:
  /// **'Dernière position'**
  String get dernierePosition;

  /// No description provided for @flespiDeviceIdGps.
  ///
  /// In fr, this message translates to:
  /// **'Flespi Device ID (GPS)'**
  String get flespiDeviceIdGps;

  /// No description provided for @gpsFlotte.
  ///
  /// In fr, this message translates to:
  /// **'GPS — Flotte'**
  String get gpsFlotte;

  /// No description provided for @gpsPasserelleFlespi.
  ///
  /// In fr, this message translates to:
  /// **'GPS & Passerelle Flespi'**
  String get gpsPasserelleFlespi;

  /// No description provided for @motDePasseFlespi.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe Flespi'**
  String get motDePasseFlespi;

  /// No description provided for @positionGps.
  ///
  /// In fr, this message translates to:
  /// **'Position GPS'**
  String get positionGps;

  /// No description provided for @prendreEnPhotoLaCarteGrise.
  ///
  /// In fr, this message translates to:
  /// **'Prendre en photo la carte grise'**
  String get prendreEnPhotoLaCarteGrise;

  /// No description provided for @scannerCarteGrise.
  ///
  /// In fr, this message translates to:
  /// **'Scanner carte grise'**
  String get scannerCarteGrise;

  /// No description provided for @suiviGpsBalises.
  ///
  /// In fr, this message translates to:
  /// **'Suivi GPS & Balises'**
  String get suiviGpsBalises;

  /// No description provided for @tokenFlespi.
  ///
  /// In fr, this message translates to:
  /// **'Token Flespi'**
  String get tokenFlespi;

  /// No description provided for @urlFlespi.
  ///
  /// In fr, this message translates to:
  /// **'URL Flespi'**
  String get urlFlespi;

  /// No description provided for @utilisateurFlespi.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur Flespi'**
  String get utilisateurFlespi;

  /// No description provided for @supprimerDefinitivement.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement ?'**
  String get supprimerDefinitivement;

  /// No description provided for @confirmerDecimation.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la décimation ?'**
  String get confirmerDecimation;

  /// No description provided for @tousPointsGpsEntre.
  ///
  /// In fr, this message translates to:
  /// **'Tous les points GPS entre le'**
  String get tousPointsGpsEntre;

  /// No description provided for @etLe.
  ///
  /// In fr, this message translates to:
  /// **'et le'**
  String get etLe;

  /// No description provided for @serontSupprimesDefinitivement.
  ///
  /// In fr, this message translates to:
  /// **'seront supprimés définitivement'**
  String get serontSupprimesDefinitivement;

  /// No description provided for @pourTouteLaFlotte.
  ///
  /// In fr, this message translates to:
  /// **'pour TOUTE la flotte'**
  String get pourTouteLaFlotte;

  /// No description provided for @actionIrreversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get actionIrreversible;

  /// No description provided for @surCetIntervalle.
  ///
  /// In fr, this message translates to:
  /// **'Sur cet intervalle, un seul point sera conservé toutes les'**
  String get surCetIntervalle;

  /// No description provided for @autresPointsSupprimes.
  ///
  /// In fr, this message translates to:
  /// **'Les autres points seront supprimés définitivement.'**
  String get autresPointsSupprimes;

  /// No description provided for @decimer.
  ///
  /// In fr, this message translates to:
  /// **'Décimer'**
  String get decimer;

  /// No description provided for @enregistrementsSupprimes.
  ///
  /// In fr, this message translates to:
  /// **'{count} enregistrement(s) supprimé(s).'**
  String enregistrementsSupprimes(String count);

  /// No description provided for @nettoyageHistoriqueGps.
  ///
  /// In fr, this message translates to:
  /// **'Nettoyage historique GPS'**
  String get nettoyageHistoriqueGps;

  /// No description provided for @touteLaFlotte.
  ///
  /// In fr, this message translates to:
  /// **'Toute la flotte'**
  String get touteLaFlotte;

  /// No description provided for @intervalleDates.
  ///
  /// In fr, this message translates to:
  /// **'Intervalle de dates'**
  String get intervalleDates;

  /// No description provided for @action.
  ///
  /// In fr, this message translates to:
  /// **'Action'**
  String get action;

  /// No description provided for @decimerGarder1Point.
  ///
  /// In fr, this message translates to:
  /// **'Décimer (garder 1 point tous les X)'**
  String get decimerGarder1Point;

  /// No description provided for @decimerRecommandation.
  ///
  /// In fr, this message translates to:
  /// **'Recommandé — conserve la tendance des trajets'**
  String get decimerRecommandation;

  /// No description provided for @supprimerToutIntervalle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer tout sur l\'intervalle'**
  String get supprimerToutIntervalle;

  /// No description provided for @effaceCompletementPeriode.
  ///
  /// In fr, this message translates to:
  /// **'Efface complètement la période choisie'**
  String get effaceCompletementPeriode;

  /// No description provided for @lancerDecimation.
  ///
  /// In fr, this message translates to:
  /// **'Lancer la décimation'**
  String get lancerDecimation;

  /// No description provided for @gpsAccessDenied.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est réservée au gérant ou au propriétaire du showroom.'**
  String get gpsAccessDenied;

  /// No description provided for @gpsCleanupInfo.
  ///
  /// In fr, this message translates to:
  /// **'La table gps_positions peut grossir très vite (1 point / quelques secondes par véhicule). Utilise cette page pour libérer de l\'espace sans perdre la tendance générale des trajets (décimation), ou pour supprimer une plage précise.'**
  String get gpsCleanupInfo;

  /// No description provided for @administrateurPrincipal.
  ///
  /// In fr, this message translates to:
  /// **'Administrateur principal - Gère les configurations globales'**
  String get administrateurPrincipal;

  /// No description provided for @administrationShowroom.
  ///
  /// In fr, this message translates to:
  /// **'Administration Showroom'**
  String get administrationShowroom;

  /// No description provided for @ajouterUnUtilisateur.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un utilisateur...'**
  String get ajouterUnUtilisateur;

  /// No description provided for @aucunUtilisateurTrouve.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur trouvé'**
  String get aucunUtilisateurTrouve;

  /// No description provided for @bienvenueDansVotreGestionnaireDeShowroom.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue dans votre gestionnaire de showroom'**
  String get bienvenueDansVotreGestionnaireDeShowroom;

  /// No description provided for @cleApiGemini.
  ///
  /// In fr, this message translates to:
  /// **'Clé API Gemini'**
  String get cleApiGemini;

  /// No description provided for @configurationDuShowroom.
  ///
  /// In fr, this message translates to:
  /// **'Configuration du Showroom'**
  String get configurationDuShowroom;

  /// No description provided for @editionUtilisateur.
  ///
  /// In fr, this message translates to:
  /// **'Édition utilisateur...'**
  String get editionUtilisateur;

  /// No description provided for @geminiReponseVideCandidatesAbsent.
  ///
  /// In fr, this message translates to:
  /// **'Gemini: réponse vide (candidates absent)'**
  String get geminiReponseVideCandidatesAbsent;

  /// No description provided for @gererLesUtilisateurs.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les utilisateurs'**
  String get gererLesUtilisateurs;

  /// No description provided for @gestionDesUtilisateurs.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Utilisateurs'**
  String get gestionDesUtilisateurs;

  /// No description provided for @impossibleDeSauvegarderAucunShowroomActif.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de sauvegarder : aucun showroom actif détecté.'**
  String get impossibleDeSauvegarderAucunShowroomActif;

  /// No description provided for @karossaShowroom.
  ///
  /// In fr, this message translates to:
  /// **'Karossa Showroom'**
  String get karossaShowroom;

  /// No description provided for @modeSombre.
  ///
  /// In fr, this message translates to:
  /// **'Mode sombre'**
  String get modeSombre;

  /// No description provided for @nomDuShowroom.
  ///
  /// In fr, this message translates to:
  /// **'Nom du showroom'**
  String get nomDuShowroom;

  /// No description provided for @parametresDuShowroom.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres du showroom'**
  String get parametresDuShowroom;

  /// No description provided for @parametresSauvegardes.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres sauvegardés'**
  String get parametresSauvegardes;

  /// No description provided for @parametresSysteme.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres système'**
  String get parametresSysteme;

  /// No description provided for @showroomRattache.
  ///
  /// In fr, this message translates to:
  /// **'Showroom rattaché'**
  String get showroomRattache;

  /// No description provided for @typeDeCommission.
  ///
  /// In fr, this message translates to:
  /// **'Type de commission'**
  String get typeDeCommission;

  /// No description provided for @ajouterAuStock.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au Stock'**
  String get ajouterAuStock;

  /// No description provided for @ajouterPaiement.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter paiement'**
  String get ajouterPaiement;

  /// No description provided for @ajouterUnPaiement.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un paiement'**
  String get ajouterUnPaiement;

  /// No description provided for @btnAjouter.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get btnAjouter;

  /// No description provided for @btnConfirmer.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get btnConfirmer;

  /// No description provided for @btnCreer.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get btnCreer;

  /// No description provided for @btnEditer.
  ///
  /// In fr, this message translates to:
  /// **'Éditer'**
  String get btnEditer;

  /// No description provided for @btnEnregistrer.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get btnEnregistrer;

  /// No description provided for @btnExporter.
  ///
  /// In fr, this message translates to:
  /// **'Exporter'**
  String get btnExporter;

  /// No description provided for @btnFermer.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get btnFermer;

  /// No description provided for @btnModifier.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get btnModifier;

  /// No description provided for @btnNouveau.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau'**
  String get btnNouveau;

  /// No description provided for @btnPartager.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get btnPartager;

  /// No description provided for @btnRechercher.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get btnRechercher;

  /// No description provided for @btnReinitialiser.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get btnReinitialiser;

  /// No description provided for @btnRetour.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get btnRetour;

  /// No description provided for @btnSauvegarder.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder'**
  String get btnSauvegarder;

  /// No description provided for @btnSupprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get btnSupprimer;

  /// No description provided for @btnTelecharger.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get btnTelecharger;

  /// No description provided for @btnValider.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get btnValider;

  /// No description provided for @btnVoir.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get btnVoir;

  /// No description provided for @cetteActionEstIrreversibleConfirmer.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Confirmer ?'**
  String get cetteActionEstIrreversibleConfirmer;

  /// No description provided for @confirmerL.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer l'**
  String get confirmerL;

  /// No description provided for @confirmerLeRejetDeCetteDemande.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le rejet de cette demande ?'**
  String get confirmerLeRejetDeCetteDemande;

  /// No description provided for @dateRetourReelle.
  ///
  /// In fr, this message translates to:
  /// **'Date retour réelle'**
  String get dateRetourReelle;

  /// No description provided for @dateRetourReelleOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Date retour réelle (optionnel)'**
  String get dateRetourReelleOptionnel;

  /// No description provided for @detailsDuRetour.
  ///
  /// In fr, this message translates to:
  /// **'Détails du retour'**
  String get detailsDuRetour;

  /// No description provided for @enregistrer.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get enregistrer;

  /// No description provided for @enregistrerLeRetour.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le retour'**
  String get enregistrerLeRetour;

  /// No description provided for @essayezDeModifierLesFiltres.
  ///
  /// In fr, this message translates to:
  /// **'Essayez de modifier les filtres'**
  String get essayezDeModifierLesFiltres;

  /// No description provided for @exporterCsv.
  ///
  /// In fr, this message translates to:
  /// **'Exporter CSV'**
  String get exporterCsv;

  /// No description provided for @informationsDeRetour.
  ///
  /// In fr, this message translates to:
  /// **'Informations de retour'**
  String get informationsDeRetour;

  /// No description provided for @kmAuRetour.
  ///
  /// In fr, this message translates to:
  /// **'Km au retour'**
  String get kmAuRetour;

  /// No description provided for @observationsAuRetour.
  ///
  /// In fr, this message translates to:
  /// **'Observations au retour'**
  String get observationsAuRetour;

  /// No description provided for @reinitialiser.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get reinitialiser;

  /// No description provided for @resteAPercevoir.
  ///
  /// In fr, this message translates to:
  /// **'Reste à percevoir'**
  String get resteAPercevoir;

  /// No description provided for @retourConformeDeLaGolf8.
  ///
  /// In fr, this message translates to:
  /// **'Retour conforme de la Golf 8'**
  String get retourConformeDeLaGolf8;

  /// No description provided for @retourEnregistreAvecSucces.
  ///
  /// In fr, this message translates to:
  /// **'Retour enregistré avec succès.'**
  String get retourEnregistreAvecSucces;

  /// No description provided for @retourPrevu.
  ///
  /// In fr, this message translates to:
  /// **'Retour prévu'**
  String get retourPrevu;

  /// No description provided for @retourReel.
  ///
  /// In fr, this message translates to:
  /// **'Retour réel'**
  String get retourReel;

  /// No description provided for @sauvegarder.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder'**
  String get sauvegarder;

  /// No description provided for @supprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ?'**
  String get supprimer;

  /// No description provided for @supprimerCeDommage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce dommage'**
  String get supprimerCeDommage;

  /// No description provided for @supprimerCePaiement.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce paiement'**
  String get supprimerCePaiement;

  /// No description provided for @supprimerLaDemande.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la demande'**
  String get supprimerLaDemande;

  /// No description provided for @voirLaFacture.
  ///
  /// In fr, this message translates to:
  /// **'Voir la facture'**
  String get voirLaFacture;

  /// No description provided for @voirTout.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get voirTout;

  /// No description provided for @voulezVousVraimentFermerVotreSession.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment fermer votre session Karossa ?'**
  String get voulezVousVraimentFermerVotreSession;

  /// No description provided for @champDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get champDate;

  /// No description provided for @champDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get champDescription;

  /// No description provided for @champMontant.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get champMontant;

  /// No description provided for @champNom.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get champNom;

  /// No description provided for @champNotes.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get champNotes;

  /// No description provided for @champPrenom.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get champPrenom;

  /// No description provided for @msgChampsObligatoires.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez remplir tous les champs obligatoires'**
  String get msgChampsObligatoires;

  /// No description provided for @uniteDa.
  ///
  /// In fr, this message translates to:
  /// **'DA'**
  String get uniteDa;

  /// No description provided for @uniteDzd.
  ///
  /// In fr, this message translates to:
  /// **'DZD'**
  String get uniteDzd;

  /// No description provided for @uniteKm.
  ///
  /// In fr, this message translates to:
  /// **'km'**
  String get uniteKm;

  /// No description provided for @utilisezVariablePourLesChampsDynamiques.
  ///
  /// In fr, this message translates to:
  /// **'Utilisez {variable} pour les champs dynamiques'**
  String utilisezVariablePourLesChampsDynamiques(Object variable);

  /// No description provided for @aucunFiltre.
  ///
  /// In fr, this message translates to:
  /// **'Aucun filtre'**
  String get aucunFiltre;

  /// No description provided for @aucunImpactConstate.
  ///
  /// In fr, this message translates to:
  /// **'Aucun impact constaté'**
  String get aucunImpactConstate;

  /// No description provided for @aucunPaiementEnregistre.
  ///
  /// In fr, this message translates to:
  /// **'Aucun paiement enregistré'**
  String get aucunPaiementEnregistre;

  /// No description provided for @aucuneDemandeTrouvee.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande trouvée'**
  String get aucuneDemandeTrouvee;

  /// No description provided for @aucuneTransactionCeMoisCi.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction ce mois-ci'**
  String get aucuneTransactionCeMoisCi;

  /// No description provided for @deconnexion.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get deconnexion;

  /// No description provided for @demandeSupprimee.
  ///
  /// In fr, this message translates to:
  /// **'Demande supprimée.'**
  String get demandeSupprimee;

  /// No description provided for @erreurDeSynchronisation.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de synchronisation'**
  String get erreurDeSynchronisation;

  /// No description provided for @fonctionnaliteDeTelechargementAImplementer.
  ///
  /// In fr, this message translates to:
  /// **'Fonctionnalité de téléchargement à implémenter'**
  String get fonctionnaliteDeTelechargementAImplementer;

  /// No description provided for @idInvalide.
  ///
  /// In fr, this message translates to:
  /// **'ID invalide'**
  String get idInvalide;

  /// No description provided for @impossibleDeChargerLesNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les notifications'**
  String get impossibleDeChargerLesNotifications;

  /// No description provided for @impossibleDeContacterLia.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de contacter le serveur IA'**
  String get impossibleDeContacterLia;

  /// No description provided for @impossibleDeRecupererLesDonneesFinancieres.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de récupérer les données financières du backend'**
  String get impossibleDeRecupererLesDonneesFinancieres;

  /// No description provided for @msgAucunResultat.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat trouvé'**
  String get msgAucunResultat;

  /// No description provided for @msgChargement.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get msgChargement;

  /// No description provided for @msgConfirmationSuppression.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la suppression'**
  String get msgConfirmationSuppression;

  /// No description provided for @msgConnexionRequise.
  ///
  /// In fr, this message translates to:
  /// **'Connexion requise'**
  String get msgConnexionRequise;

  /// No description provided for @msgErreurGenerale.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get msgErreurGenerale;

  /// No description provided for @msgSuppressionIrreversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get msgSuppressionIrreversible;

  /// No description provided for @photoAjouteeAvecSucces.
  ///
  /// In fr, this message translates to:
  /// **'Photo ajoutée avec succès'**
  String get photoAjouteeAvecSucces;

  /// No description provided for @profilIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Profil introuvable'**
  String get profilIntrouvable;

  /// No description provided for @accepte.
  ///
  /// In fr, this message translates to:
  /// **'Accepté'**
  String get accepte;

  /// No description provided for @activiteRecente.
  ///
  /// In fr, this message translates to:
  /// **'Activité récente'**
  String get activiteRecente;

  /// No description provided for @actualiserLesFiches.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser les fiches'**
  String get actualiserLesFiches;

  /// No description provided for @analyseFinanciere.
  ///
  /// In fr, this message translates to:
  /// **'Analyse financière'**
  String get analyseFinanciere;

  /// No description provided for @approuve.
  ///
  /// In fr, this message translates to:
  /// **'Approuvé'**
  String get approuve;

  /// No description provided for @approuvees.
  ///
  /// In fr, this message translates to:
  /// **'Approuvées'**
  String get approuvees;

  /// No description provided for @arrivee.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée'**
  String get arrivee;

  /// No description provided for @assistantVirtuelIa.
  ///
  /// In fr, this message translates to:
  /// **'Assistant Virtuel IA'**
  String get assistantVirtuelIa;

  /// No description provided for @bilanFinancier.
  ///
  /// In fr, this message translates to:
  /// **'Bilan financier'**
  String get bilanFinancier;

  /// No description provided for @budgetMax.
  ///
  /// In fr, this message translates to:
  /// **'Budget max'**
  String get budgetMax;

  /// No description provided for @categorie.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get categorie;

  /// No description provided for @ceMois.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois'**
  String get ceMois;

  /// No description provided for @choisissezUnIntervalleDeDates.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un intervalle de dates'**
  String get choisissezUnIntervalleDeDates;

  /// No description provided for @comparatifAnnuelDa.
  ///
  /// In fr, this message translates to:
  /// **'Comparatif Annuel (DA)'**
  String get comparatifAnnuelDa;

  /// No description provided for @conditionsGenerale.
  ///
  /// In fr, this message translates to:
  /// **'- Conditions Générale :'**
  String get conditionsGenerale;

  /// No description provided for @connectezVousAVotreCompte.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à votre compte'**
  String get connectezVousAVotreCompte;

  /// No description provided for @coordonnees.
  ///
  /// In fr, this message translates to:
  /// **'Coordonnées'**
  String get coordonnees;

  /// No description provided for @coutTotal.
  ///
  /// In fr, this message translates to:
  /// **'Cout total'**
  String get coutTotal;

  /// No description provided for @date.
  ///
  /// In fr, this message translates to:
  /// **'Date : _______________'**
  String get date;

  /// No description provided for @dateDeRecuperation.
  ///
  /// In fr, this message translates to:
  /// **'Date de récupération'**
  String get dateDeRecuperation;

  /// No description provided for @dateDepart.
  ///
  /// In fr, this message translates to:
  /// **'Date départ'**
  String get dateDepart;

  /// No description provided for @datesDeReservationManquantes.
  ///
  /// In fr, this message translates to:
  /// **'Dates de réservation manquantes.'**
  String get datesDeReservationManquantes;

  /// No description provided for @deduireDuProfitAvantRepartition.
  ///
  /// In fr, this message translates to:
  /// **'Deduire du profit avant repartition'**
  String get deduireDuProfitAvantRepartition;

  /// No description provided for @definissezLeTauxParDefautPre.
  ///
  /// In fr, this message translates to:
  /// **'Définissez le taux par défaut pré-rempli dans chaque formulaire.'**
  String get definissezLeTauxParDefautPre;

  /// No description provided for @dejaVerse.
  ///
  /// In fr, this message translates to:
  /// **'Déjà versé'**
  String get dejaVerse;

  /// No description provided for @demandeDeDevis.
  ///
  /// In fr, this message translates to:
  /// **'Demande de devis'**
  String get demandeDeDevis;

  /// No description provided for @demanderAKarossaai.
  ///
  /// In fr, this message translates to:
  /// **'Demander à KarossaAI...'**
  String get demanderAKarossaai;

  /// No description provided for @demandesWebLeads.
  ///
  /// In fr, this message translates to:
  /// **'Demandes Web & Leads'**
  String get demandesWebLeads;

  /// No description provided for @depart.
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get depart;

  /// No description provided for @depenseTotale.
  ///
  /// In fr, this message translates to:
  /// **'Dépense totale'**
  String get depenseTotale;

  /// No description provided for @depenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get depenses;

  /// No description provided for @description.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @detacherLeContexteActuel.
  ///
  /// In fr, this message translates to:
  /// **'Détacher le contexte actuel'**
  String get detacherLeContexteActuel;

  /// No description provided for @detail.
  ///
  /// In fr, this message translates to:
  /// **'Détail'**
  String get detail;

  /// No description provided for @detailsFinanciers.
  ///
  /// In fr, this message translates to:
  /// **'DETAILS FINANCIERS'**
  String get detailsFinanciers;

  /// No description provided for @devisePrincipale.
  ///
  /// In fr, this message translates to:
  /// **'Devise principale'**
  String get devisePrincipale;

  /// No description provided for @diagnosticRlsConsole.
  ///
  /// In fr, this message translates to:
  /// **'Diagnostic RLS (console)'**
  String get diagnosticRlsConsole;

  /// No description provided for @dinarAlgerienFixeDzd.
  ///
  /// In fr, this message translates to:
  /// **'Dinar algérien fixe (DZD)'**
  String get dinarAlgerienFixeDzd;

  /// No description provided for @dommagesPannesAnomaliesOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Dommages / pannes / anomalies (optionnel)'**
  String get dommagesPannesAnomaliesOptionnel;

  /// No description provided for @duree.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get duree;

  /// No description provided for @dzdDa.
  ///
  /// In fr, this message translates to:
  /// **'DZD (DA)'**
  String get dzdDa;

  /// No description provided for @economieNegociee.
  ///
  /// In fr, this message translates to:
  /// **'Économie négociée'**
  String get economieNegociee;

  /// No description provided for @enAtelier.
  ///
  /// In fr, this message translates to:
  /// **'En Atelier'**
  String get enAtelier;

  /// No description provided for @enAttente.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get enAttente;

  /// No description provided for @enEvaluation.
  ///
  /// In fr, this message translates to:
  /// **'En évaluation'**
  String get enEvaluation;

  /// No description provided for @etesVousSurDeVouloirVous.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir vous déconnecter ?'**
  String get etesVousSurDeVouloirVous;

  /// No description provided for @exRayureSurAileAvantGauche.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Rayure sur aile avant gauche, climatisation en panne, rétroviseur droit fissuré…'**
  String get exRayureSurAileAvantGauche;

  /// No description provided for @exRevision60000KmChez.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Révision 60 000 km chez garage Dupont'**
  String get exRevision60000KmChez;

  /// No description provided for @filtresActifs.
  ///
  /// In fr, this message translates to:
  /// **'Filtres actifs'**
  String get filtresActifs;

  /// No description provided for @filtresAvances.
  ///
  /// In fr, this message translates to:
  /// **'Filtres avancés'**
  String get filtresAvances;

  /// No description provided for @fonctionnaliteDePartageAImplementer.
  ///
  /// In fr, this message translates to:
  /// **'Fonctionnalité de partage à implémenter'**
  String get fonctionnaliteDePartageAImplementer;

  /// No description provided for @garageAuto.
  ///
  /// In fr, this message translates to:
  /// **'Garage Auto'**
  String get garageAuto;

  /// No description provided for @generationDesMetriquesKarossa.
  ///
  /// In fr, this message translates to:
  /// **'Génération des métriques Karossa...'**
  String get generationDesMetriquesKarossa;

  /// No description provided for @impactFinancier.
  ///
  /// In fr, this message translates to:
  /// **'Impact financier'**
  String get impactFinancier;

  /// No description provided for @informationsDeContact.
  ///
  /// In fr, this message translates to:
  /// **'Informations de contact'**
  String get informationsDeContact;

  /// No description provided for @informationsGenerales.
  ///
  /// In fr, this message translates to:
  /// **'Informations générales'**
  String get informationsGenerales;

  /// No description provided for @injecterDesDonneesDeGestion.
  ///
  /// In fr, this message translates to:
  /// **'Injecter des données de gestion'**
  String get injecterDesDonneesDeGestion;

  /// No description provided for @intelligenceArtificielle.
  ///
  /// In fr, this message translates to:
  /// **'Intelligence Artificielle'**
  String get intelligenceArtificielle;

  /// No description provided for @kmAuDepart.
  ///
  /// In fr, this message translates to:
  /// **'Km au départ'**
  String get kmAuDepart;

  /// No description provided for @kmAuMoment.
  ///
  /// In fr, this message translates to:
  /// **'Km au moment'**
  String get kmAuMoment;

  /// No description provided for @laDateDeDebutDoitEtre.
  ///
  /// In fr, this message translates to:
  /// **'La date de début doit être avant la date de fin.'**
  String get laDateDeDebutDoitEtre;

  /// No description provided for @laSommeDesPartsDoitEtre.
  ///
  /// In fr, this message translates to:
  /// **'La somme des parts doit etre egale a 100%'**
  String get laSommeDesPartsDoitEtre;

  /// No description provided for @listeNoire.
  ///
  /// In fr, this message translates to:
  /// **'Liste noire'**
  String get listeNoire;

  /// No description provided for @logsDeDiagnosticEcritsDansLa.
  ///
  /// In fr, this message translates to:
  /// **'🔍 Logs de diagnostic écrits dans la console Flutter'**
  String get logsDeDiagnosticEcritsDansLa;

  /// No description provided for @modeDePaiement.
  ///
  /// In fr, this message translates to:
  /// **'Mode de paiement'**
  String get modeDePaiement;

  /// No description provided for @modeMixte.
  ///
  /// In fr, this message translates to:
  /// **'Mixte'**
  String get modeMixte;

  /// No description provided for @monProfil.
  ///
  /// In fr, this message translates to:
  /// **'Mon Profil'**
  String get monProfil;

  /// No description provided for @montantBrut.
  ///
  /// In fr, this message translates to:
  /// **'Montant brut'**
  String get montantBrut;

  /// No description provided for @montantDa.
  ///
  /// In fr, this message translates to:
  /// **'Montant (DA)'**
  String get montantDa;

  /// No description provided for @montantDeduit.
  ///
  /// In fr, this message translates to:
  /// **'Montant déduit'**
  String get montantDeduit;

  /// No description provided for @montantFacturable.
  ///
  /// In fr, this message translates to:
  /// **'Montant facturable'**
  String get montantFacturable;

  /// No description provided for @montantFixeDa.
  ///
  /// In fr, this message translates to:
  /// **'Montant fixe (DA)'**
  String get montantFixeDa;

  /// No description provided for @motDePasse.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get motDePasse;

  /// No description provided for @noteOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Note (optionnel)'**
  String get noteOptionnel;

  /// No description provided for @notesInternesOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Notes internes (optionnel)'**
  String get notesInternesOptionnel;

  /// No description provided for @notesOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Notes (optionnel)'**
  String get notesOptionnel;

  /// No description provided for @notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @observations.
  ///
  /// In fr, this message translates to:
  /// **'Observations'**
  String get observations;

  /// No description provided for @offreFaite.
  ///
  /// In fr, this message translates to:
  /// **'Offre faite'**
  String get offreFaite;

  /// No description provided for @paiementsRecus.
  ///
  /// In fr, this message translates to:
  /// **'Paiements reçus'**
  String get paiementsRecus;

  /// No description provided for @pasDeDateDeFin.
  ///
  /// In fr, this message translates to:
  /// **'Pas de date de fin'**
  String get pasDeDateDeFin;

  /// No description provided for @periode.
  ///
  /// In fr, this message translates to:
  /// **'Période'**
  String get periode;

  /// No description provided for @personnalise.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get personnalise;

  /// No description provided for @pourcentage.
  ///
  /// In fr, this message translates to:
  /// **'Pourcentage (%)'**
  String get pourcentage;

  /// No description provided for @preferencesSysteme.
  ///
  /// In fr, this message translates to:
  /// **'Préférences & Système'**
  String get preferencesSysteme;

  /// No description provided for @prixDemande.
  ///
  /// In fr, this message translates to:
  /// **'Prix demandé'**
  String get prixDemande;

  /// No description provided for @prixMaxDa.
  ///
  /// In fr, this message translates to:
  /// **'Prix max (DA)'**
  String get prixMaxDa;

  /// No description provided for @prixPaiement.
  ///
  /// In fr, this message translates to:
  /// **'Prix & paiement'**
  String get prixPaiement;

  /// No description provided for @prixSouhaite.
  ///
  /// In fr, this message translates to:
  /// **'Prix souhaité'**
  String get prixSouhaite;

  /// No description provided for @rafraichir.
  ///
  /// In fr, this message translates to:
  /// **'Rafraîchir'**
  String get rafraichir;

  /// No description provided for @rafraichirMaintenant.
  ///
  /// In fr, this message translates to:
  /// **'Rafraîchir maintenant'**
  String get rafraichirMaintenant;

  /// No description provided for @reessayer.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get reessayer;

  /// No description provided for @registreDuCommerceRc.
  ///
  /// In fr, this message translates to:
  /// **'Registre du commerce (RC)'**
  String get registreDuCommerceRc;

  /// No description provided for @rejetees.
  ///
  /// In fr, this message translates to:
  /// **'Rejetées'**
  String get rejetees;

  /// No description provided for @repAutre.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get repAutre;

  /// No description provided for @repartitionDesGains.
  ///
  /// In fr, this message translates to:
  /// **'Répartition des gains'**
  String get repartitionDesGains;

  /// No description provided for @resume.
  ///
  /// In fr, this message translates to:
  /// **'Résumé'**
  String get resume;

  /// No description provided for @resumeFinancier.
  ///
  /// In fr, this message translates to:
  /// **'Résumé financier'**
  String get resumeFinancier;

  /// No description provided for @revenuTotal.
  ///
  /// In fr, this message translates to:
  /// **'Revenu total'**
  String get revenuTotal;

  /// No description provided for @revenusVsDepenses.
  ///
  /// In fr, this message translates to:
  /// **'Revenus vs Dépenses'**
  String get revenusVsDepenses;

  /// No description provided for @seConnecter.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get seConnecter;

  /// No description provided for @seDeconnecter.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get seDeconnecter;

  /// No description provided for @statistiques.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get statistiques;

  /// No description provided for @tauxOccupation.
  ///
  /// In fr, this message translates to:
  /// **'Taux Occupation'**
  String get tauxOccupation;

  /// No description provided for @totalBrut.
  ///
  /// In fr, this message translates to:
  /// **'Total brut'**
  String get totalBrut;

  /// No description provided for @totalGenere.
  ///
  /// In fr, this message translates to:
  /// **'Total généré'**
  String get totalGenere;

  /// No description provided for @totalReparti.
  ///
  /// In fr, this message translates to:
  /// **'TOTAL réparti'**
  String get totalReparti;

  /// No description provided for @tousLesTypes.
  ///
  /// In fr, this message translates to:
  /// **'Tous les types'**
  String get tousLesTypes;

  /// No description provided for @toutEffacer.
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get toutEffacer;

  /// No description provided for @toutEstEnOrdre.
  ///
  /// In fr, this message translates to:
  /// **'Tout est en ordre 👍'**
  String get toutEstEnOrdre;

  /// No description provided for @toutRafraichir.
  ///
  /// In fr, this message translates to:
  /// **'Tout rafraîchir'**
  String get toutRafraichir;

  /// No description provided for @toutesLesCategories.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les catégories'**
  String get toutesLesCategories;

  /// No description provided for @toutesLesFiches.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les fiches'**
  String get toutesLesFiches;

  /// No description provided for @typeD.
  ///
  /// In fr, this message translates to:
  /// **'Type d'**
  String get typeD;

  /// No description provided for @typeDeDommage.
  ///
  /// In fr, this message translates to:
  /// **'Type de dommage'**
  String get typeDeDommage;

  /// No description provided for @urlDuLogo.
  ///
  /// In fr, this message translates to:
  /// **'URL du Logo'**
  String get urlDuLogo;

  /// No description provided for @urlSupabaseStorageNulle.
  ///
  /// In fr, this message translates to:
  /// **'URL Supabase Storage nulle.'**
  String get urlSupabaseStorageNulle;

  /// No description provided for @valeursFinancieres.
  ///
  /// In fr, this message translates to:
  /// **'Valeurs financières'**
  String get valeursFinancieres;

  /// No description provided for @valides.
  ///
  /// In fr, this message translates to:
  /// **'Validés'**
  String get valides;

  /// No description provided for @aiEffacerHistorique.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'historique'**
  String get aiEffacerHistorique;

  /// No description provided for @aiContextualiserAssistant.
  ///
  /// In fr, this message translates to:
  /// **'Contextualiser l\'assistant avec la BDD'**
  String get aiContextualiserAssistant;

  /// No description provided for @aiAnalyseEtatGlobalParc.
  ///
  /// In fr, this message translates to:
  /// **'Analyse de l\'état global du parc automobile'**
  String get aiAnalyseEtatGlobalParc;

  /// No description provided for @aiNLocationsRecentes.
  ///
  /// In fr, this message translates to:
  /// **'{count} locations récentes'**
  String aiNLocationsRecentes(String count);

  /// No description provided for @aiCatalogueNVehicules.
  ///
  /// In fr, this message translates to:
  /// **'Catalogue ({count} véhicules)'**
  String aiCatalogueNVehicules(String count);

  /// No description provided for @aiContratsChargesContexte.
  ///
  /// In fr, this message translates to:
  /// **'✅ {count} contrats chargés dans le contexte.'**
  String aiContratsChargesContexte(String count);

  /// No description provided for @aiVehiculesSynchronisesKarossa.
  ///
  /// In fr, this message translates to:
  /// **'✅ {count} véhicules synchronisés avec KarossaAI.'**
  String aiVehiculesSynchronisesKarossa(String count);

  /// No description provided for @erreurAvecDetail.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String erreurAvecDetail(String error);

  /// No description provided for @erreurChargementMessage.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement : {message}'**
  String erreurChargementMessage(String message);

  /// No description provided for @erreurSuppression.
  ///
  /// In fr, this message translates to:
  /// **'Erreur suppression : {error}'**
  String erreurSuppression(String error);

  /// No description provided for @erreurConversion.
  ///
  /// In fr, this message translates to:
  /// **'Erreur conversion : {error}'**
  String erreurConversion(String error);

  /// No description provided for @contratGenereAvecSucces.
  ///
  /// In fr, this message translates to:
  /// **'Contrat généré avec succès'**
  String get contratGenereAvecSucces;

  /// No description provided for @clientInconnu.
  ///
  /// In fr, this message translates to:
  /// **'Client inconnu'**
  String get clientInconnu;

  /// No description provided for @vehiculeInconnu.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule inconnu'**
  String get vehiculeInconnu;

  /// No description provided for @oui.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get oui;

  /// No description provided for @non.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get non;

  /// No description provided for @champTitre.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get champTitre;

  /// No description provided for @champCorps.
  ///
  /// In fr, this message translates to:
  /// **'Corps'**
  String get champCorps;

  /// No description provided for @modifierArticle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'article'**
  String get modifierArticle;

  /// No description provided for @modifierChamp.
  ///
  /// In fr, this message translates to:
  /// **'Modifier — {label}'**
  String modifierChamp(String label);

  /// No description provided for @langue.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get langue;

  /// No description provided for @champValeur.
  ///
  /// In fr, this message translates to:
  /// **'Valeur'**
  String get champValeur;

  /// No description provided for @modeleIaLabel.
  ///
  /// In fr, this message translates to:
  /// **'Modèle IA (gemini_model)'**
  String get modeleIaLabel;

  /// No description provided for @commissionPourLabel.
  ///
  /// In fr, this message translates to:
  /// **'Commission — {label}'**
  String commissionPourLabel(String label);

  /// No description provided for @commissionVente.
  ///
  /// In fr, this message translates to:
  /// **'Vente'**
  String get commissionVente;

  /// No description provided for @commissionLocation.
  ///
  /// In fr, this message translates to:
  /// **'Location'**
  String get commissionLocation;

  /// No description provided for @commissionAchat.
  ///
  /// In fr, this message translates to:
  /// **'Achat'**
  String get commissionAchat;

  /// No description provided for @commissionEchange.
  ///
  /// In fr, this message translates to:
  /// **'Échange'**
  String get commissionEchange;

  /// No description provided for @gererLequipe.
  ///
  /// In fr, this message translates to:
  /// **'Gérer l\'équipe'**
  String get gererLequipe;

  /// No description provided for @clesApiGeminiEtFlespi.
  ///
  /// In fr, this message translates to:
  /// **'Clés API Gemini, Flespi et coordonnées'**
  String get clesApiGeminiEtFlespi;

  /// No description provided for @voulezVousVraimentFermerSession.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment fermer votre session Karossa ?'**
  String get voulezVousVraimentFermerSession;

  /// No description provided for @contratOuvert.
  ///
  /// In fr, this message translates to:
  /// **'Contrat ouvert'**
  String get contratOuvert;

  /// No description provided for @suppressionInterruption.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'interruption ?'**
  String get suppressionInterruption;

  /// No description provided for @joursSerontRecalculesAuto.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Les jours seront recalculés automatiquement.'**
  String get joursSerontRecalculesAuto;

  /// No description provided for @champMotif.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get champMotif;

  /// No description provided for @nJoursRetard.
  ///
  /// In fr, this message translates to:
  /// **'{count}j retard'**
  String nJoursRetard(String count);

  /// No description provided for @nJoursRetardBullet.
  ///
  /// In fr, this message translates to:
  /// **'• {count}j de retard'**
  String nJoursRetardBullet(String count);

  /// No description provided for @nJoursInterruptionDeduits.
  ///
  /// In fr, this message translates to:
  /// **'{count} j interruption déduits'**
  String nJoursInterruptionDeduits(String count);

  /// No description provided for @dupliquer.
  ///
  /// In fr, this message translates to:
  /// **'Dupliquer'**
  String get dupliquer;

  /// No description provided for @filterTous.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get filterTous;

  /// No description provided for @enCoursEnPause.
  ///
  /// In fr, this message translates to:
  /// **'⏸ En cours'**
  String get enCoursEnPause;

  /// No description provided for @enRetardAvecCount.
  ///
  /// In fr, this message translates to:
  /// **'⚠️ En retard ({count})'**
  String enRetardAvecCount(String count);

  /// No description provided for @historiqueAvecCount.
  ///
  /// In fr, this message translates to:
  /// **'Historique ({count})'**
  String historiqueAvecCount(String count);

  /// No description provided for @nZones.
  ///
  /// In fr, this message translates to:
  /// **'{count} zone(s)'**
  String nZones(String count);

  /// No description provided for @labelNotesDepart.
  ///
  /// In fr, this message translates to:
  /// **'Départ : {notes}'**
  String labelNotesDepart(String notes);

  /// No description provided for @labelNotesRetour.
  ///
  /// In fr, this message translates to:
  /// **'Retour : {notes}'**
  String labelNotesRetour(String notes);

  /// No description provided for @champDistance.
  ///
  /// In fr, this message translates to:
  /// **'Distance'**
  String get champDistance;

  /// No description provided for @kmDepartHelper.
  ///
  /// In fr, this message translates to:
  /// **'Départ : {km} km'**
  String kmDepartHelper(String km);

  /// No description provided for @traitementEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Traitement…'**
  String get traitementEnCours;

  /// No description provided for @interruptionDemarre.
  ///
  /// In fr, this message translates to:
  /// **'Interruption démarrée — véhicule récupéré le {date}'**
  String interruptionDemarre(String date);

  /// No description provided for @vehiculeRestitue.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule restitué le {date} — {count} jour(s) déduit(s)'**
  String vehiculeRestitue(String date, String count);

  /// No description provided for @interruptionSupprimee.
  ///
  /// In fr, this message translates to:
  /// **'Interruption supprimée'**
  String get interruptionSupprimee;

  /// No description provided for @depuisLeDateCount.
  ///
  /// In fr, this message translates to:
  /// **'Depuis le {date} · {count} j'**
  String depuisLeDateCount(String date, String count);

  /// No description provided for @indiquerRaisonDateRecuperation.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez la raison et la date à laquelle vous récupérez le véhicule. Ces jours seront déduits de la facturation.'**
  String get indiquerRaisonDateRecuperation;

  /// No description provided for @dateRecuperationVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Date de récupération du véhicule'**
  String get dateRecuperationVehicule;

  /// No description provided for @titreDetailsMontants.
  ///
  /// In fr, this message translates to:
  /// **'Montants'**
  String get titreDetailsMontants;

  /// No description provided for @paiementsRecusCount.
  ///
  /// In fr, this message translates to:
  /// **'Paiements reçus ({count})'**
  String paiementsRecusCount(String count);

  /// No description provided for @champFinancier.
  ///
  /// In fr, this message translates to:
  /// **'Financier'**
  String get champFinancier;

  /// No description provided for @totalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @detailsOperation.
  ///
  /// In fr, this message translates to:
  /// **'Détails de l\'opération'**
  String get detailsOperation;

  /// No description provided for @filterSorties.
  ///
  /// In fr, this message translates to:
  /// **'Sorties'**
  String get filterSorties;

  /// No description provided for @filterSolde.
  ///
  /// In fr, this message translates to:
  /// **'Solde'**
  String get filterSolde;

  /// No description provided for @acompte.
  ///
  /// In fr, this message translates to:
  /// **'Acompte'**
  String get acompte;

  /// No description provided for @champMois.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get champMois;

  /// No description provided for @champAnneeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get champAnneeLabel;

  /// No description provided for @champType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get champType;

  /// No description provided for @totalCommissions.
  ///
  /// In fr, this message translates to:
  /// **'Total commissions'**
  String get totalCommissions;

  /// No description provided for @champCommission.
  ///
  /// In fr, this message translates to:
  /// **'Commission'**
  String get champCommission;

  /// No description provided for @anonyme.
  ///
  /// In fr, this message translates to:
  /// **'Anonyme'**
  String get anonyme;

  /// No description provided for @demandeSucces.
  ///
  /// In fr, this message translates to:
  /// **'Demande traitée avec succès.'**
  String get demandeSucces;

  /// No description provided for @photosCount.
  ///
  /// In fr, this message translates to:
  /// **'Photos ({count})'**
  String photosCount(String count);

  /// No description provided for @champPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get champPhoto;

  /// No description provided for @btnRejeter.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter'**
  String get btnRejeter;

  /// No description provided for @btnApprouver.
  ///
  /// In fr, this message translates to:
  /// **'Approuver'**
  String get btnApprouver;

  /// No description provided for @champMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get champMessage;

  /// No description provided for @gpsDepuis.
  ///
  /// In fr, this message translates to:
  /// **'Du {date}'**
  String gpsDepuis(String date);

  /// No description provided for @gpsAu.
  ///
  /// In fr, this message translates to:
  /// **'Au {date}'**
  String gpsAu(String date);

  /// No description provided for @preset1Heure.
  ///
  /// In fr, this message translates to:
  /// **'1 heure'**
  String get preset1Heure;

  /// No description provided for @preset3Heures.
  ///
  /// In fr, this message translates to:
  /// **'3 heures'**
  String get preset3Heures;

  /// No description provided for @preset8Heures.
  ///
  /// In fr, this message translates to:
  /// **'8 heures'**
  String get preset8Heures;

  /// No description provided for @presetHier.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get presetHier;

  /// No description provided for @preset24Heures.
  ///
  /// In fr, this message translates to:
  /// **'24 heures'**
  String get preset24Heures;

  /// No description provided for @preset3Jours.
  ///
  /// In fr, this message translates to:
  /// **'3 jours'**
  String get preset3Jours;

  /// No description provided for @preset7Jours.
  ///
  /// In fr, this message translates to:
  /// **'7 jours'**
  String get preset7Jours;

  /// No description provided for @sectionClient.
  ///
  /// In fr, this message translates to:
  /// **'Client'**
  String get sectionClient;

  /// No description provided for @vehiculeCede.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule cédé'**
  String get vehiculeCede;

  /// No description provided for @vehiculeRepris.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule repris'**
  String get vehiculeRepris;

  /// No description provided for @modeleChamp.
  ///
  /// In fr, this message translates to:
  /// **'Modèle *'**
  String get modeleChamp;

  /// No description provided for @telephoneObligatoire.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone *'**
  String get telephoneObligatoire;

  /// No description provided for @achatEnregistreAvecSucces.
  ///
  /// In fr, this message translates to:
  /// **'Achat enregistré avec succès'**
  String get achatEnregistreAvecSucces;

  /// No description provided for @prixAccordeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prix accordé'**
  String get prixAccordeLabel;

  /// No description provided for @modeleIaGemini.
  ///
  /// In fr, this message translates to:
  /// **'Modèle IA (gemini_model)'**
  String get modeleIaGemini;

  /// No description provided for @echangeEnregistreAvecSucces.
  ///
  /// In fr, this message translates to:
  /// **'Échange enregistré avec succès'**
  String get echangeEnregistreAvecSucces;

  /// No description provided for @kmDepartInferieur.
  ///
  /// In fr, this message translates to:
  /// **'< km départ'**
  String get kmDepartInferieur;

  /// No description provided for @dateRetourAvantDebut.
  ///
  /// In fr, this message translates to:
  /// **'La date de retour réelle ne peut pas être avant la date de début'**
  String get dateRetourAvantDebut;

  /// No description provided for @locationMiseAJour.
  ///
  /// In fr, this message translates to:
  /// **'Location mise à jour avec succès !'**
  String get locationMiseAJour;

  /// No description provided for @contratOuvertSansDateFin.
  ///
  /// In fr, this message translates to:
  /// **'Contrat ouvert (sans date de fin)'**
  String get contratOuvertSansDateFin;

  /// No description provided for @clientListeNoire.
  ///
  /// In fr, this message translates to:
  /// **'⚠️ Ce client est en liste noire ! Soyez prudent.'**
  String get clientListeNoire;

  /// No description provided for @notesEtatVehiculeDepart.
  ///
  /// In fr, this message translates to:
  /// **'Notes état du véhicule au départ (optionnel)'**
  String get notesEtatVehiculeDepart;

  /// No description provided for @pdfGenereAvecSucces.
  ///
  /// In fr, this message translates to:
  /// **'PDF généré avec succès'**
  String get pdfGenereAvecSucces;

  /// No description provided for @locationSupprimee.
  ///
  /// In fr, this message translates to:
  /// **'Location supprimée.'**
  String get locationSupprimee;

  /// No description provided for @elementSupprime.
  ///
  /// In fr, this message translates to:
  /// **'Supprimé avec succès.'**
  String get elementSupprime;

  /// No description provided for @suppressionImpossibleLiee.
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible : d\'autres éléments (locations, ventes, paiements, réparations...) sont encore liés à cet enregistrement.'**
  String get suppressionImpossibleLiee;

  /// No description provided for @exMarqueVehicule.
  ///
  /// In fr, this message translates to:
  /// **'ex: Renault, Peugeot...'**
  String get exMarqueVehicule;

  /// No description provided for @sommePartsDoit100.
  ///
  /// In fr, this message translates to:
  /// **'La somme des parts doit etre 100%'**
  String get sommePartsDoit100;

  /// No description provided for @anneeInvalideSimple.
  ///
  /// In fr, this message translates to:
  /// **'Annee invalide'**
  String get anneeInvalideSimple;

  /// No description provided for @cleApiGeminiNonConfiguree.
  ///
  /// In fr, this message translates to:
  /// **'Clé API Gemini non configurée. Allez dans Paramètres > Showroom.'**
  String get cleApiGeminiNonConfiguree;

  /// No description provided for @carteGriseAnalysee.
  ///
  /// In fr, this message translates to:
  /// **'Carte grise analysée avec succès !'**
  String get carteGriseAnalysee;

  /// No description provided for @analyseTermineeDonneesManquantes.
  ///
  /// In fr, this message translates to:
  /// **'Analyse terminée mais certaines données sont manquantes. Veuillez compléter manuellement.'**
  String get analyseTermineeDonneesManquantes;

  /// No description provided for @venteEnregistreeAvecSucces.
  ///
  /// In fr, this message translates to:
  /// **'Vente enregistrée avec succès'**
  String get venteEnregistreeAvecSucces;

  /// No description provided for @ajouterAuStockBtn.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au stock'**
  String get ajouterAuStockBtn;

  /// No description provided for @tooltipPlanning.
  ///
  /// In fr, this message translates to:
  /// **'Planning'**
  String get tooltipPlanning;

  /// No description provided for @tooltipRetourAccueil.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get tooltipRetourAccueil;

  /// No description provided for @tooltipPlusOptions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d\'options'**
  String get tooltipPlusOptions;

  /// No description provided for @titrePaiements.
  ///
  /// In fr, this message translates to:
  /// **'Paiements'**
  String get titrePaiements;

  /// No description provided for @confirmerSuppressionLocationMessage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la location de {vehicule} pour {client} ?\nCette action est irréversible.'**
  String confirmerSuppressionLocationMessage(String vehicule, String client);

  /// No description provided for @cautionMontantDa.
  ///
  /// In fr, this message translates to:
  /// **'Caution : {montant} DA'**
  String cautionMontantDa(String montant);

  /// No description provided for @karossaAi.
  ///
  /// In fr, this message translates to:
  /// **'KarossaAI'**
  String get karossaAi;

  /// No description provided for @prendrePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get prendrePhoto;

  /// No description provided for @choisirGalerie.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get choisirGalerie;

  /// No description provided for @erreurGenerationRapport.
  ///
  /// In fr, this message translates to:
  /// **'Erreur génération du rapport : {erreur}'**
  String erreurGenerationRapport(String erreur);

  /// No description provided for @genererRapportPdfMois.
  ///
  /// In fr, this message translates to:
  /// **'Générer le rapport PDF du mois'**
  String get genererRapportPdfMois;

  /// No description provided for @effacerHistorique.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'historique'**
  String get effacerHistorique;

  /// No description provided for @contextualiserAssistant.
  ///
  /// In fr, this message translates to:
  /// **'Contextualiser l\'assistant avec la BDD'**
  String get contextualiserAssistant;

  /// No description provided for @joindrePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Joindre une photo (dommage, facture, carte grise...)'**
  String get joindrePhoto;

  /// No description provided for @actualiser.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get actualiser;

  /// No description provided for @rejete.
  ///
  /// In fr, this message translates to:
  /// **'Rejeté'**
  String get rejete;

  /// No description provided for @confirmerApprobationDemande.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer l\'approbation de cette demande ?'**
  String get confirmerApprobationDemande;

  /// No description provided for @bonjourPrenom.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour, {prenom} 👋'**
  String bonjourPrenom(String prenom);

  /// No description provided for @actionRequiseRetards.
  ///
  /// In fr, this message translates to:
  /// **'Action requise : {count} véhicule(s) en retard de restitution !'**
  String actionRequiseRetards(String count);

  /// No description provided for @fin.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get fin;

  /// No description provided for @aucunContratLocationActif.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contrat de location actif aujourd\'hui'**
  String get aucunContratLocationActif;

  /// No description provided for @copier.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get copier;

  /// No description provided for @marquerRembourse.
  ///
  /// In fr, this message translates to:
  /// **'Marquer remboursé'**
  String get marquerRembourse;

  /// No description provided for @supprimerCeTransfert.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce transfert ?'**
  String get supprimerCeTransfert;

  /// No description provided for @transfertSeraSupprimeDefinitivement.
  ///
  /// In fr, this message translates to:
  /// **'Le transfert de {montant} sera définitivement supprimé.'**
  String transfertSeraSupprimeDefinitivement(String montant);

  /// No description provided for @soldeRestantTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Solde restant à verser en tenant compte des transferts d\'argent avec d\'autres utilisateurs'**
  String get soldeRestantTooltip;

  /// No description provided for @zoneCreeeSucces.
  ///
  /// In fr, this message translates to:
  /// **'Zone \"{nom}\" créée'**
  String zoneCreeeSucces(String nom);

  /// No description provided for @btnContinuer.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get btnContinuer;

  /// No description provided for @champNomZone.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la zone'**
  String get champNomZone;

  /// No description provided for @exempleNomZone.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Showroom Alger, Atelier...'**
  String get exempleNomZone;

  /// No description provided for @champCouleur.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get champCouleur;

  /// No description provided for @alerterALEntree.
  ///
  /// In fr, this message translates to:
  /// **'Alerter à l\'entrée'**
  String get alerterALEntree;

  /// No description provided for @alerterALaSortie.
  ///
  /// In fr, this message translates to:
  /// **'Alerter à la sortie'**
  String get alerterALaSortie;

  /// No description provided for @aucunContratTrouvePourVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contrat trouvé pour ce véhicule'**
  String get aucunContratTrouvePourVehicule;

  /// No description provided for @fonctionnaliteTelechargementAImplementer.
  ///
  /// In fr, this message translates to:
  /// **'Fonctionnalité de téléchargement à implémenter'**
  String get fonctionnaliteTelechargementAImplementer;

  /// No description provided for @fonctionnalitePartageAImplementer.
  ///
  /// In fr, this message translates to:
  /// **'Fonctionnalité de partage à implémenter'**
  String get fonctionnalitePartageAImplementer;

  /// No description provided for @aucuneDonneePourCetteDate.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée pour cette date'**
  String get aucuneDonneePourCetteDate;

  /// No description provided for @lectureDeTrajet.
  ///
  /// In fr, this message translates to:
  /// **'Lecture de trajet'**
  String get lectureDeTrajet;

  /// No description provided for @reconstitutionDuTrajet.
  ///
  /// In fr, this message translates to:
  /// **'Reconstitution du trajet…'**
  String get reconstitutionDuTrajet;

  /// No description provided for @pointsReconstituesTooltip.
  ///
  /// In fr, this message translates to:
  /// **'{count} point(s) reconstitué(s) le long de la route la plus probable, là où le signal GPS a été perdu quelques instants.'**
  String pointsReconstituesTooltip(String count);

  /// No description provided for @countReconstitues.
  ///
  /// In fr, this message translates to:
  /// **'{count} reconstitué{plural}'**
  String countReconstitues(String count, String plural);

  /// No description provided for @intervalleDeLecture.
  ///
  /// In fr, this message translates to:
  /// **'Intervalle de lecture'**
  String get intervalleDeLecture;

  /// No description provided for @btnAppliquer.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get btnAppliquer;

  /// No description provided for @vitesseDeLecture.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse de lecture'**
  String get vitesseDeLecture;

  /// No description provided for @syncDansSecondes.
  ///
  /// In fr, this message translates to:
  /// **'Sync dans {countdown}s'**
  String syncDansSecondes(String countdown);

  /// No description provided for @aucunVehiculeGps.
  ///
  /// In fr, this message translates to:
  /// **'Aucun véhicule GPS'**
  String get aucunVehiculeGps;

  /// No description provided for @planningLocations.
  ///
  /// In fr, this message translates to:
  /// **'Planning locations'**
  String get planningLocations;

  /// No description provided for @aujourdhui.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get aujourdhui;

  /// No description provided for @aucunVehiculeAAfficher.
  ///
  /// In fr, this message translates to:
  /// **'Aucun véhicule à afficher.'**
  String get aucunVehiculeAAfficher;

  /// No description provided for @msgMarqueModeleTypeAlerte.
  ///
  /// In fr, this message translates to:
  /// **'{marque} {modele} — {typeAlerte}'**
  String msgMarqueModeleTypeAlerte(
      String marque, String modele, String typeAlerte);

  /// No description provided for @alerteGpsVehicule.
  ///
  /// In fr, this message translates to:
  /// **'Alerte GPS — {vehicule}'**
  String alerteGpsVehicule(String vehicule);

  /// No description provided for @nouvelleReservationWeb.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle réservation web'**
  String get nouvelleReservationWeb;

  /// No description provided for @msgReservationWeb.
  ///
  /// In fr, this message translates to:
  /// **'{marque} {modele} — du {debut} au {fin}'**
  String msgReservationWeb(
      String marque, String modele, String debut, String fin);

  /// No description provided for @nouvelleDemandeDevis.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle demande de devis'**
  String get nouvelleDemandeDevis;

  /// No description provided for @propositionRepriseClient.
  ///
  /// In fr, this message translates to:
  /// **'Proposition de reprise client'**
  String get propositionRepriseClient;

  /// No description provided for @alaChargeDe.
  ///
  /// In fr, this message translates to:
  /// **'À la charge de : {resume}'**
  String alaChargeDe(String resume);

  /// No description provided for @documents.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @centreAlertes.
  ///
  /// In fr, this message translates to:
  /// **'Centre d\'alertes'**
  String get centreAlertes;

  /// No description provided for @toutLu.
  ///
  /// In fr, this message translates to:
  /// **'Tout lu'**
  String get toutLu;

  /// No description provided for @aucuneAlerteIci.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte ici'**
  String get aucuneAlerteIci;

  /// No description provided for @lu.
  ///
  /// In fr, this message translates to:
  /// **'Lu'**
  String get lu;

  /// No description provided for @vitessePeriode.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse — {periode}'**
  String vitessePeriode(String periode);

  /// No description provided for @repartitionDuTemps.
  ///
  /// In fr, this message translates to:
  /// **'Répartition du temps'**
  String get repartitionDuTemps;

  /// No description provided for @retourPrevuValeur.
  ///
  /// In fr, this message translates to:
  /// **'Retour prévu : {retour}'**
  String retourPrevuValeur(String retour);

  /// No description provided for @kmh.
  ///
  /// In fr, this message translates to:
  /// **'km/h'**
  String get kmh;

  /// No description provided for @erreurDeChargement.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement : {error}'**
  String erreurDeChargement(String error);

  /// No description provided for @aucuneDonneeGpsSurPeriode.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée GPS sur cette période'**
  String get aucuneDonneeGpsSurPeriode;

  /// No description provided for @zonesDeCirculation.
  ///
  /// In fr, this message translates to:
  /// **'Zones de circulation'**
  String get zonesDeCirculation;

  /// No description provided for @pointsGpsAnalyses.
  ///
  /// In fr, this message translates to:
  /// **'{count} points GPS analysés'**
  String pointsGpsAnalyses(String count);

  /// No description provided for @faible.
  ///
  /// In fr, this message translates to:
  /// **'Faible'**
  String get faible;

  /// No description provided for @eleve.
  ///
  /// In fr, this message translates to:
  /// **'Élevé'**
  String get eleve;

  /// No description provided for @vendeur.
  ///
  /// In fr, this message translates to:
  /// **'Vendeur'**
  String get vendeur;

  /// No description provided for @remarques.
  ///
  /// In fr, this message translates to:
  /// **'Remarques'**
  String get remarques;

  /// No description provided for @statutMisAJour.
  ///
  /// In fr, this message translates to:
  /// **'Statut mis à jour : {statut}'**
  String statutMisAJour(String statut);

  /// No description provided for @modifierLabel.
  ///
  /// In fr, this message translates to:
  /// **'Modifier — {label}'**
  String modifierLabel(String label);

  /// No description provided for @commissionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Commission — {label}'**
  String commissionLabel(String label);

  /// No description provided for @identite.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get identite;

  /// No description provided for @aucuneAlerteEntretienActive.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte d\'entretien active'**
  String get aucuneAlerteEntretienActive;

  /// No description provided for @kmEcheance.
  ///
  /// In fr, this message translates to:
  /// **'À {km} km'**
  String kmEcheance(String km);

  /// No description provided for @expire.
  ///
  /// In fr, this message translates to:
  /// **'EXPIRÉ'**
  String get expire;

  /// No description provided for @btnFait.
  ///
  /// In fr, this message translates to:
  /// **'Fait'**
  String get btnFait;

  /// No description provided for @catalogue.
  ///
  /// In fr, this message translates to:
  /// **'Catalogue'**
  String get catalogue;

  /// No description provided for @filtres.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get filtres;

  /// No description provided for @journalAudit.
  ///
  /// In fr, this message translates to:
  /// **'Journal d\'audit'**
  String get journalAudit;

  /// No description provided for @aucuneActiviteEnregistreePourCesFiltres.
  ///
  /// In fr, this message translates to:
  /// **'Aucune activité enregistrée pour ces filtres.'**
  String get aucuneActiviteEnregistreePourCesFiltres;

  /// No description provided for @gererLEquipe.
  ///
  /// In fr, this message translates to:
  /// **'Gérer l\'équipe'**
  String get gererLEquipe;

  /// No description provided for @nouvelleAlerteEntretien.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle alerte d\'entretien'**
  String get nouvelleAlerteEntretien;

  /// No description provided for @typeEntretien.
  ///
  /// In fr, this message translates to:
  /// **'Type d\'entretien'**
  String get typeEntretien;

  /// No description provided for @depensesUpper.
  ///
  /// In fr, this message translates to:
  /// **'DÉPENSES'**
  String get depensesUpper;

  /// No description provided for @revenusUpper.
  ///
  /// In fr, this message translates to:
  /// **'REVENUS'**
  String get revenusUpper;

  /// No description provided for @locationsUpper.
  ///
  /// In fr, this message translates to:
  /// **'LOCATIONS'**
  String get locationsUpper;

  /// No description provided for @constatIA.
  ///
  /// In fr, this message translates to:
  /// **'Constat IA'**
  String get constatIA;

  /// No description provided for @insightDuJour.
  ///
  /// In fr, this message translates to:
  /// **'· insight du jour'**
  String get insightDuJour;

  /// No description provided for @autresPointsAConsulter.
  ///
  /// In fr, this message translates to:
  /// **'+ {autres} autre{plural} point{plural} à consulter'**
  String autresPointsAConsulter(String autres, String plural);

  /// No description provided for @vueDEnsemble.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble'**
  String get vueDEnsemble;

  /// No description provided for @donneesNonDisponibles.
  ///
  /// In fr, this message translates to:
  /// **'Données non disponibles'**
  String get donneesNonDisponibles;

  /// No description provided for @aucunTrajetAujourdhui.
  ///
  /// In fr, this message translates to:
  /// **'Aucun trajet aujourd\'hui'**
  String get aucunTrajetAujourdhui;

  /// No description provided for @vsMoisDernier.
  ///
  /// In fr, this message translates to:
  /// **'vs mois dernier'**
  String get vsMoisDernier;

  /// No description provided for @supprimerLInterruption.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'interruption ?'**
  String get supprimerLInterruption;

  /// No description provided for @montants.
  ///
  /// In fr, this message translates to:
  /// **'Montants'**
  String get montants;

  /// No description provided for @departKm.
  ///
  /// In fr, this message translates to:
  /// **'Départ : {km} km'**
  String departKm(String km);

  /// No description provided for @joursRetard.
  ///
  /// In fr, this message translates to:
  /// **'{jours}j retard'**
  String joursRetard(String jours);

  /// No description provided for @totalPourcent.
  ///
  /// In fr, this message translates to:
  /// **'Total : {pct}%'**
  String totalPourcent(String pct);

  /// No description provided for @erreurUploadPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'upload de la photo : {error}'**
  String erreurUploadPhoto(String error);

  /// No description provided for @detailDeLErreur.
  ///
  /// In fr, this message translates to:
  /// **'Détail de l\'erreur'**
  String get detailDeLErreur;

  /// No description provided for @entretien.
  ///
  /// In fr, this message translates to:
  /// **'Entretien'**
  String get entretien;

  /// No description provided for @dateDAchat.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'achat'**
  String get dateDAchat;

  /// No description provided for @scoreIndisponiblePourPeriode.
  ///
  /// In fr, this message translates to:
  /// **'Score indisponible pour cette période'**
  String get scoreIndisponiblePourPeriode;

  /// No description provided for @scoreDeConduite.
  ///
  /// In fr, this message translates to:
  /// **'Score de conduite'**
  String get scoreDeConduite;

  /// No description provided for @duDate.
  ///
  /// In fr, this message translates to:
  /// **'Du {date}'**
  String duDate(String date);

  /// No description provided for @auDate.
  ///
  /// In fr, this message translates to:
  /// **'Au {date}'**
  String auDate(String date);

  /// No description provided for @enMouvement.
  ///
  /// In fr, this message translates to:
  /// **'En mouvement'**
  String get enMouvement;

  /// No description provided for @horsLigne.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get horsLigne;

  /// No description provided for @entreeDansLaZone.
  ///
  /// In fr, this message translates to:
  /// **'Entrée dans la zone \"{zone}\"'**
  String entreeDansLaZone(String zone);

  /// No description provided for @sortieDeLaZone.
  ///
  /// In fr, this message translates to:
  /// **'Sortie de la zone \"{zone}\"'**
  String sortieDeLaZone(String zone);

  /// No description provided for @champMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode'**
  String get champMode;

  /// No description provided for @contratOuvertPrixJour.
  ///
  /// In fr, this message translates to:
  /// **'Contrat ouvert — {prix} DA/jour'**
  String contratOuvertPrixJour(String prix);

  /// No description provided for @detailsDeLOperation.
  ///
  /// In fr, this message translates to:
  /// **'Détails de l\'opération'**
  String get detailsDeLOperation;

  /// No description provided for @effacer.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get effacer;

  /// No description provided for @retourALAccueil.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get retourALAccueil;

  /// No description provided for @locationsEffectuees.
  ///
  /// In fr, this message translates to:
  /// **'{count} location(s) effectuée(s)'**
  String locationsEffectuees(String count);

  /// No description provided for @erreurCritiqueSynchronisation.
  ///
  /// In fr, this message translates to:
  /// **'Erreur critique de synchronisation : {error}'**
  String erreurCritiqueSynchronisation(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
