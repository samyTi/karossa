import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/vehicules_repository.dart';
import '../domain/vehicule_model.dart';

final vehiculesRepositoryProvider = Provider((_) => VehiculesRepository());

final vehiculesProvider = FutureProvider.autoDispose<List<Vehicule>>((ref) {
  return ref.watch(vehiculesRepositoryProvider).getAll();
});

final vehiculeDetailProvider =
    FutureProvider.autoDispose.family<Vehicule, String>((ref, id) {
  return ref.watch(vehiculesRepositoryProvider).getById(id);
});

final statutFiltreProvider = StateProvider<VehiculeStatut?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');
final marqueFiltreProvider = StateProvider<String?>((ref) => null);
final anneeMinProvider = StateProvider<int?>((ref) => null);
final anneeMaxProvider = StateProvider<int?>((ref) => null);
final prixMaxProvider = StateProvider<double?>((ref) => null);

final vehiculesFiltresProvider =
    Provider.autoDispose<AsyncValue<List<Vehicule>>>((ref) {
  final statut   = ref.watch(statutFiltreProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase().trim();
  final marque = ref.watch(marqueFiltreProvider);
  final anneeMin = ref.watch(anneeMinProvider);
  final anneeMax = ref.watch(anneeMaxProvider);
  final prixMax = ref.watch(prixMaxProvider);
  final vehicules = ref.watch(vehiculesProvider);
  
  return vehicules.whenData((list) {
    var filtered = list;
    
    // Filtre par statut
    if (statut != null) {
      filtered = filtered.where((v) => v.statut == statut).toList();
    }
    
    // Filtre par marque
    if (marque != null && marque.isNotEmpty) {
      filtered = filtered.where((v) => 
        (v.marque ?? '').toLowerCase().contains(marque.toLowerCase())).toList();
    }
    
    // Filtre par année minimum
    if (anneeMin != null) {
      filtered = filtered.where((v) => v.annee >= anneeMin!).toList();
    }
    
    // Filtre par année maximum
    if (anneeMax != null) {
      filtered = filtered.where((v) => v.annee <= anneeMax!).toList();
    }
    
    // Filtre par prix maximum
    if (prixMax != null) {
      filtered = filtered.where((v) {
        final prixVente = v.prixVente;
        final prixLocation = v.prixLocationJour;
        return (prixVente != null && prixVente <= prixMax!) ||
               (prixLocation != null && prixLocation <= prixMax!);
      }).toList();
    }
    
    // Filtre par recherche textuelle
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((v) {
        final displayName = v.displayName.toLowerCase();
        final marqueValue = (v.marque ?? '').toLowerCase();
        final modele = (v.modele ?? '').toLowerCase();
        final immatriculation = (v.immatriculation ?? '').toLowerCase();
        
        return displayName.contains(searchQuery) ||
               marqueValue.contains(searchQuery) ||
               modele.contains(searchQuery) ||
               immatriculation.contains(searchQuery);
      }).toList();
    }
    
    return filtered;
  });
});
