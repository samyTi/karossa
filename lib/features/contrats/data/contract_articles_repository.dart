// lib/features/contrats/data/contract_articles_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/contract_article_model.dart';
import '../../../core/utils/app_logger.dart';

class ContractArticlesRepository {
  ContractArticlesRepository(this._client, {required this.showroomId});

  final SupabaseClient _client;
  final String showroomId;

  // ── Lecture ──────────────────────────────────────────────────────────────

  Future<List<ContractArticle>> getActifs(String contratType) async {
    AppLogger.d('📄 [Articles] getActifs → type=$contratType showroom=$showroomId');
    try {
      final data = await _client
          .from('contract_articles')
          .select()
          .eq('showroom_id', showroomId)
          .eq('contrat_type', contratType)
          .eq('actif', true)
          .order('ordre');
      final list = (data as List).map((j) => ContractArticle.fromJson(j)).toList();
      AppLogger.d('✅ [Articles] getActifs → ${list.length} article(s) récupéré(s)');
      return list;
    } catch (e, st) {
      AppLogger.e('ContractArticlesRepository.getActifs', error: e, stackTrace: st);
      return [];
    }
  }

  Future<List<ContractArticle>> getActifsParLangue(
    String contratType,
    String langue,
  ) async {
    AppLogger.d('📄 [Articles] getActifsParLangue → type=$contratType langue=$langue showroom=$showroomId');
    try {
      final data = await _client
          .from('contract_articles')
          .select()
          .eq('showroom_id', showroomId)
          .eq('contrat_type', contratType)
          .eq('actif', true)
          .eq('langue', langue)
          .order('ordre');
      final list = (data as List).map((j) => ContractArticle.fromJson(j)).toList();
      AppLogger.d('✅ [Articles] getActifsParLangue ($langue) → ${list.length} article(s)');
      return list;
    } catch (e, st) {
      AppLogger.e('ContractArticlesRepository.getActifsParLangue',
          error: e, stackTrace: st);
      return [];
    }
  }

  Future<List<ContractArticle>> getTous(String contratType) async {
    AppLogger.d('📄 [Articles] getTous → type=$contratType showroom=$showroomId');
    try {
      final data = await _client
          .from('contract_articles')
          .select()
          .eq('showroom_id', showroomId)
          .eq('contrat_type', contratType)
          .order('ordre');
      final list = (data as List).map((j) => ContractArticle.fromJson(j)).toList();
      AppLogger.d('✅ [Articles] getTous → ${list.length} article(s)');
      return list;
    } catch (e, st) {
      AppLogger.e('ContractArticlesRepository.getTous', error: e, stackTrace: st);
      return [];
    }
  }

  // ── Écriture ─────────────────────────────────────────────────────────────

