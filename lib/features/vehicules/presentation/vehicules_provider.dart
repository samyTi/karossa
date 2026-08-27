// lib/features/vehicules/presentation/vehicules_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart'; // 🚀 Importation nécessaire pour écouter la session
import '../data/vehicules_repository.dart';
import '../domain/vehicule_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final vehiculesRepositoryProvider = Provider<VehiculesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  // 🚀 On récupère de façon réactive le showroom de l'utilisateur connecté
  final showroomId = ref.watch(currentShowroomIdProvider);
  
  if (showroomId == null) {
    // Si la session n'est pas encore chargée, on passe une chaîne vide ou on lève une erreur.
    // L'infrastructure RLS bloquera de toute façon l'accès par sécurité.
    return VehiculesRepository(client, showroomId: '');
  }
  
  return VehiculesRepository(client, showroomId: showroomId);
});

// ── Providers de liste ────────────────────────────────────────────────────────

final vehiculesProvider = FutureProvider.autoDispose<List<Vehicule>>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  // Si le profil utilisateur (et donc son showroom) est toujours en cours de chargement,
  // on évite de requêter inutilement en retournant une liste vide.
  if (showroomId == null || showroomId.isEmpty) {
    return <Vehicule>[];
  }
  
  return ref.watch(vehiculesRepositoryProvider).getAll();
});

final vehiculeDetailProvider =
    FutureProvider.autoDispose.family<Vehicule, String>((ref, id) {
  return ref.watch(vehiculesRepositoryProvider).getById(id);
});

// ── Filtres (état UI) ─────────────────────────────────────────────────────────

final statutFiltreProvider = StateProvider<VehiculeStatut?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');
final marqueFiltreProvider = StateProvider<String?>((ref) => null);
final anneeMinProvider = StateProvider<int?>((ref) => null);
final anneeMaxProvider = StateProvider<int?>((ref) => null);
final prixMaxProvider = StateProvider<double?>((ref) => null);

// ── Liste filtrée (logique de présentation uniquement) ────────────────────────

final vehiculesFiltresProvider =
    Provider.autoDispose<AsyncValue<List<Vehicule>>>((ref) {
  final statut = ref.watch(statutFiltreProvider);
  final search = ref.watch(searchQueryProvider).toLowerCase().trim();
  final marque = ref.watch(marqueFiltreProvider);
  final anneeMin = ref.watch(anneeMinProvider);
  final anneeMax = ref.watch(anneeMaxProvider);
  final prixMax = ref.watch(prixMaxProvider);

  return ref.watch(vehiculesProvider).whenData((list) {
    return list.where((v) {
      if (statut != null && v.statut != statut) return false;
      if (marque != null &&
          marque.isNotEmpty &&
          !v.marque.toLowerCase().contains(marque.toLowerCase())) {
        return false;
      }
      if (anneeMin != null && v.annee < anneeMin) return false;
      if (anneeMax != null && v.annee > anneeMax) return false;
      if (prixMax != null) {
        final pv = v.prixVente;
        final pl = v.prixLocationJour;
        if ((pv == null || pv > prixMax) &&
            (pl == null || pl > prixMax)) {
          return false;
        }
      }
      if (search.isNotEmpty) {
        final hay = '${v.displayName} ${v.immatriculation ?? ''}'.toLowerCase();
        if (!hay.contains(search)) return false;
      }
      return true;
    }).toList();
  });
});