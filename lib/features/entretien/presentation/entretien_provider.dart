// lib/features/entretiens/presentation/entretien_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart'; // 🚀 NOUVEAU : Import pour suivre le showroom actif
import '../data/entretien_repository.dart';
import '../domain/alerte_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

// 🚀 MODIFICATION : Injection dynamique du showroomId actif dans le Repository d'entretiens
final entretienRepositoryProvider = Provider<EntretienRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final showroomId = ref.watch(currentShowroomIdProvider);
  
  return EntretienRepository(client, showroomId: showroomId ?? '');
});

// ── Providers ─────────────────────────────────────────────────────────────────

// ✅ Ce provider reste inchangé mais retourne désormais uniquement les alertes du showroom courant !
final alertesEntretienProvider =
    FutureProvider.autoDispose<List<AlerteEntretien>>((ref) {
  return ref.watch(entretienRepositoryProvider).getActives();
});