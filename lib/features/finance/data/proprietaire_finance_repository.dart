// lib/features/finance/data/proprietaire_finance_repository.dart
//
// Vue financière consolidée par bénéficiaire (propriétaire/associé OU gérant) :
//   - véhicules détenus (vehicule_proprietes)               [propriétaire/associé uniquement]
//   - gains issus des locations (location_repartitions)
//   - gains issus des ventes & échanges (transaction_repartitions, polymorphique)
//   - versements déjà effectués (versements_proprietaires)
//
// Le `type_part` ('part_proprietaire' ou 'commission_gerant') détermine quelle
// part de l'argent réparti on regarde : un même profil peut cumuler les deux
// rôles (ex. un gérant copropriétaire d'un véhicule) — chaque rôle a son écran
// dédié, mais partage ce repository pour éviter la duplication de requêtes.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/proprietaire_solde_model.dart';
import '../domain/versement_model.dart';
import '../domain/transfert_model.dart';

export '../domain/versement_model.dart' show TypePart;

class ProprietaireFinanceRepository {
  ProprietaireFinanceRepository(this._client, {required this.showroomId});

  final SupabaseClient _client;
  final String showroomId;

  /// Charge l'intégralité du dossier financier d'un bénéficiaire.
  ///
  /// [typePart] détermine si on consolide les parts de copropriété
  /// (propriétaire/associé) ou les commissions (gérant). Les véhicules
  /// détenus ne sont chargés que pour [TypePart.partProprietaire] — un
  /// gérant n'a pas de "véhicules détenus" au sens de la copropriété,
  /// même s'il peut en avoir un séparément via son propre profil propriétaire.
  Future<ProprietaireSolde> getSolde(
    String proprietaireId, {
    TypePart typePart = TypePart.partProprietaire,
  }) async {
    try {
      final vehicules = typePart == TypePart.partProprietaire
          ? await _getVehicules(proprietaireId)
          : <VehiculePart>[];

      final results = await Future.wait<dynamic>([
        _getGainsLocations(proprietaireId, typePart),
        _getGainsVentesEtEchanges(proprietaireId, typePart),
        _getVersements(proprietaireId, typePart),
        // Les dépenses concernent tout bénéficiaire : la part déduite au
        // prorata (copropriétaire) ET les remboursements dus à qui a payé
        // de sa poche (gérant, associé ou propriétaire, peu importe s'il
        // détient une part du véhicule concerné).
        _getDepenses(proprietaireId, vehicules),
        _getTransfertsEnvoyes(proprietaireId),
        _getTransfertsRecus(proprietaireId),
      ]);

      final gains = <LigneGain>[
        ...(results[0] as List<LigneGain>),
        ...(results[1] as List<LigneGain>),
      ]..sort((a, b) => b.date.compareTo(a.date));

      return ProprietaireSolde(
        proprietaireId: proprietaireId,
        vehicules: vehicules,
        gains: gains,
        versements: results[2] as List<Versement>,
        depenses: (results[3] as List<LigneDepense>)
          ..sort((a, b) => b.date.compareTo(a.date)),
        transfertsEnvoyes: results[4] as List<TransfertUtilisateur>,
        transfertsRecus: results[5] as List<TransfertUtilisateur>,
      );
    } catch (e, st) {
      AppLogger.e('ProprietaireFinanceRepository.getSolde', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Véhicules détenus (propriétaire/associé uniquement) ─────────────────

  Future<List<VehiculePart>> _getVehicules(String proprietaireId) async {
    final data = await _client
        .from('vehicule_proprietes')
        .select('part_pct, vehicules(id, marque, modele, immatriculation, statut)')
        .eq('proprietaire_id', proprietaireId);

    return (data as List).map((row) {
      final v = row['vehicules'] as Map<String, dynamic>;
      final immat = v['immatriculation'] as String?;
      return VehiculePart(
        vehiculeId: v['id'] as String,
        label: '${v['marque']} ${v['modele']}${immat != null ? ' ($immat)' : ''}',
        partPct: (row['part_pct'] as num).toDouble(),
        statut: v['statut'] as String,
      );
    }).toList();
  }

  // ── Dépenses (réparations + autres frais véhicule) ───────────────────────
  //
  // Pour les réparations, chaque ligne de reparation_paiements distingue :
  //   - qui a PAYÉ  (payeur_type / proprietaire_id)      → à rembourser
  //     intégralement si ce n'est pas le showroom.
  //   - qui doit RÉELLEMENT SUPPORTER le coût (debiteur_id) → déduit de son
  //     solde. Si non renseigné : réparti au prorata des copropriétaires du
  //     véhicule (comportement historique). Si renseigné : 100% du montant
  //     déduit de ce profil précis, qu'il possède le véhicule ou non — c'est
  //     ce qui permet de "transférer" une dépense d'un payeur vers un
  //     responsable désigné dans le bilan financier.
  //
  // Pour les autres frais (caisse_operations), le modèle plus simple
  // d'origine est conservé : payee_par 'showroom' → prorata copropriétaires,
  // 'proprietaire' → remboursement intégral, sans notion de débiteur désigné.

  Future<List<LigneDepense>> _getDepenses(
    String proprietaireId,
    List<VehiculePart> vehicules,
  ) async {
    final vehiculeIds = vehicules.map((v) => v.vehiculeId).toList();
    final partPctByVehicule = {for (final v in vehicules) v.vehiculeId: v.partPct};
    final labelByVehicule = {for (final v in vehicules) v.vehiculeId: v.label};

    const autresCategories = [
      'entretien', 'carburant', 'assurance', 'controle_technique', 'lavage', 'autre',
    ];

    final depenses = <LigneDepense>[];
    final idsVus = <String>{};

    void ajouter(LigneDepense? d) {
      if (d != null && idsVus.add(d.id)) depenses.add(d);
    }

    String labelFor(String? vehId, Map<String, dynamic>? veh) =>
        labelByVehicule[vehId] ??
        (veh != null ? '${veh['marque']} ${veh['modele']}' : 'Véhicule');

    // 1a) Réparations — part déduite au prorata sur les véhicules qu'il
    // détient, uniquement pour les lignes SANS débiteur désigné.
    if (vehiculeIds.isNotEmpty) {
      final prorataRows = await _client
          .from('reparation_paiements')
          .select('id, montant, '
              'reparations!inner(id, type_rep, date_rep, vehicule_id, deductible)')
          .isFilter('debiteur_id', null)
          .eq('reparations.deductible', true)
          .inFilter('reparations.vehicule_id', vehiculeIds);

      for (final row in (prorataRows as List)) {
        final r = row['reparations'] as Map<String, dynamic>;
        final vehId = r['vehicule_id'] as String;
        final partPct = partPctByVehicule[vehId]!;
        final montantPaye = (row['montant'] as num).toDouble();
        ajouter(LigneDepense(
          id: row['id'] as String,
          categorie: r['type_rep'] as String,
          vehiculeLabel: labelByVehicule[vehId]!,
          coutTotal: montantPaye,
          partPct: partPct,
          montant: montantPaye * partPct / 100,
          date: DateTime.parse(r['date_rep'] as String),
          aRembourser: false,
        ));
      }
    }

    // 1b) Réparations — lignes où CE profil est le débiteur désigné : 100%
    // du montant lui est imputé, indépendamment de la propriété du véhicule.
    final debiteurRows = await _client
        .from('reparation_paiements')
        .select('id, montant, '
            'reparations!inner(id, type_rep, date_rep, vehicule_id, deductible, vehicules(marque, modele))')
        .eq('debiteur_id', proprietaireId)
        .eq('reparations.deductible', true);

    for (final row in (debiteurRows as List)) {
      final r = row['reparations'] as Map<String, dynamic>;
      final montant = (row['montant'] as num).toDouble();
      ajouter(LigneDepense(
        id: row['id'] as String,
        categorie: r['type_rep'] as String,
        vehiculeLabel: labelFor(r['vehicule_id'] as String?, r['vehicules'] as Map<String, dynamic>?),
        coutTotal: montant,
        partPct: 100,
        montant: montant,
        date: DateTime.parse(r['date_rep'] as String),
        aRembourser: false,
      ));
    }

    // 1c) Autres frais (caisse_operations) — logique d'origine inchangée.
    if (vehiculeIds.isNotEmpty) {
      final caisseRows = await _client
          .from('caisse_operations')
          .select('id, categorie, montant, date_op, vehicule_id, payee_par, proprietaire_payeur_id')
          .inFilter('vehicule_id', vehiculeIds)
          .eq('type', 'sortie')
          .eq('payee_par', 'showroom')
          .inFilter('categorie', autresCategories);

      for (final row in (caisseRows as List)) {
        final vehId = row['vehicule_id'] as String;
        ajouter(_depenseFromRow(
          id: row['id'] as String,
          categorie: row['categorie'] as String,
          cout: (row['montant'] as num).toDouble(),
          dateStr: row['date_op'] as String,
          payeePar: row['payee_par'] as String?,
          proprietairePayeurId: row['proprietaire_payeur_id'] as String?,
          proprietaireId: proprietaireId,
          partPct: partPctByVehicule[vehId]!,
          vehiculeLabel: labelByVehicule[vehId]!,
        ));
      }
    }

    // 2) Remboursements dus : peu importe s'il détient le véhicule — n'importe
    // quel profil (gérant, associé, propriétaire) peut avoir avancé les frais.
    // Chaque ligne de reparation_paiements où il est le payeur = un
    // remboursement intégral de la portion qu'il a avancée, que le coût soit
    // ensuite reparti au prorata ou imputé à un débiteur désigné (les deux
    // effets — remboursement au payeur et déduction chez le débiteur — sont
    // indépendants et peuvent viser deux profils différents).
    final reparationsRemb = await _client
        .from('reparation_paiements')
        .select('id, montant, '
            'reparations!inner(id, type_rep, date_rep, deductible, vehicule_id, vehicules(marque, modele))')
        .eq('payeur_type', 'proprietaire')
        .eq('proprietaire_id', proprietaireId)
        .eq('reparations.deductible', true);

    for (final row in (reparationsRemb as List)) {
      final r = row['reparations'] as Map<String, dynamic>;
      final montantAvance = (row['montant'] as num).toDouble();
      ajouter(LigneDepense(
        id: '${row['id']}-remb',
        categorie: r['type_rep'] as String,
        vehiculeLabel: labelFor(r['vehicule_id'] as String?, r['vehicules'] as Map<String, dynamic>?),
        coutTotal: montantAvance,
        partPct: 100,
        montant: montantAvance,
        date: DateTime.parse(r['date_rep'] as String),
        aRembourser: true,
      ));
    }

    final caisseRemb = await _client
        .from('caisse_operations')
        .select('id, categorie, montant, date_op, vehicule_id, vehicules(marque, modele)')
        .eq('type', 'sortie')
        .eq('payee_par', 'proprietaire')
        .eq('proprietaire_payeur_id', proprietaireId)
        .inFilter('categorie', autresCategories);

    for (final row in (caisseRemb as List)) {
      final veh = row['vehicules'] as Map<String, dynamic>?;
      final label = labelByVehicule[row['vehicule_id']] ??
          (veh != null ? '${veh['marque']} ${veh['modele']}' : 'Véhicule');
      ajouter(LigneDepense(
        id: row['id'] as String,
        categorie: row['categorie'] as String,
        vehiculeLabel: label,
        coutTotal: (row['montant'] as num).toDouble(),
        partPct: 100,
        montant: (row['montant'] as num).toDouble(),
        date: DateTime.parse(row['date_op'] as String),
        aRembourser: true,
      ));
    }

    return depenses;
  }

  /// Construit une [LigneDepense] "part déduite" pour [proprietaireId] à
  /// partir d'une ligne payée par le showroom, ou `null` si elle n'est en
  /// fait pas payée par le showroom (garde-fou, ne devrait pas arriver vu
  /// le filtre `.eq('payee_par', 'showroom')` en amont).
  LigneDepense? _depenseFromRow({
    required String id,
    required String categorie,
    required double cout,
    required String dateStr,
    required String? payeePar,
    required String? proprietairePayeurId,
    required String proprietaireId,
    required double partPct,
    required String vehiculeLabel,
  }) {
    if (payeePar == 'proprietaire') return null; // géré séparément, cf. plus haut
    return LigneDepense(
      id: id,
      categorie: categorie,
      vehiculeLabel: vehiculeLabel,
      coutTotal: cout,
      partPct: partPct,
      montant: cout * partPct / 100,
      date: DateTime.parse(dateStr),
      aRembourser: false,
    );
  }

  // ── Gains locations ─────────────────────────────────────────────────────

  Future<List<LigneGain>> _getGainsLocations(
    String proprietaireId,
    TypePart typePart,
  ) async {
    final data = await _client
        .from('location_repartitions')
        .select(
          'id, montant, pourcentage, created_at, '
          'locations(date_debut, vehicules(marque, modele))',
        )
        .eq('beneficiaire_id', proprietaireId)
        .eq('type_part', typePart.value);

    return (data as List).map((row) {
      final loc = row['locations'] as Map<String, dynamic>?;
      final veh = loc?['vehicules'] as Map<String, dynamic>?;
      final label = veh != null ? '${veh['marque']} ${veh['modele']}' : 'Location';
      final dateStr = loc?['date_debut'] as String?;
      return LigneGain(
        id: row['id'] as String,
        typeOperation: 'location',
        vehiculeLabel: label,
        pourcentage: (row['pourcentage'] as num).toDouble(),
        montant: (row['montant'] as num).toDouble(),
        date: dateStr != null
            ? DateTime.parse(dateStr)
            : DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  // ── Gains ventes & échanges (table polymorphique) ───────────────────────

  Future<List<LigneGain>> _getGainsVentesEtEchanges(
    String proprietaireId,
    TypePart typePart,
  ) async {
    final data = await _client
        .from('transaction_repartitions')
        .select('id, transaction_type, transaction_id, montant, pourcentage, created_at')
        .eq('beneficiaire_id', proprietaireId)
        .eq('type_part', typePart.value);

    final rows = List<Map<String, dynamic>>.from(data);
    if (rows.isEmpty) return [];

    final venteIds = rows
        .where((r) => r['transaction_type'] == 'vente')
        .map((r) => r['transaction_id'] as String)
        .toList();
    final echangeIds = rows
        .where((r) => r['transaction_type'] == 'echange')
        .map((r) => r['transaction_id'] as String)
        .toList();

    final Map<String, Map<String, dynamic>> ventesById = {};
    final Map<String, Map<String, dynamic>> echangesById = {};

    if (venteIds.isNotEmpty) {
      final ventes = await _client
          .from('ventes')
          .select('id, date_vente, vehicules(marque, modele)')
          .inFilter('id', venteIds);
      for (final v in ventes) {
        ventesById[v['id'] as String] = v as Map<String, dynamic>;
      }
    }

    if (echangeIds.isNotEmpty) {
      final echanges = await _client
          .from('echanges')
          .select('id, date_echange, vehicules!echanges_vehicule_cede_id_fkey(marque, modele)')
          .inFilter('id', echangeIds);
      for (final e in echanges) {
        echangesById[e['id'] as String] = e as Map<String, dynamic>;
      }
    }

    return rows.map((row) {
      final type = row['transaction_type'] as String;
      final txId = row['transaction_id'] as String;
      final source = type == 'vente' ? ventesById[txId] : echangesById[txId];
      final veh = source?['vehicules'] as Map<String, dynamic>?;
      final label = veh != null
          ? '${veh['marque']} ${veh['modele']}'
          : (type == 'vente' ? 'Vente' : 'Échange');
      final dateStr = (source?['date_vente'] ?? source?['date_echange']) as String?;

      return LigneGain(
        id: row['id'] as String,
        typeOperation: type,
        vehiculeLabel: label,
        pourcentage: (row['pourcentage'] as num).toDouble(),
        montant: (row['montant'] as num).toDouble(),
        date: dateStr != null
            ? DateTime.parse(dateStr)
            : DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  // ── Versements déjà effectués ────────────────────────────────────────────

  Future<List<Versement>> _getVersements(
    String proprietaireId,
    TypePart typePart,
  ) async {
    final data = await _client
        .from('versements_proprietaires')
        .select()
        .eq('proprietaire_id', proprietaireId)
        .eq('type_part', typePart.value)
        .order('date_versement', ascending: false);

    return (data as List)
        .map((j) => Versement.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ── Création d'un versement ──────────────────────────────────────────────

  /// Enregistre un versement et la sortie de caisse correspondante de façon
  /// traçable (via versement_proprietaire_id sur caisse_operations).
  ///
  /// [typePart] doit correspondre à l'écran d'où l'appel est fait (solde
  /// propriétaire ou commission gérant), pour que ce versement soit compté
  /// dans le bon solde et n'apparaisse pas dans l'autre écran de la même
  /// personne si elle cumule les deux rôles.
  Future<Versement> creerVersement({
    required String proprietaireId,
    required double montant,
    required DateTime dateVersement,
    ModeVersement? mode,
    String? notes,
    String? createdBy,
    TypePart typePart = TypePart.partProprietaire,
  }) async {
    try {
      final versementData = {
        'showroom_id': showroomId,
        'proprietaire_id': proprietaireId,
        'montant': montant,
        'date_versement': dateVersement.toIso8601String().split('T').first,
        'type_part': typePart.value,
        if (mode != null) 'mode': mode.name,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (createdBy != null) 'created_by': createdBy,
      };

      final result = await _client
          .from('versements_proprietaires')
          .insert(versementData)
          .select()
          .single();

      // Trace la sortie de caisse correspondante pour garder un solde de
      // trésorerie exact (cohérent avec le reste du module caisse).
      final description = typePart == TypePart.commissionGerant
          ? 'Versement commission gérant'
          : 'Versement propriétaire';
      await _client.from('caisse_operations').insert({
        'showroom_id': showroomId,
        'type': 'sortie',
        'categorie': 'versement_proprietaire',
        'montant': montant,
        'description': description,
        'date_op': dateVersement.toIso8601String().split('T').first,
        'versement_proprietaire_id': result['id'],
        if (createdBy != null) 'created_by': createdBy,
      });

      return Versement.fromJson(result);
    } catch (e, st) {
      AppLogger.e('ProprietaireFinanceRepository.creerVersement', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> supprimerVersement(String versementId) async {
    try {
      // La FK caisse_operations.versement_proprietaire_id n'a pas de ON DELETE
      // CASCADE par défaut → on retire d'abord la trace caisse, puis le versement.
      await _client
          .from('caisse_operations')
          .delete()
          .eq('versement_proprietaire_id', versementId)
          .eq('showroom_id', showroomId); // ✅ verrou anti cross-tenant

      final deleted = await _client
          .from('versements_proprietaires')
          .delete()
          .eq('id', versementId)
          .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
          .select('id');

      if (deleted.isEmpty) {
        // Rien n'a été supprimé côté base (le plus souvent : bloqué par une
        // policy RLS DELETE manquante ou trop restrictive sur
        // versements_proprietaires/caisse_operations). Supabase ne renvoie
        // pas d'erreur dans ce cas → on la génère nous-mêmes pour que
        // l'utilisateur voie un message au lieu d'un échec silencieux.
        throw Exception(
            "La suppression a été refusée par la base de données (droits d'accès). "
            "Vérifiez les policies RLS sur versements_proprietaires.");
      }
    } catch (e, st) {
      AppLogger.e('ProprietaireFinanceRepository.supprimerVersement', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Transferts entre utilisateurs (indépendants de la caisse réelle) ────
  //
  // Un utilisateur peut donner de l'argent à un autre (gérant, associé ou
  // propriétaire) pour n'importe quel motif. Ça ne touche jamais
  // `caisse_operations` : c'est un solde purement entre deux personnes.

  static const _transfertsSelect = '''
    *,
    payeur:profiles!transferts_utilisateurs_payeur_id_fkey(nom, prenom),
    beneficiaire:profiles!transferts_utilisateurs_beneficiaire_id_fkey(nom, prenom)
  ''';

  Future<List<TransfertUtilisateur>> _getTransfertsEnvoyes(String userId) async {
    final data = await _client
        .from('transferts_utilisateurs')
        .select(_transfertsSelect)
        .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
        .eq('payeur_id', userId)
        .order('date_transfert', ascending: false);
    return (data as List)
        .map((j) => TransfertUtilisateur.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransfertUtilisateur>> _getTransfertsRecus(String userId) async {
    final data = await _client
        .from('transferts_utilisateurs')
        .select(_transfertsSelect)
        .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
        .eq('beneficiaire_id', userId)
        .order('date_transfert', ascending: false);
    return (data as List)
        .map((j) => TransfertUtilisateur.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Enregistre un nouveau transfert d'argent entre deux utilisateurs.
  Future<void> creerTransfert({
    required String payeurId,
    required String beneficiaireId,
    required double montant,
    required String motif,
    bool remboursable = false,
    String? notes,
    DateTime? dateTransfert,
    String? createdBy,
  }) async {
    try {
      final t = TransfertUtilisateur(
        id: '',
        payeurId: payeurId,
        beneficiaireId: beneficiaireId,
        montant: montant,
        motif: motif,
        remboursable: remboursable,
        notes: notes,
        dateTransfert: dateTransfert ?? DateTime.now(),
      );
      await _client.from('transferts_utilisateurs').insert({
        ...t.toInsertJson(),
        'showroom_id': showroomId, // ✅ injection multi-tenant
        if (createdBy != null) 'created_by': createdBy,
      });
    } catch (e, st) {
      AppLogger.e('ProprietaireFinanceRepository.creerTransfert', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Marque un transfert remboursable comme réglé.
  Future<void> marquerTransfertRembourse(String transfertId) async {
    try {
      await _client
          .from('transferts_utilisateurs')
          .update({
            'rembourse': true,
            'date_rembourse': DateTime.now().toIso8601String().split('T').first,
          })
          .eq('id', transfertId)
          .eq('showroom_id', showroomId); // ✅ verrou anti cross-tenant
    } catch (e, st) {
      AppLogger.e('ProprietaireFinanceRepository.marquerTransfertRembourse', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> supprimerTransfert(String transfertId) async {
    try {
      final deleted = await _client
          .from('transferts_utilisateurs')
          .delete()
          .eq('id', transfertId)
          .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
          .select('id');

      if (deleted.isEmpty) {
        throw Exception(
            "La suppression a été refusée par la base de données (droits d'accès). "
            "Vérifiez les policies RLS sur transferts_utilisateurs.");
      }
    } catch (e, st) {
      AppLogger.e('ProprietaireFinanceRepository.supprimerTransfert', error: e, stackTrace: st);
      rethrow;
    }
  }
}