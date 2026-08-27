// lib/features/ai/data/ai_tools_executor.dart
//
// Donne à Gemini la capacité d'interroger la BDD lui-même (function calling),
// avec des garde-fous stricts :
//  - liste blanche de tables/colonnes (voir ai_schema.dart)
//  - showroom_id TOUJOURS forcé côté serveur (jamais fourni par l'IA)
//  - lecture seule uniquement (aucun insert/update/delete exposé)
//  - limite de lignes plafonnée

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/utils/app_logger.dart';
import 'ai_schema.dart';

class AiTools {
  /// Déclarations exposées au modèle Gemini.
  static List<Tool> get tools => [
        Tool(functionDeclarations: [
          FunctionDeclaration(
            'query_table',
            'Lit des lignes dans une table autorisée du showroom (déjà filtré '
                'automatiquement sur le showroom courant). Retourne un tableau JSON.',
            Schema.object(properties: {
              'table': Schema.string(
                description:
                    'Nom exact de la table parmi : ${kAiAllowedTables.keys.join(', ')}',
              ),
              'columns': Schema.string(
                description:
                    'Colonnes séparées par des virgules à retourner (ex: "marque,modele,statut"). '
                    'Laisser vide pour toutes les colonnes autorisées.',
              ),
              'filters': Schema.string(
                description:
                    'Filtres au format JSON. Égalité simple : {"statut":"disponible"}. '
                    'Opérateur explicite : {"kilometrage":{"op":"gte","value":100000}}. '
                    'Opérateurs supportés : eq, neq, gt, gte, lt, lte, like. Laisser vide si aucun filtre.',
              ),
              'order_by': Schema.string(
                description: 'Colonne de tri (optionnel).',
              ),
              'ascending': Schema.boolean(
                description: 'true = croissant, false = décroissant (défaut true).',
              ),
              'limit': Schema.integer(
                description: 'Nombre max de lignes (défaut 20, plafond 200).',
              ),
            }, requiredProperties: [
              'table',
            ]),
          ),
          FunctionDeclaration(
            'aggregate_table',
            'Calcule un agrégat (sum, avg, count, min, max) sur une colonne numérique '
                "d'une table autorisée, sans rapatrier les lignes une à une. "
                'À privilégier pour toute question de type "total", "combien", "moyenne".',
            Schema.object(properties: {
              'table': Schema.string(
                description: 'Nom exact de la table parmi : ${kAiAllowedTables.keys.join(', ')}',
              ),
              'column': Schema.string(
                description: 'Colonne numérique à agréger (voir colonnes agrégeables autorisées).',
              ),
              'operation': Schema.string(
                description: 'Une de : sum, avg, count, min, max',
              ),
              'filters': Schema.string(
                description: 'Filtres JSON, même format que query_table. Optionnel.',
              ),
            }, requiredProperties: [
              'table',
              'operation',
            ]),
          ),
          FunctionDeclaration(
            'detect_anomalies',
            "Compare les dépenses/recettes de caisse du mois en cours à la moyenne des 3 mois "
                "précédents, par catégorie, et retourne les écarts significatifs. À utiliser pour "
                'toute question du type "y a-t-il quelque chose d\'anormal", "surveille mes dépenses", '
                '"détecte les anomalies".',
            Schema.object(properties: {
              'seuil_pct': Schema.integer(
                description:
                    "Seuil de variation en % au-delà duquel un écart est considéré comme anormal (défaut 30).",
              ),
            }),
          ),
          FunctionDeclaration(
            'get_dashboard_summary',
            'Retourne en un seul appel une photo instantanée du showroom : répartition '
                'du parc par statut, locations en cours, chiffre du mois (ventes + locations), '
                "solde de caisse du mois, alertes d'entretien actives. À utiliser pour toute "
                'question générale du type "comment va mon business", "résumé", "état des lieux".',
            Schema.object(properties: {}),
          ),
        ]),
      ];
}

class AiToolsExecutor {
  final SupabaseClient _client;
  final String showroomId;

  static const int _defaultLimit = 20;
  static const int _maxLimit = 200;
  static const int _aggregateRowCap = 1000;

