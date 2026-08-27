// lib/features/echanges/domain/echange_dto_mapper.dart

import '../../contrats/domain/contrat_echange_dto.dart';
import '../domain/echange_model.dart';

extension EchangeToDto on Echange {
  ContratEchangeDto toContratDto({
    required String agenceNom,
    String  agenceAdresse   = '',
    String  agenceTel       = '',
    String  agenceEmail     = '',
    String  agenceRc        = '',
    String? agenceLogoUrl,
    String  agenceCouleurHex = '#1A365D',
    // Infos véhicule cédé — non stockées dans Echange, passées depuis le form
    String  vehiculeCedeMarque   = '',
    String  vehiculeCedeModele   = '',
    int?    vehiculeCedeAnnee,
    String? vehiculeCedeImmat,
    int?    vehiculeCedeKm,
    String? vehiculeCedeCouleur,
    String? vehiculeCedeCarburant,
    String? vehiculeCedeBoite,
    // Infos client — clientNom dans Echange est "prénom nom" concaténé
    String? clientPrenomOverride,
    String? clientNomOverride,
    String  clientTelephone = '',
    String? clientCin,
    // Articles bilingues
    List<Map<String, String>> articlesFr = const [],
    List<Map<String, String>> articlesAr = const [],
    String? modePaiement,
    String? notes,
  }) {
    // clientNom dans le modèle est déjà "Prénom Nom" concaténé par fromJson.
    // On sépare sur le premier espace pour alimenter clientPrenom/clientNom du DTO.
    final fullName = clientNomOverride ?? clientNom ?? '';
    final spaceIdx = fullName.indexOf(' ');
    final prenom = clientPrenomOverride ??
        (spaceIdx > 0 ? fullName.substring(0, spaceIdx) : fullName);
    final nom = spaceIdx > 0 ? fullName.substring(spaceIdx + 1) : '';

    final cedeInfos =
        '$vehiculeCedeMarque $vehiculeCedeModele'.trim();

    // vehiculeRepris* : noms corrects dans Echange (pas vehiculeReprise*)
    final reprisInfos =
        '$vehiculeReprisMarque $vehiculeReprisModele'.trim();

    return ContratEchangeDto(
      echangeId:          id,
      dateEtablissement:  DateTime.now(),
      dateEchange:        dateEchange,

      // ── Agence ──────────────────────────────────────────────
      agenceNom:          agenceNom,
      agenceAdresse:      agenceAdresse,
      agenceTel:          agenceTel,
      agenceEmail:        agenceEmail,
      agenceRc:           agenceRc,
      agenceLogoUrl:      agenceLogoUrl,
      agenceCouleurHex:   agenceCouleurHex,

      // ── Client ──────────────────────────────────────────────
      clientNom:          nom,
      clientPrenom:       prenom,
      clientTelephone:    clientTelephone,
      clientCin:          clientCin,

      // ── Véhicule cédé (du showroom) ─────────────────────────
      vehiculeCedeInfos:     cedeInfos,
      vehiculeCedeMarque:    vehiculeCedeMarque,
      vehiculeCedeModele:    vehiculeCedeModele,
      vehiculeCedeAnnee:     vehiculeCedeAnnee,
      vehiculeCedeImmat:     vehiculeCedeImmat,
      vehiculeCedeKm:        vehiculeCedeKm,
      vehiculeCedeCouleur:   vehiculeCedeCouleur,
      vehiculeCedeCarburant: vehiculeCedeCarburant,
      vehiculeCedeBoite:     vehiculeCedeBoite,

      // ── Véhicule repris (du client) ─────────────────────────
      // Champs corrects du modèle Echange : vehiculeRepris* (pas vehiculeReprise*)
      vehiculeReprisInfos:  reprisInfos,
      vehiculeReprisMarque: vehiculeReprisMarque,
      vehiculeReprisModele: vehiculeReprisModele,
      vehiculeReprisAnnee:  vehiculeReprisAnnee,
      vehiculeReprisImmat:  vehiculeReprisImmat,
      vehiculeReprisKm:     vehiculeReprisKm,

      // ── Financier ────────────────────────────────────────────
      valeurReprise:       valeurReprise,
      complementClient:    complementClient,
      commissionGerantPct: commissionGerantPct,
      modePaiement:        modePaiement,

      // ── Articles & Notes ─────────────────────────────────────
      articlesFr: articlesFr,
      articlesAr: articlesAr,
      notes:      notes ?? this.notes,
    );
  }
}