  Future<ContractArticle?> creer(ContractArticle article) async {
    try {
      final json = article.toJson();
      if (article.id.isEmpty) json.remove('id');
      json['showroom_id'] = showroomId;

      final data = await _client
          .from('contract_articles')
          .insert(json)
          .select()
          .single();
      return ContractArticle.fromJson(data);
    } catch (e, st) {
      AppLogger.e('ContractArticlesRepository.creer', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<bool> modifier(String id, Map<String, dynamic> data) async {
    try {
      final fullData = {
        ...data,
        'updated_at':  DateTime.now().toIso8601String(),
        'showroom_id': showroomId,
      };

      await _client
          .from('contract_articles')
          .update(fullData)
          .eq('showroom_id', showroomId)
          .eq('id', id);
      return true;
    } catch (e, st) {
      AppLogger.e('ContractArticlesRepository.modifier', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<bool> toggleActif(String id, bool actif) =>
      modifier(id, {'actif': actif});

  Future<void> reordonner(List<ContractArticle> articles) async {
    // ⚠️ Ne PAS utiliser Future.wait ici : des updates concurrents qui
    // permutent des valeurs d'`ordre` déjà utilisées par une autre ligne
    // peuvent se percuter (violation de contrainte d'unicité si elle existe,
    // ou tri final incohérent en cas d'échec partiel puisqu'il n'y a aucune
    // transaction/rollback entre les requêtes).
    //
    // On procède donc en 2 passes SÉQUENTIELLES :
    //   1. On déplace toutes les lignes vers des valeurs temporaires
    //      hautes et garanties uniques (aucune collision possible avec les
    //      valeurs finales, ni avec les valeurs de départ).
    //      🐛 CORRECTIF : l'ancienne version utilisait des valeurs
    //      temporaires NÉGATIVES (-(index+1)). Si la colonne `ordre` a une
    //      contrainte CHECK (ordre >= 0) — ce qui est courant pour une
    //      colonne d'ordre d'affichage — la toute première requête de cette
    //      passe échoue systématiquement, et le glissement (drag & drop)
    //      des clauses ne fonctionne alors jamais, quel que soit le geste
    //      de l'utilisateur. On utilise désormais un offset positif très
    //      élevé, hors de la plage normale des valeurs d'ordre, pour rester
    //      compatible avec ce genre de contrainte.
    //   2. On applique les valeurs finales (0..N-1).
    //
    // En cas d'échec, on NE l'avale PAS silencieusement (contrairement à
    // l'ancienne version qui retournait juste `false`) : on relance
    // l'exception, comme le font `creer`/`modifier`/`supprimer` plus haut,
    // pour que l'écran puisse afficher une erreur à l'utilisateur plutôt que
    // de laisser un tri à moitié appliqué sans aucun retour visuel.
    const tempOffset = 1000000;
    try {
      for (final entry in articles.asMap().entries) {
        await _client
            .from('contract_articles')
            .update({'ordre': tempOffset + entry.key})
            .eq('showroom_id', showroomId)
            .eq('id', entry.value.id);
      }

      for (final entry in articles.asMap().entries) {
        await _client
            .from('contract_articles')
            .update({'ordre': entry.key})
            .eq('showroom_id', showroomId)
            .eq('id', entry.value.id);
      }
    } catch (e, st) {
      AppLogger.e('ContractArticlesRepository.reordonner', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<bool> supprimer(String id) async {
    try {
      await _client
          .from('contract_articles')
          .delete()
          .eq('showroom_id', showroomId)
          .eq('id', id);
      return true;
    } catch (e, st) {
      AppLogger.e('ContractArticlesRepository.supprimer', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Résolution pour génération PDF ───────────────────────────────────────

  Future<ArticlesResolus> getArticlesResolusParLangue({
    required String contratType,
    required Map<String, dynamic> contextData,
  }) async {
    AppLogger.d('🔍 [Articles] getArticlesResolusParLangue → type=$contratType showroom=$showroomId');
    AppLogger.d('🔍 [Articles] contextData keys: ${contextData.keys.toList()}');

    try {
      final strContext = contextData.map(
        (k, v) => MapEntry(k, v?.toString() ?? ''),
      );

      final results = await Future.wait([
        getActifsParLangue(contratType, 'fr'),
        getActifsParLangue(contratType, 'ar'),
      ]);

      final articlesFr = results[0];
      final articlesAr = results[1];

      AppLogger.d('📦 [Articles] bruts récupérés → FR: ${articlesFr.length}, AR: ${articlesAr.length}');

      List<Map<String, String>> resolve(List<ContractArticle> articles, String langue) {
        final resolved = articles
            .where((a) => a.evaluerCondition(contextData))
            .map((a) => {
                  'titre': a.resolveTitre(strContext),
                  'corps': a.resolveVariables(strContext),
                })
            .toList();
        final filtres = articles.length - resolved.length;
        if (filtres > 0) {
          AppLogger.d('🔎 [Articles] $filtres article(s) $langue filtrés par condition');
        }
        AppLogger.d('✅ [Articles] résolus $langue → ${resolved.length} article(s)');
        for (var i = 0; i < resolved.length; i++) {
          AppLogger.d('   [$langue][${i + 1}] titre: "${resolved[i]['titre']}"');
        }
        return resolved;
      }

      final fr = resolve(articlesFr, 'FR');
      final ar = resolve(articlesAr, 'AR');

      if (fr.isEmpty && ar.isEmpty) {
        AppLogger.w('⚠️ [Articles] Aucun article résolu pour type=$contratType — la page 2 du PDF sera vide');
      }

      return ArticlesResolus(fr: fr, ar: ar);
    } catch (e, st) {
      AppLogger.e('ContractArticlesRepository.getArticlesResolusParLangue',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Map<String, String>>> getArticlesResolus({
    required String contratType,
    required Map<String, dynamic> contextData,
  }) async {
    final resolved = await getArticlesResolusParLangue(
      contratType: contratType,
      contextData: contextData,
    );
    return [...resolved.fr, ...resolved.ar];
  }
}

/// DTO transportant les articles résolus séparés par langue.
class ArticlesResolus {
  final List<Map<String, String>> fr;
  final List<Map<String, String>> ar;

  const ArticlesResolus({required this.fr, required this.ar});

  bool get hasFr => fr.isNotEmpty;
  bool get hasAr => ar.isNotEmpty;
}