  AiToolsExecutor(this._client, {required this.showroomId});

  Future<Map<String, dynamic>> execute(String name, Map<String, Object?> args) async {
    try {
      switch (name) {
        case 'query_table':
          return await _queryTable(args);
        case 'aggregate_table':
          return await _aggregateTable(args);
        case 'detect_anomalies':
          return await _detectAnomalies(args);
        case 'get_dashboard_summary':
          return await _dashboardSummary();
        default:
          return {'error': 'Fonction inconnue : $name'};
      }
    } catch (e) {
      AppLogger.e('AiToolsExecutor erreur sur $name', error: e);
      return {'error': 'Échec de la requête : ${e.toString()}'};
    }
  }

  // ---------------------------------------------------------------------
  // query_table
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> _queryTable(Map<String, Object?> args) async {
    final table = args['table'] as String?;
    if (table == null || !kAiAllowedTables.containsKey(table)) {
      return {'error': 'Table non autorisée : $table'};
    }

    final allowedCols = kAiAllowedTables[table]!;
    final requestedCols = (args['columns'] as String?)
        ?.split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    final cols = (requestedCols == null || requestedCols.isEmpty)
        ? allowedCols
        : requestedCols.where((c) => allowedCols.contains(c)).toList();
    final selectClause = (cols.isEmpty ? allowedCols : cols).join(',');

    var query = _client.from(table).select(selectClause).eq('showroom_id', showroomId);

    query = _applyFilters(query, table, args['filters'] as String?);

    final orderBy = args['order_by'] as String?;
    int limit = (args['limit'] as int?) ?? _defaultLimit;
    if (limit <= 0) limit = _defaultLimit;
    if (limit > _maxLimit) limit = _maxLimit;

    final List<dynamic> data;
    if (orderBy != null && allowedCols.contains(orderBy)) {
      final asc = (args['ascending'] as bool?) ?? true;
      data = await query.order(orderBy, ascending: asc).limit(limit);
    } else {
      data = await query.limit(limit);
    }

    return {
      'table': table,
      'row_count': data.length,
      'rows': List<Map<String, dynamic>>.from(data),
    };
  }

  // ---------------------------------------------------------------------
  // aggregate_table
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> _aggregateTable(Map<String, Object?> args) async {
    final table = args['table'] as String?;
    final operation = (args['operation'] as String?)?.toLowerCase();
    if (table == null || !kAiAllowedTables.containsKey(table)) {
      return {'error': 'Table non autorisée : $table'};
    }
    if (operation == null || !['sum', 'avg', 'count', 'min', 'max'].contains(operation)) {
      return {'error': 'Opération non supportée : $operation'};
    }

    if (operation == 'count') {
      var query = _client.from(table).select('id').eq('showroom_id', showroomId);
      query = _applyFilters(query, table, args['filters'] as String?);
      final data = await query.limit(_aggregateRowCap);
      return {'table': table, 'operation': 'count', 'result': data.length};
    }

    final column = args['column'] as String?;
    final aggCols = kAiAggregatableColumns[table] ?? [];
    if (column == null || !aggCols.contains(column)) {
      return {'error': 'Colonne non agrégeable : $column (autorisées : ${aggCols.join(', ')})'};
    }

    var query = _client.from(table).select(column).eq('showroom_id', showroomId);
    query = _applyFilters(query, table, args['filters'] as String?);
    final data = await query.limit(_aggregateRowCap);

    final values = data
        .map((row) => (row as Map<String, dynamic>)[column])
        .where((v) => v != null)
        .map((v) => (v as num).toDouble())
        .toList();

    if (values.isEmpty) {
      return {'table': table, 'column': column, 'operation': operation, 'result': 0, 'row_count': 0};
    }

    double result;
    switch (operation) {
      case 'sum':
        result = values.fold(0.0, (a, b) => a + b);
        break;
      case 'avg':
        result = values.fold(0.0, (a, b) => a + b) / values.length;
        break;
      case 'min':
        result = values.reduce((a, b) => a < b ? a : b);
        break;
      case 'max':
        result = values.reduce((a, b) => a > b ? a : b);
        break;
      default:
        result = 0;
    }

    return {
      'table': table,
      'column': column,
      'operation': operation,
      'result': result,
      'row_count': values.length,
      'note': values.length >= _aggregateRowCap
          ? 'Résultat calculé sur les $_aggregateRowCap premières lignes (plafond atteint).'
          : null,
    };
  }

