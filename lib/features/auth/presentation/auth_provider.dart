import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../domain/profile_model.dart';

/// Provider pour l'état d'authentification
final authStateProvider = StreamProvider<User?>((ref) {
  return supabase.auth.onAuthStateChange.map((e) => e.session?.user);
});

/// Provider pour le profil actuel
/// Dépend de authStateProvider → se recharge automatiquement à chaque connexion/déconnexion
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  final data = await supabase
    .from('profiles').select().eq('id', user.id).single();
  return Profile.fromJson(data);
});

/// Provider pour vérifier si l'utilisateur peut gérer la caisse
final canManageCaisseProvider = Provider<bool>((ref) {
  final p = ref.watch(currentProfileProvider).valueOrNull;
  return p?.role == UserRole.gerant || p?.role == UserRole.admin;
});

/// Provider pour l'authentification (connexion/déconnexion)
final authProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Classe pour gérer l'authentification
class AuthService {
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }
}
