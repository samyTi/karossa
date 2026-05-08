// lib/shared/services/backend_api_service.dart
// Service d'appel aux routes API Next.js du backend Karossa
//
// CONFIGURATION :
//   - En développement : le backend tourne sur http://localhost:3001
//   - En production    : remplacer par l'URL de déploiement (Vercel, Railway...)
//   - La clé API est passée dans le header x-api-key pour les routes GPS

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/app_logger.dart';

class BackendApiService {
  BackendApiService(this._client);

  final SupabaseClient _client;

  // ⚠️ Remplacez cette URL par votre URL de déploiement en production
  static const String _baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3001',
  );

  static const String _apiKey = String.fromEnvironment(
    'BACKEND_API_KEY',
    defaultValue: 'change-me-in-production',
  );

  // ── Headers avec token Supabase ───────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final session = _client.auth.currentSession;
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer ${session?.accessToken ?? ''}',
    };
  }

  Map<String, String> get _apiKeyHeaders => {
    'Content-Type': 'application/json',
    'x-api-key':    _apiKey,
  };

  // ═══════════════════════════════════════════════════════════════════════════
  //  1. CONTRATS — Génération PDF
  // ═══════════════════════════════════════════════════════════════════════════

  /// Génère un PDF de contrat et retourne son URL Supabase Storage
  ///
  /// [type] : 'location' | 'vente' | 'echange'
  /// [referenceId] : UUID de l'enregistrement concerné
  Future<String?> generateContrat({
    required String type,
    required String referenceId,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/contrats/generate'),
        headers: await _authHeaders(),
        body: jsonEncode({ 'type': type, 'referenceId': referenceId }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['url'] as String?;
      }
      AppLogger.d('generateContrat [${resp.statusCode}]: ${resp.body}');
      return null;
    } catch (e) {
      AppLogger.d('BackendApiService.generateContrat: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  2. GPS — Envoi de position
  // ═══════════════════════════════════════════════════════════════════════════

  /// Envoie une position GPS vers le backend (qui gère alertes + geofencing)
  Future<bool> sendGpsPosition({
    required String vehiculeId,
    required double latitude,
    required double longitude,
    double? speed,
    double? altitude,
    double? cap,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/gps/position'),
        headers: _apiKeyHeaders,
        body: jsonEncode({
          'vehiculeId': vehiculeId,
          'latitude':   latitude,
          'longitude':  longitude,
          if (speed != null)    'speed': speed,
          if (altitude != null) 'altitude': altitude,
          if (cap != null)      'cap': cap,
          'fixTime': DateTime.now().toIso8601String(),
        }),
      );
      return resp.statusCode == 200;
    } catch (e) {
      AppLogger.d('BackendApiService.sendGpsPosition: $e');
      return false;
    }
  }

  /// Récupère la dernière position connue d'un véhicule
  Future<Map<String, dynamic>?> getLastGpsPosition(String vehiculeId) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/gps/position?vehiculeId=$vehiculeId'),
        headers: await _authHeaders(),
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      AppLogger.d('BackendApiService.getLastGpsPosition: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  3. IA — Chat Gemini via backend sécurisé
  // ═══════════════════════════════════════════════════════════════════════════

  /// Envoie un message à l'IA Gemini via le backend sécurisé
  ///
  /// Utilise le backend Next.js pour ne pas exposer la clé Gemini côté client
  Future<String> chatWithAi({
    required String message,
    required List<Map<String, String>> history,
    Map<String, dynamic>? vehiculeContext,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/ai/chat'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'message':  message,
          'history':  history,
          if (vehiculeContext != null) 'vehiculeContext': vehiculeContext,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['reply'] as String? ?? 'Aucune réponse.';
      }
      return '❌ Erreur backend IA (${resp.statusCode})';
    } catch (e) {
      AppLogger.d('BackendApiService.chatWithAi: $e');
      return '❌ Impossible de contacter le serveur IA.';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  4. FINANCIALS — Marges et prix de revient (via backend)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Récupère l'analyse financière complète d'un véhicule depuis le backend
  Future<Map<String, dynamic>?> getVehiculeFinancials(String vehiculeId) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/vehicules/$vehiculeId/financials'),
        headers: await _authHeaders(),
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      AppLogger.d('BackendApiService.getVehiculeFinancials: $e');
      return null;
    }
  }
}
