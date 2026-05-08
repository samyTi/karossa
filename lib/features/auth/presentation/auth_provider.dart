// lib/features/auth/presentation/auth_provider.dart
//
// CHANGEMENT : utilise supabaseClientProvider / supabaseAuthProvider
// au lieu d'importer la variable globale depuis main.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../domain/profile_model.dart';
import '../../../core/utils/app_logger.dart';

/// État d'authentification — stream Supabase.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref
      .watch(supabaseAuthProvider)
      .onAuthStateChange
      .map((e) => e.session?.user);
});

/// Profil de l'utilisateur connecté.
/// Se recharge automatiquement à chaque connexion/déconnexion.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final data =
      await client.from('profiles').select().eq('id', user.id).single();
  return Profile.fromJson(data);
});

/// Raccourci — vrai si l'utilisateur peut gérer la caisse.
final canManageCaisseProvider = Provider<bool>((ref) {
  final p = ref.watch(currentProfileProvider).valueOrNull;
  return p?.role == UserRole.gerant || p?.role == UserRole.admin;
});

/// Service d'authentification (connexion/déconnexion).
final authProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseAuthProvider));
});

class AuthService {
  AuthService(this._auth);

  final GoTrueClient _auth;

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e, st) {
      AppLogger.e('AuthService.signOut', error: e, stackTrace: st);
      rethrow;
    }
  }
}
