// lib/features/locations/presentation/locations_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../data/locations_repository.dart';
import '../domain/location_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final locationsRepositoryProvider = Provider<LocationsRepository>((ref) {
  return LocationsRepository(ref.watch(supabaseClientProvider));
});

// ── Providers ─────────────────────────────────────────────────────────────────

final locationsActivesProvider =
    FutureProvider.autoDispose<List<Location>>((ref) {
  return ref.watch(locationsRepositoryProvider).getActives();
});

final locationsRetardProvider =
    FutureProvider.autoDispose<List<Location>>((ref) {
  return ref.watch(locationsRepositoryProvider).getRetards();
});
