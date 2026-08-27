// lib/features/admin/presentation/users_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart'; 
import '../../auth/domain/profile_model.dart';
import '../../../core/utils/app_logger.dart';

/// Provider qui récupère tous les utilisateurs du showroom actif
final usersProvider = FutureProvider<List<Profile>>((ref) async {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null) return [];

  try {
    final response = await ref.watch(supabaseClientProvider)
        .from('profiles')
        .select('''
          id,
          nom,
          prenom,
          role,
          telephone,
          avatar_url,
          created_at
        ''')
        .eq('showroom_id', showroomId) // 🚀 Isolation SaaS
        .order('created_at', ascending: false);

    if (response == null || (response as List).isEmpty) return [];

    return (response as List).map((data) {
      return Profile(
        id: data['id'] as String,
        nom: data['nom'] as String,
        prenom: data['prenom'] as String,
        role: UserRole.values.firstWhere(
          (r) => r.name == data['role'],
          // 🚀 CORRECTION : Utilisation d'une valeur existante de l'enum
          orElse: () => UserRole.externe, 
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

/// Provider pour récupérer les credentials Flespi du showroom actif
final flespiCredentialsProvider = FutureProvider<FlespiCredentials?>((ref) async {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null) return null;

  try {
    final response = await ref.watch(supabaseClientProvider)
        .from('showrooms') 
        .select('flespi_url, flespi_user, flespi_password')
        .eq('id', showroomId) // 🚀 Isolation SaaS
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