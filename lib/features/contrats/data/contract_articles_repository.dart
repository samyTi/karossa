// lib/features/contrats/data/contract_articles_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/contract_article_model.dart';
import '../../../core/utils/app_logger.dart';

class ContractArticlesRepository {
  ContractArticlesRepository(this._client);
  final SupabaseClient _client;

  Future<List<ContractArticle>> getActifs(String contratType) async {
    try {
      final data = await _client
          .from('contract_articles')
          .select()
          .eq('contrat_type', contratType)
          .eq('actif', true)
          .order('ordre');
      return (data as List).map((j) => ContractArticle.fromJson(j)).toList();
    } catch (e) {
      AppLogger.d('ContractArticlesRepository.getActifs: $e');
      return [];
    }
  }

  /// Retourne uniquement les articles actifs d'une langue donnée ('fr' ou 'ar').
  /// Filtre à la fois en base ET côté client pour garantir la séparation.
  Future<List<ContractArticle>> getActifsParLangue(
    String contratType,
    String langue, // 'fr' | 'ar'
  ) async {
    try {
      final data = await _client
          .from('contract_articles')
          .select()
          .eq('contrat_type', contratType)
          .eq('actif', true)
          .eq('langue', langue) // filtre en base — colonne DEFAULT 'fr'
          .order('ordre');
      return (data as List).map((j) => ContractArticle.fromJson(j)).toList();
    } catch (e) {
      AppLogger.d('ContractArticlesRepository.getActifsParLangue: $e');
      return [];
    }
  }

  Future<List<ContractArticle>> getTous(String contratType) async {
    try {
      final data = await _client
          .from('contract_articles')
          .select()
          .eq('contrat_type', contratType)
          .order('ordre');
      return (data as List).map((j) => ContractArticle.fromJson(j)).toList();
    } catch (e) {
      AppLogger.d('ContractArticlesRepository.getTous: $e');
      return [];
    }
  }

  Future<ContractArticle?> creer(ContractArticle article) async {
    try {
      final json = article.toJson();
      if (article.id.isEmpty) json.remove('id');

      final data = await _client
          .from('contract_articles')
          .insert(json)
          .select()
          .single();

      return ContractArticle.fromJson(data);
    } catch (e) {
      AppLogger.d('ContractArticlesRepository.creer erreur: $e');
      rethrow;
    }
  }

  Future<bool> modifier(String id, Map<String, dynamic> data) async {
    try {
      await _client
          .from('contract_articles')
          .update({...data, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      return true;
    } catch (e) {
      AppLogger.d('ContractArticlesRepository.modifier: $e');
      rethrow;
    }
  }

  Future<bool> toggleActif(String id, bool actif) =>
      modifier(id, {'actif': actif});

  Future<bool> reordonner(List<ContractArticle> articles) async {
    try {
      await Future.wait(
        articles.asMap().entries.map((entry) =>
          _client.from('contract_articles')
            .update({'ordre': entry.key})
            .eq('id', entry.value.id)
        ),
      );
      return true;
    } catch (e) {
      AppLogger.d('ContractArticlesRepository.reordonner: $e');
      return false;
    }
  }

  Future<bool> supprimer(String id) async {
    try {
      await _client.from('contract_articles').delete().eq('id', id);
      return true;
    } catch (e) {
      AppLogger.d('ContractArticlesRepository.supprimer: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Méthodes de résolution pour la génération PDF
  //  Retourne les articles séparés par langue, variables résolues.
  // ──────────────────────────────────────────────────────────────────────────

  /// Retourne les articles actifs résolus, séparés en deux listes :
  ///   - `fr` : articles français → injectés dans la page conditions FR
  ///   - `ar` : articles arabes  → injectés dans la page conditions AR
  ///
  /// CORRECTION : filtre la langue EN BASE (via getActifsParLangue) pour éviter
  /// que les articles arabes apparaissent dans le contrat français quand la
  /// colonne `langue` vaut NULL en base (ce qui résultait en ArticleLangue.fr
  /// par défaut dans fromString()).
  Future<ArticlesResolus> getArticlesResolusParLangue({
    required String contratType,
    required Map<String, dynamic> contextData,
  }) async {
    final strContext = contextData.map(
      (k, v) => MapEntry(k, v?.toString() ?? ''),
    );

    // Deux requêtes séparées : une par langue (filtre en base)
    final articlesFr = await getActifsParLangue(contratType, 'fr');
    final articlesAr = await getActifsParLangue(contratType, 'ar');

    List<Map<String, String>> resolve(List<ContractArticle> articles) =>
        articles
            .where((a) => a.evaluerCondition(contextData))
            .map((a) => {
                  'titre': a.resolveTitre(strContext),
                  'corps': a.resolveVariables(strContext),
                })
            .toList();

    return ArticlesResolus(
      fr: resolve(articlesFr),
      ar: resolve(articlesAr),
    );
  }

  /// Compatibilité ascendante : retourne tous les articles actifs résolus
  /// sans distinction de langue (même comportement qu'avant).
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
  /// Articles en français, à injecter dans la page conditions FR (LTR).
  final List<Map<String, String>> fr;

  /// Articles en arabe, à injecter dans la page conditions AR (RTL).
  final List<Map<String, String>> ar;

  const ArticlesResolus({required this.fr, required this.ar});

  bool get hasFr => fr.isNotEmpty;
  bool get hasAr => ar.isNotEmpty;
}