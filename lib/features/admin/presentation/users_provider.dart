import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'dart:convert';
import '../../auth/domain/profile_model.dart';
import '../../../core/utils/app_logger.dart';

/// Provider qui récupère tous les utilisateurs depuis Supabase
final usersProvider = FutureProvider<List<Profile>>((ref) async {
  try {
    // Note: email n'est pas dans profiles, on le récupère depuis auth.users via une jointure
    final response = await ref.watch(supabaseClientProvider)
        .from('profiles')
        .select('''
          id,
          nom,
          prenom,
          role,
          telephone,
          avatar_url,
          created_at,
          active,
          user_id,
          auth:user_id!inner
        ''')
        .order('created_at', ascending: false);

    if (response.isEmpty) return [];

    return response.map((data) {
      // Récupérer l'email depuis la jointure auth
      // ignore: unused_local_variable — jointure présente pour validation, email non exposé dans Profile
      final _ = data['user_id'] as Map<String, dynamic>?;
      
      return Profile(
        id: data['id'] as String,
        nom: data['nom'] as String,
        prenom: data['prenom'] as String,
        role: UserRole.values.firstWhere(
          (r) => r.name == data['role'],
          orElse: () => UserRole.proprietaire_vehicule,
        ),
        telephone: data['telephone'] as String?,
        avatarUrl: data['avatar_url'] as String?,
        dateCreation: data['created_at'] != null
            ? DateTime.tryParse(data['created_at'] as String)
            : null,
      );
    }).toList();
  } catch (e) {
    AppLogger.d('Erreur lors de la récupération des utilisateurs: $e');
    return [];
  }
});

/// Provider pour récupérer les credentials Flespi depuis la table showroom_settings
final flespiCredentialsProvider = FutureProvider<FlespiCredentials?>((ref) async {
  try {
    final response = await ref.watch(supabaseClientProvider)
        .from('showroom_settings')
        .select('flespi_url, flespi_user, flespi_password')
        .maybeSingle();

    if (response == null) return null;

    return FlespiCredentials(
      url: response['flespi_url'] as String? ?? 'https://demo.flespi.org',
      username: response['flespi_user'] as String?,
      password: response['flespi_password'] as String?,
    );
  } catch (e) {
    AppLogger.d('Erreur lors de la récupération des credentials Flespi: $e');
    return null;
  }
});

/// Modèle pour les credentials Flespi
class FlespiCredentials {
  final String url;
  final String? username;
  final String? password;

  FlespiCredentials({
    required this.url,
    this.username,
    this.password,
  });

  /// WebSocket URL dérivée de l'URL HTTP
  String get wsUrl {
    return url
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
  }

  /// Header d'authentification Basic
  String? get authHeader {
    if (username == null || password == null) return null;
    final creds = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $creds';
  }
}