  // ---------------------------------------------------------------------
  // detect_anomalies
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> _detectAnomalies(Map<String, Object?> args) async {
    final seuilPct = ((args['seuil_pct'] as int?) ?? 30).clamp(5, 500);

    final now = DateTime.now();
    // Début du mois M-3 jusqu'à aujourd'hui : 4 mois de données au total.
    final rangeStart = DateTime(now.year, now.month - 3, 1);
    final rangeStartIso = rangeStart.toIso8601String().substring(0, 10);
    final currentMonthStartIso =
        DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);

    final rows = await _client
        .from('caisse_operations')
        .select('categorie,type,montant,date_op')
        .eq('showroom_id', showroomId)
        .gte('date_op', rangeStartIso)
        .limit(_aggregateRowCap);

    // clé = "categorie|type" -> {mois "YYYY-MM": total}
    final buckets = <String, Map<String, double>>{};
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      final categorie = row['categorie'] as String? ?? 'autre';
      final type = row['type'] as String? ?? 'sortie';
      final montant = (row['montant'] as num?)?.toDouble() ?? 0;
      final dateOp = row['date_op'] as String? ?? '';
      if (dateOp.length < 7) continue;
      final moisKey = dateOp.substring(0, 7); // "YYYY-MM"
      final key = '$categorie|$type';
      buckets.putIfAbsent(key, () => {});
      buckets[key]![moisKey] = (buckets[key]![moisKey] ?? 0) + montant;
    }

    final currentMoisKey = currentMonthStartIso.substring(0, 7);
    final anomalies = <Map<String, dynamic>>[];

    for (final entry in buckets.entries) {
      final parts = entry.key.split('|');
      final categorie = parts[0];
      final type = parts[1];
      final moisData = entry.value;

      final currentVal = moisData[currentMoisKey] ?? 0;
      final moisPrecedents = moisData.entries.where((e) => e.key != currentMoisKey).toList();
      if (moisPrecedents.isEmpty) continue; // pas d'historique de comparaison

      final moyenne =
          moisPrecedents.fold<double>(0, (a, e) => a + e.value) / moisPrecedents.length;

      double variationPct;
      if (moyenne == 0) {
        if (currentVal == 0) continue;
        variationPct = 100; // nouvelle catégorie de dépense/recette apparue
      } else {
        variationPct = ((currentVal - moyenne) / moyenne) * 100;
      }

      if (variationPct.abs() >= seuilPct) {
        anomalies.add({
          'categorie': categorie,
          'type': type,
          'montant_mois_courant_da': currentVal,
          'moyenne_3_mois_precedents_da': moyenne,
          'variation_pct': variationPct.round(),
        });
      }
    }

    anomalies.sort((a, b) =>
        (b['variation_pct'] as int).abs().compareTo((a['variation_pct'] as int).abs()));

    return {
      'seuil_pct': seuilPct,
      'mois_analyse': currentMoisKey,
      'anomalies_detectees': anomalies,
    };
  }

  // ---------------------------------------------------------------------
  // get_dashboard_summary
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> _dashboardSummary() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);

    final vehicules = await _client
        .from('vehicules')
        .select('statut')
        .eq('showroom_id', showroomId)
        .limit(_aggregateRowCap);
    final parStatut = <String, int>{};
    for (final v in vehicules) {
      final s = (v as Map<String, dynamic>)['statut'] as String? ?? 'inconnu';
      parStatut[s] = (parStatut[s] ?? 0) + 1;
    }

    final locationsEnCours = await _client
        .from('locations')
        .select('id')
        .eq('showroom_id', showroomId)
        .eq('statut', 'en_cours')
        .limit(_aggregateRowCap);

    final ventesMois = await _client
        .from('ventes')
        .select('prix_vente')
        .eq('showroom_id', showroomId)
        .gte('date_vente', startOfMonth)
        .limit(_aggregateRowCap);
    final caVentesMois = ventesMois.fold<double>(
        0, (a, r) => a + (((r as Map<String, dynamic>)['prix_vente'] as num?)?.toDouble() ?? 0));

    final locationsMois = await _client
        .from('locations')
        .select('montant_brut')
        .eq('showroom_id', showroomId)
        .gte('date_debut', startOfMonth)
        .limit(_aggregateRowCap);
    final caLocationsMois = locationsMois.fold<double>(
        0, (a, r) => a + (((r as Map<String, dynamic>)['montant_brut'] as num?)?.toDouble() ?? 0));

    final caisseMois = await _client
        .from('caisse_operations')
        .select('type,montant')
        .eq('showroom_id', showroomId)
        .gte('date_op', startOfMonth)
        .limit(_aggregateRowCap);
    double entrees = 0, sorties = 0;
    for (final op in caisseMois) {
      final m = ((op as Map<String, dynamic>)['montant'] as num?)?.toDouble() ?? 0;
      if (op['type'] == 'entree') {
        entrees += m;
      } else {
        sorties += m;
      }
    }

    final alertesActives = await _client
        .from('alertes_entretien')
        .select('id')
        .eq('showroom_id', showroomId)
        .eq('statut', 'active')
        .limit(_aggregateRowCap);

    return {
      'parc_par_statut': parStatut,
      'locations_en_cours': locationsEnCours.length,
      'chiffre_affaires_ventes_ce_mois_da': caVentesMois,
      'chiffre_affaires_locations_ce_mois_da': caLocationsMois,
      'caisse_ce_mois_da': {'entrees': entrees, 'sorties': sorties, 'solde': entrees - sorties},
      'alertes_entretien_actives': alertesActives.length,
      'periode': 'depuis le $startOfMonth',
    };
  }

  // ---------------------------------------------------------------------
  // Filtres JSON → PostgrestFilterBuilder
  // ---------------------------------------------------------------------
  PostgrestFilterBuilder<T> _applyFilters<T>(
      PostgrestFilterBuilder<T> query, String table, String? filtersJson) {
    if (filtersJson == null || filtersJson.trim().isEmpty) return query;

    final allowedCols = kAiAllowedTables[table]!;
    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(filtersJson) as Map<String, dynamic>;
    } catch (_) {
      return query; // filtres illisibles : on ignore plutôt que de planter
    }

    for (final entry in parsed.entries) {
      final col = entry.key;
      if (col == 'showroom_id' || !allowedCols.contains(col)) continue; // jamais overridable

      final value = entry.value;
      if (value is Map<String, dynamic>) {
        final op = (value['op'] as String?)?.toLowerCase() ?? 'eq';
        final v = value['value'];
        if (v == null) continue;
        switch (op) {
          case 'gte':
            query = query.gte(col, v);
            break;
          case 'lte':
            query = query.lte(col, v);
            break;
          case 'gt':
            query = query.gt(col, v);
            break;
          case 'lt':
            query = query.lt(col, v);
            break;
          case 'neq':
            query = query.neq(col, v);
            break;
          case 'like':
            query = query.ilike(col, '%$v%');
            break;
          default:
            query = query.eq(col, v);
        }
      } else {
        query = query.eq(col, value);
      }
    }
    return query;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AiActionExecutor — la partie "IA qui agit"
