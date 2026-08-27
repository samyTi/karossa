// lib/features/web_demandes/presentation/web_demandes_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart'; // Assurez-vous d'importer le bon chemin pour currentShowroomIdProvider
import '../data/web_demandes_repository.dart';
import '../domain/web_demande_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final webDemandesRepositoryProvider = Provider<WebDemandesRepository>((ref) {
  // On récupère le showroom courant pour assurer le multi-tenant
  final showroomId = ref.watch(currentShowroomIdProvider) ?? '';
  
  return WebDemandesRepository(
    ref.watch(supabaseClientProvider),
    showroomId: showroomId,
  );
});

// ── Liste complète ────────────────────────────────────────────────────────────

final webDemandesListProvider = FutureProvider<List<WebDemande>>((ref) {
  return ref.watch(webDemandesRepositoryProvider).fetchAllWebDemandes();
});

// ── Badge : nombre total en attente ──────────────────────────────────────────

final webDemandesCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(webDemandesRepositoryProvider).countEnAttente();
});

// ── Filtres ───────────────────────────────────────────────────────────────────

final webDemandesStatutFilterProvider = StateProvider<DemandeWebStatut?>((ref) => null);

final webDemandesTypeFilterProvider = StateProvider<DemandeWebType?>((ref) => null);

final webDemandesSearchProvider = StateProvider<String>((ref) => '');

// ── Liste filtrée ─────────────────────────────────────────────────────────────

final webDemandesFiltreesProvider = FutureProvider<List<WebDemande>>((ref) async {
  final demandes = await ref.watch(webDemandesListProvider.future);
  final statutFilter = ref.watch(webDemandesStatutFilterProvider);
  final typeFilter = ref.watch(webDemandesTypeFilterProvider);
  final search = ref.watch(webDemandesSearchProvider).trim().toLowerCase();

  var filtered = demandes;

  if (statutFilter != null) {
    filtered = filtered.where((d) => d.statut == statutFilter).toList();
  }
  if (typeFilter != null) {
    filtered = filtered.where((d) => d.type == typeFilter).toList();
  }
  if (search.isNotEmpty) {
    filtered = filtered.where((d) {
      return (d.clientFullName.toLowerCase().contains(search)) ||
          (d.telephone?.toLowerCase().contains(search) ?? false) ||
          (d.vehiculeMarque?.toLowerCase().contains(search) ?? false) ||
          (d.vehiculeModele?.toLowerCase().contains(search) ?? false) ||
          (d.vehiculeImmat?.toLowerCase().contains(search) ?? false) ||
          (d.propMarque?.toLowerCase().contains(search) ?? false) ||
          (d.propModele?.toLowerCase().contains(search) ?? false);
    }).toList();
  }

  return filtered;
});

// ── Stats rapides ─────────────────────────────────────────────────────────────

class WebDemandesStats {
  final int total;
  final int enAttente;
  final int approuvees;
  final int rejetees;
  final int locations;
  final int propositionsVente;
  final int demandesDevis;

  const WebDemandesStats({
    required this.total,
    required this.enAttente,
    required this.approuvees,
    required this.rejetees,
    required this.locations,
    required this.propositionsVente,
    required this.demandesDevis,
  });
}

final webDemandesStatsProvider = FutureProvider<WebDemandesStats>((ref) async {
  final demandes = await ref.watch(webDemandesListProvider.future);
  return WebDemandesStats(
    total: demandes.length,
    enAttente: demandes.where((d) => d.statut == DemandeWebStatut.enAttente).length,
    approuvees: demandes.where((d) => d.statut == DemandeWebStatut.approuve).length,
    rejetees: demandes.where((d) => d.statut == DemandeWebStatut.rejete).length,
    locations: demandes.where((d) => d.type == DemandeWebType.location).length,
    propositionsVente: demandes.where((d) => d.type == DemandeWebType.propositionVente).length,
    demandesDevis: demandes.where((d) => d.type == DemandeWebType.demandeDevis).length,
  );
});