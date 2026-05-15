// lib/features/contrats/presentation/contract_articles_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/contract_articles_repository.dart';
import '../domain/contract_article_model.dart';

// ── Repository ─────────────────────────────────────────────

final contractArticlesRepositoryProvider =
    Provider<ContractArticlesRepository>((ref) {
  return ContractArticlesRepository(ref.watch(supabaseClientProvider));
});

// ── Lecture admin (tous — actifs + inactifs) ───────────────

final contractArticlesAdminProvider =
    FutureProvider.autoDispose.family<List<ContractArticle>, String>(
  (ref, contratType) => ref
      .watch(contractArticlesRepositoryProvider)
      .getTous(contratType),
);

// ── Lecture génération (actifs seulement) ─────────────────

final contractArticlesActifsProvider =
    FutureProvider.autoDispose.family<List<ContractArticle>, String>(
  (ref, contratType) => ref
      .watch(contractArticlesRepositoryProvider)
      .getActifs(contratType),
);

// ── Notifier pour l'écran admin (CRUD + réordonnancement) ──

class ContractArticlesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<ContractArticle>, String> {
  @override
  Future<List<ContractArticle>> build(String arg) async {
    return ref.watch(contractArticlesRepositoryProvider).getTous(arg);
  }

  ContractArticlesRepository get _repo =>
      ref.read(contractArticlesRepositoryProvider);

  Future<void> creer(ContractArticle article) async {
    final created = await _repo.creer(article);
    if (created != null) ref.invalidateSelf();
  }

  Future<void> modifier(String id, Map<String, dynamic> data) async {
    await _repo.modifier(id, data);
    ref.invalidateSelf();
  }

  Future<void> toggleActif(String id, bool actif) async {
    await _repo.toggleActif(id, actif);
    ref.invalidateSelf();
  }

  Future<void> reordonner(List<ContractArticle> articles) async {
    await _repo.reordonner(articles);
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    await _repo.supprimer(id);
    ref.invalidateSelf();
  }
}

final contractArticlesNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<ContractArticlesNotifier, List<ContractArticle>, String>(
  ContractArticlesNotifier.new,
);