// ═══════════════════════════════════════════════════════════════════════
//
// KarossaAI ne peut JAMAIS écrire en base de sa propre initiative : le
// function-calling Gemini reste 100% lecture seule (voir AiToolsExecutor
// ci-dessus). Quand une action est pertinente, le modèle se contente de
// proposer un bloc ```karossa-action {...}``` dans sa réponse (voir consigne
// de prompt système). L'UI affiche alors une carte de confirmation, et ce
// n'est QUE si l'utilisateur appuie sur "Confirmer" que ce executor exécute
// une des actions ci-dessous, choisies dans une liste blanche fermée.
enum AiActionType {
  creerAlerteEntretien,
  creerAlerteIa,
}

extension AiActionTypeX on AiActionType {
  static AiActionType? fromKey(String key) => switch (key) {
        'creer_alerte_entretien' => AiActionType.creerAlerteEntretien,
        'creer_alerte_ia' => AiActionType.creerAlerteIa,
        _ => null,
      };
}

class AiActionResult {
  final bool success;
  final String message;
  const AiActionResult(this.success, this.message);
}

class AiActionExecutor {
  final SupabaseClient _client;
  final String showroomId;

  AiActionExecutor(this._client, {required this.showroomId});

  Future<AiActionResult> execute(String actionKey, Map<String, dynamic> payload) async {
    final type = AiActionTypeX.fromKey(actionKey);
    if (type == null) {
      return const AiActionResult(false, 'Action inconnue ou non autorisée.');
    }
    try {
      switch (type) {
        case AiActionType.creerAlerteEntretien:
          return await _creerAlerteEntretien(payload);
        case AiActionType.creerAlerteIa:
          return await _creerAlerteIa(payload);
      }
    } catch (e) {
      AppLogger.e('AiActionExecutor erreur sur $actionKey', error: e);
      return AiActionResult(false, 'Échec de l\'action : ${e.toString()}');
    }
  }

