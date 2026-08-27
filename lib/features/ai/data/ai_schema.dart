// lib/features/ai/data/ai_schema.dart
//
// Source de vérité pour ce que KarossaAI a le droit de voir dans la BDD.
// Toute table/colonne absente d'ici est INVISIBLE pour l'IA, même si elle
// existe dans Supabase (clés API, mots de passe Flespi, CNI/permis, etc.
// sont volontairement exclus).

/// Colonnes autorisées à la lecture, par table.
/// `showroom_id` est ajouté automatiquement en filtre par l'exécuteur :
/// inutile (et interdit) de le laisser choisir par l'IA.
const Map<String, List<String>> kAiAllowedTables = {
  'vehicules': [
    'id', 'marque', 'modele', 'annee', 'couleur', 'immatriculation',
    'carburant', 'boite', 'kilometrage', 'prix_vente', 'prix_location_jour',
    'statut', 'prix_achat', 'etat_vehicule', 'date_entree', 'created_at',
  ],
  'clients': [
    'id', 'nom', 'prenom', 'telephone', 'statut', 'note_interne', 'created_at',
  ],
  'locations': [
    'id', 'vehicule_id', 'client_id', 'date_debut', 'date_fin_prevue',
    'date_fin_reelle', 'km_depart', 'km_retour', 'prix_jour', 'caution',
    'retenue_caution', 'statut', 'nb_jours', 'montant_brut', 'created_at',
  ],
  'location_paiements': [
    'id', 'location_id', 'montant', 'date_paiement', 'mode',
  ],
  'ventes': [
    'id', 'vehicule_id', 'client_id', 'prix_catalogue', 'prix_vente',
    'mode_paiement', 'date_vente', 'date_livraison', 'commission_gerant_pct',
    'commission_gerant_mnt', 'statut_paiement',
  ],
  'vente_paiements': [
    'id', 'vente_id', 'montant', 'date_paiement', 'mode',
  ],
  'echanges': [
    'id', 'vehicule_cede_id', 'client_id', 'vehicule_reprise_marque',
    'vehicule_reprise_modele', 'vehicule_reprise_annee', 'vehicule_reprise_km',
    'valeur_reprise', 'complement_client', 'commission_gerant_pct',
    'commission_gerant_mnt', 'date_echange',
  ],
  'achats': [
    'id', 'vehicule_id', 'vendeur_nom', 'prix_propose', 'prix_accorde',
    'date_achat', 'statut',
  ],
  'caisse_operations': [
    'id', 'type', 'categorie', 'montant', 'description', 'vehicule_id',
    'date_op', 'payee_par', 'location_id', 'vente_id', 'reparation_id',
    'echange_id',
  ],
  'reparations': [
    'id', 'vehicule_id', 'type_rep', 'description', 'prestataire', 'cout',
    'date_rep', 'km_au_moment', 'deductible', 'payee_par',
  ],
  'alertes_entretien': [
    'id', 'vehicule_id', 'type_alerte', 'date_echeance', 'km_echeance',
    'statut', 'description',
  ],
  'versements_proprietaires': [
    'id', 'proprietaire_id', 'montant', 'date_versement', 'mode', 'type_part',
  ],
  'reservations_web': [
    'id', 'vehicule_id', 'client_id', 'date_debut', 'date_fin', 'statut',
    'montant_estime', 'created_at',
  ],
  'demandes_devis': [
    'id', 'vehicule_id', 'client_id', 'type', 'budget_max', 'statut',
    'created_at',
  ],
  'propositions_vente': [
    'id', 'client_id', 'marque', 'modele', 'annee', 'kilometrage',
    'prix_souhaite', 'statut', 'created_at',
  ],
  'profiles': ['id', 'nom', 'prenom', 'role'],
  'vehicule_proprietes': ['id', 'vehicule_id', 'proprietaire_id', 'part_pct'],
  'transferts_utilisateurs': [
    'id', 'payeur_id', 'beneficiaire_id', 'montant', 'motif', 'remboursable',
    'rembourse', 'date_transfert',
  ],
};

/// Colonnes numériques "agrégeables" par table, exposées à l'outil
/// `aggregate_table` (évite de calculer une somme sur `annee` par exemple).
const Map<String, List<String>> kAiAggregatableColumns = {
  'vehicules': ['prix_vente', 'prix_location_jour', 'prix_achat', 'kilometrage'],
  'locations': ['prix_jour', 'caution', 'retenue_caution', 'montant_brut', 'nb_jours'],
  'location_paiements': ['montant'],
  'ventes': ['prix_catalogue', 'prix_vente', 'commission_gerant_mnt'],
  'vente_paiements': ['montant'],
  'echanges': ['valeur_reprise', 'complement_client', 'commission_gerant_mnt'],
  'achats': ['prix_propose', 'prix_accorde'],
  'caisse_operations': ['montant'],
  'reparations': ['cout', 'km_au_moment'],
  'versements_proprietaires': ['montant'],
  'reservations_web': ['montant_estime'],
  'propositions_vente': ['prix_souhaite', 'kilometrage'],
};

