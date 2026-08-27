// lib/features/ventes/presentation/ventes_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/ventes_repository.dart';
import '../domain/vente_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Fournit l'instance de VentesRepository configurée pour le showroom connecté.
final ventesRepositoryProvider = Provider<VentesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final showroomId = ref.watch(currentShowroomIdProvider);
  
  return VentesRepository(client, showroomId: showroomId ?? '');
});

// ── Providers ─────────────────────────────────────────────────────────────────

/// Liste de toutes les ventes du showroom actif, typées avec le modèle du Domaine.
final ventesListProvider = FutureProvider.autoDispose<List<Vente>>((ref) async {
  final repo = ref.watch(ventesRepositoryProvider);
  return repo.getAll();
});

/// Détail d'une vente spécifique, récupérée de manière sécurisée par son ID.
final venteDetailProvider = FutureProvider.autoDispose.family<Vente?, String>((ref, id) async {
  final repo = ref.watch(ventesRepositoryProvider);
  return repo.getById(id);
});

/// Indicateurs de performance et statistiques financières (CA, volume, panier moyen) 
/// calculés à l'échelle du showroom courant.
final statsVentesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(ventesRepositoryProvider);
  return repo.getStats();
});