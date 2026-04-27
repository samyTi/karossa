import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../auth/domain/profile_model.dart';
import '../../../main.dart';

/// Provider qui récupère tous les utilisateurs depuis Supabase
final usersProvider = FutureProvider<List<Profile>>((ref) async {
  try {
    final response = await supabase
        .from('profiles')
        .select('''
          id,
          nom,
          prenom,
          email,
          role,
          telephone,
          avatar_url,
          created_at,
          active
        ''')
        .order('created_at', ascending: false);

    if (response.isEmpty) return [];

    return response.map((data) {
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
    debugPrint('Erreur lors de la récupération des utilisateurs: $e');
    return [];
  }
});

/// Provider pour récupérer les credentials Traccar depuis la table showroom_settings
final traccarCredentialsProvider = FutureProvider<TraccarCredentials?>((ref) async {
  try {
    final response = await supabase
        .from('showroom_settings')
        .select('traccar_url, traccar_user, traccar_password')
        .maybeSingle();

    if (response == null) return null;

    return TraccarCredentials(
      url: response['traccar_url'] as String? ?? 'https://demo.traccar.org',
      username: response['traccar_user'] as String?,
      password: response['traccar_password'] as String?,
    );
  } catch (e) {
    debugPrint('Erreur lors de la récupération des credentials Traccar: $e');
    return null;
  }
});

/// Modèle pour les credentials Traccar
class TraccarCredentials {
  final String url;
  final String? username;
  final String? password;

  TraccarCredentials({
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