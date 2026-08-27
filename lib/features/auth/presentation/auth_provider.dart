// lib/features/auth/presentation/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../domain/profile_model.dart';
import '../../../core/utils/app_logger.dart';

/// État d'authentification — écoute en temps réel le stream Supabase Auth.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref
      .watch(supabaseAuthProvider)
      .onAuthStateChange
      .map((e) => e.session?.user);
});

/// Profil de l'utilisateur connecté.
/// Se recharge automatiquement à chaque changement d'état d'authentification.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    RolePermissions.clearOverrides();
    return null;
  }

  try {
    final client = ref.watch(supabaseClientProvider);
    final data = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    final profile = Profile.fromJson(data);

    // Charge les permissions personnalisées par rôle pour ce showroom
    // (table role_permissions). Si la table/ligne n'existe pas encore,
    // on garde silencieusement les permissions par défaut codées en dur.
    if (profile.showroomId != null) {
      try {
        final rows = await client
            .from('role_permissions')
            .select()
            .eq('showroom_id', profile.showroomId as Object);
        final overrides = <UserRole, Set<String>>{};
        for (final row in (rows as List)) {
          final role = UserRole.values
              .where((r) => r.name == row['role'])
              .cast<UserRole?>()
              .firstWhere((_) => true, orElse: () => null);
          if (role == null) continue;
          overrides[role] = Set<String>.from(row['permissions'] ?? const []);
        }
        RolePermissions.applyOverrides(overrides);
      } catch (e) {
        AppLogger.e('Impossible de charger role_permissions, utilisation des permissions par défaut', error: e);
      }
    }

    return profile;
  } catch (e, st) {
    AppLogger.e('Erreur lors de la récupération du profil utilisateur', error: e, stackTrace: st);
    return null;
  }
});

/// 🚀 ID du Showroom actif pour l'utilisateur connecté.
/// Consommé par l'ensemble des Repositories de l'application pour l'isolation des données (SaaS).
final currentShowroomIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.showroomId;
});

/// Raccourci de permissions — Vrai si l'utilisateur possède les droits de gestion de caisse/finance.
final canManageCaisseProvider = Provider<bool>((ref) {
  final p = ref.watch(currentProfileProvider).valueOrNull;
  if (p == null) return false;
  
  // Alignement strict avec vos contraintes CHECK de rôles en BDD ('gerant', 'externe')
  return p.role == UserRole.gerant;
});

/// Service d'authentification pour les actions utilisateur (connexion/déconnexion).
final authProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseAuthProvider));
});

class AuthService {
  AuthService(this._auth);

  final GoTrueClient _auth;

  /// Déconnecte l'utilisateur et ferme la session courante
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e, st) {
      AppLogger.e('AuthService.signOut', error: e, stackTrace: st);
      rethrow;
    }
  }
}