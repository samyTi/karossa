// lib/core/providers/supabase_provider.dart
//
// SOURCE UNIQUE du client Supabase dans l'application.
//
// AVANT : chaque repository faisait `import '../../../main.dart'`
//         pour accéder à la variable globale `supabase`.
//         → couplage fort, impossible à mocker en test.
//
// APRÈS : tous les repositories reçoivent le client via ce provider.
//         → testable (override dans ProviderScope), découplé de main.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client Supabase injecté par Riverpod.
///
/// Usage dans un repository :
/// ```dart
/// class VentesRepository {
///   VentesRepository(this._client);
///   final SupabaseClient _client;
/// }
///
/// final ventesRepositoryProvider = Provider((ref) {
///   return VentesRepository(ref.watch(supabaseClientProvider));
/// });
/// ```
///
/// Override en test :
/// ```dart
/// final container = ProviderContainer(overrides: [
///   supabaseClientProvider.overrideWithValue(mockClient),
/// ]);
/// ```
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  // Supabase.initialize() est appelé dans main() avant runApp(),
  // donc Supabase.instance est garanti initialisé ici.
  return Supabase.instance.client;
});

/// Auth client — dérivé de supabaseClientProvider.
/// Pratique pour les providers qui n'ont besoin que de l'auth.
final supabaseAuthProvider = Provider<GoTrueClient>((ref) {
  return ref.watch(supabaseClientProvider).auth;
});