/// Résumé COMPACT du schéma (pas le DDL complet, pour économiser des tokens),
/// injecté dans le prompt système afin que l'IA sache quelles tables
/// interroger et pourquoi, sans avoir à deviner.
String buildSchemaSummaryForPrompt() {
  return '''
SCHÉMA DE DONNÉES DISPONIBLE (lecture seule, déjà filtré sur le showroom courant) :
- vehicules : le parc auto (marque, modèle, année, statut disponible/loue/vendu/reparation/reserve, prix_vente, prix_location_jour, kilométrage...)
- clients : identité + statut (normal/fiable/risque/blacklist)
- locations : contrats de location (dates, km_depart/retour, prix_jour, statut en_cours/termine/annule/retard, montant_brut) → lien vehicule_id, client_id
- location_paiements : paiements reçus sur une location → lien location_id
- ventes : ventes de véhicules (prix_vente, statut_paiement partiel/complet, commission_gerant_mnt) → lien vehicule_id, client_id
- vente_paiements : paiements reçus sur une vente → lien vente_id
- echanges : reprises/échanges de véhicules (valeur_reprise, complement_client) → lien vehicule_cede_id, client_id
- achats : acquisitions de véhicules auprès de vendeurs particuliers → lien vehicule_id
- caisse_operations : mouvements de caisse (type entree/sortie, categorie loyer_location/vente_vehicule/reparation/entretien/carburant/assurance/...)
- reparations : historique entretien/réparations (cout, type_rep, payee_par showroom/proprietaire) → lien vehicule_id
- alertes_entretien : échéances vidange/assurance/controle_technique/vignette à venir → lien vehicule_id
- versements_proprietaires : sommes reversées aux propriétaires
- vehicule_proprietes : répartition de propriété d'un véhicule entre plusieurs propriétaires (part_pct) → lien vehicule_id, proprietaire_id
- reservations_web / demandes_devis / propositions_vente : demandes venant de la plateforme publique clients
- profiles : utilisateurs internes (gerant/proprietaire/associe) — sert à retrouver un nom depuis un proprietaire_id/beneficiaire_id, jamais à afficher un id brut

RÈGLES D'UTILISATION DES OUTILS :
- Utilise query_table pour lire des lignes, aggregate_table pour un total/moyenne/nombre (ne rapatrie pas 200 lignes pour calculer une somme), get_dashboard_summary pour une vue d'ensemble instantanée, detect_anomalies pour repérer des écarts financiers anormaux ce mois-ci.
- Un id (vehicule_id, client_id, proprietaire_id...) retourné par un outil sert UNIQUEMENT à enchaîner une requête suivante (ex: retrouver le nom du client). Ne l'affiche jamais tel quel dans ta réponse finale.
- Enchaîne plusieurs appels d'outils si nécessaire avant de répondre (ex: locations en retard → puis vehicules correspondants pour donner marque/modèle).
- Si une donnée n'est pas disponible via les outils, dis-le clairement plutôt que d'inventer.

SIMULATIONS "ET SI ?" :
Quand on te demande l'impact d'un changement hypothétique (ex: baisse de prix, hausse du taux d'occupation), n'invente jamais de chiffre : appuie-toi d'abord sur l'historique réel via aggregate_table/query_table (ex: revenu moyen par jour loué sur les 3 derniers mois pour ce véhicule), pose l'hypothèse clairement ("en supposant un taux d'occupation similaire"), puis projette le calcul. Présente toujours la situation actuelle ET la situation simulée côte à côte, avec l'écart en DA et en %.

CARTES VISUELLES :
Quand ta réponse compare des chiffres (plusieurs véhicules, plusieurs mois, plusieurs catégories de dépenses...), ajoute EN PLUS de ton explication un bloc de code avec le langage "karossa-chart" contenant un JSON strict au format :
```karossa-chart
{"type":"bar","title":"Titre court","unit":"DA","data":[{"label":"Janvier","value":125000},{"label":"Février","value":98000}]}
```
Un seul bloc karossa-chart par réponse, avec 2 à 8 entrées maximum, valeurs numériques uniquement (jamais d'UUID en label). N'utilise ce bloc que si un vrai chiffre comparatif est disponible ; sinon n'en mets pas.
''';
}