  Future<AiActionResult> _creerAlerteEntretien(Map<String, dynamic> payload) async {
    const typesValides = {
      'vidange', 'controle_technique', 'assurance', 'vignette', 'pneus', 'autre'
    };
    final typeAlerte = (payload['type_alerte'] as String?) ?? 'autre';
    if (!typesValides.contains(typeAlerte)) {
      return const AiActionResult(false, 'Type d\'alerte non reconnu.');
    }

    String? vehiculeId = payload['vehicule_id'] as String?;
    final immatriculation = payload['immatriculation'] as String?;
    if (vehiculeId == null && immatriculation != null && immatriculation.isNotEmpty) {
      final match = await _client
          .from('vehicules')
          .select('id')
          .eq('showroom_id', showroomId)
          .eq('immatriculation', immatriculation)
          .maybeSingle();
      vehiculeId = match?['id'] as String?;
    }
    if (vehiculeId == null) {
      return const AiActionResult(false, 'Véhicule introuvable pour créer l\'alerte.');
    }

    await _client.from('alertes_entretien').insert({
      'vehicule_id': vehiculeId,
      'showroom_id': showroomId,
      'type_alerte': typeAlerte,
      'date_echeance': payload['date_echeance'],
      'km_echeance': payload['km_echeance'],
      'description': payload['description'] ?? 'Créée par KarossaAI',
      'statut': 'active',
    });
    return const AiActionResult(true, 'Alerte d\'entretien créée.');
  }

  Future<AiActionResult> _creerAlerteIa(Map<String, dynamic> payload) async {
    const typesValides = {
      'anomalie_financiere', 'entretien', 'rentabilite', 'opportunite', 'autre'
    };
    const severitesValides = {'info', 'attention', 'urgent'};
    final type = (payload['type'] as String?) ?? 'autre';
    final severite = (payload['severite'] as String?) ?? 'info';
    final titre = (payload['titre'] as String?)?.trim();
    final message = (payload['message'] as String?)?.trim();

    if (titre == null || titre.isEmpty || message == null || message.isEmpty) {
      return const AiActionResult(false, 'Titre ou message manquant.');
    }

    await _client.from('ai_alertes').insert({
      'showroom_id': showroomId,
      'type': typesValides.contains(type) ? type : 'autre',
      'titre': titre,
      'message': message,
      'severite': severitesValides.contains(severite) ? severite : 'info',
      'lue': false,
    });
    // Cette alerte apparaîtra automatiquement dans la carte "Insight du jour"
    // et le badge du FAB IA, sans code UI supplémentaire à écrire.
    return const AiActionResult(true, 'Rappel enregistré — visible depuis le tableau de bord.');
  }
}