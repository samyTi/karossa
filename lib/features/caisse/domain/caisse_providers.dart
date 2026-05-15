import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/caisse_operation.dart';
import '../data/caisse_repository.dart';

// ─── Repository ──────────────────────────────────────────────────────────────

final caisseRepositoryProvider = Provider<CaisseRepository>((ref) {
  return CaisseRepository(ref.read(supabaseClientProvider));
});

// ─── Filtre (state notifier) ─────────────────────────────────────────────────

class CaisseFilterNotifier extends StateNotifier<CaisseFilter> {
  CaisseFilterNotifier()
      : super(CaisseFilter(
          mois: DateTime.now().month,
          annee: DateTime.now().year,
        ));

  void setType(String? v) => state = state.copyWith(type: v);
  void setCategorie(String? v) => state = state.copyWith(categorie: v);
  void setDateDebut(DateTime? v) =>
      state = state.copyWith(dateDebut: v, mois: null, annee: null);
  void setDateFin(DateTime? v) =>
      state = state.copyWith(dateFin: v, mois: null, annee: null);
  void setMois(int mois, int annee) =>
      state = state.copyWith(
        mois: mois, annee: annee, dateDebut: null, dateFin: null);
  void clearPeriode() =>
      state = state.copyWith(
        mois: null, annee: null, dateDebut: null, dateFin: null);
  void reset() => state = CaisseFilter(
    mois: DateTime.now().month, annee: DateTime.now().year);
}

final caisseFilterProvider =
    StateNotifierProvider<CaisseFilterNotifier, CaisseFilter>(
  (_) => CaisseFilterNotifier(),
);

// ─── Liste opérations ────────────────────────────────────────────────────────

final caisseOperationsProvider =
    FutureProvider.autoDispose<List<CaisseOperation>>((ref) async {
  final filter = ref.watch(caisseFilterProvider);
  final repo = ref.read(caisseRepositoryProvider);
  return repo.fetchAll(filter);
});

// ─── Stats dérivées ──────────────────────────────────────────────────────────

final caisseStatsProvider = Provider.autoDispose<CaisseStats>((ref) {
  return ref.watch(caisseOperationsProvider).maybeWhen(
    data: (ops) => CaisseStats.fromOperations(ops),
    orElse: () => CaisseStats.empty,
  );
});

// ─── Détail opération ────────────────────────────────────────────────────────

final caisseOperationDetailProvider =
    FutureProvider.autoDispose.family<CaisseOperation?, String>((ref, id) {
  return ref.read(caisseRepositoryProvider).fetchById(id);
});

// ─── Lookups ─────────────────────────────────────────────────────────────────

final vehiculesLookupProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(caisseRepositoryProvider).fetchVehicules();
});

final locationsLookupProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(caisseRepositoryProvider).fetchLocationsEnCours();
});

final ventesLookupProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(caisseRepositoryProvider).fetchVentesRecentes();
});

final reparationsLookupProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(caisseRepositoryProvider).fetchReparations();
});

final echangesLookupProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(caisseRepositoryProvider).fetchEchanges();
});

// ─── Actions (CRUD) ───────────────────────────────────────────────────────────

final caisseActionsProvider = Provider.autoDispose((ref) {
  return CaisseActions(ref);
});

class CaisseActions {
  final Ref _ref;
  CaisseActions(this._ref);

  CaisseRepository get _repo => _ref.read(caisseRepositoryProvider);
  String get _userId =>
      _ref.read(supabaseClientProvider).auth.currentUser?.id ?? '';

  Future<void> insert(CaisseOperation op) async {
    await _repo.insert(op, _userId);
    _ref.invalidate(caisseOperationsProvider);
  }

  Future<void> update(String id, CaisseOperation op) async {
    await _repo.update(id, op);
    _ref.invalidate(caisseOperationsProvider);
    _ref.invalidate(caisseOperationDetailProvider(id));
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _ref.invalidate(caisseOperationsProvider);
  }
}