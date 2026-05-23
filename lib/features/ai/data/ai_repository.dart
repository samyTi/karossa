// lib/features/ai/data/ai_repository.dart
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  CORRECTIFS                                                             │
// │                                                                         │
// │  1. Modèle hardcodé → lu depuis showroom_settings.gemini_model         │
// │  2. Modèle par défaut mis à jour : gemini-2.0-flash (stable v1beta)    │
// │  3. Cache invalidé si le modèle change dans les settings               │
// │  4. Meilleur message d'erreur si le modèle est inconnu                 │
// │                                                                         │
// │  Migration SQL à exécuter UNE FOIS dans Supabase SQL Editor :          │
// │    ALTER TABLE showroom_settings                                        │
// │      ADD COLUMN IF NOT EXISTS gemini_model text                        │
// │        DEFAULT 'gemini-2.0-flash';                                     │
// └─────────────────────────────────────────────────────────────────────────┘

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../domain/chat_message.dart';
import '../../../core/utils/app_logger.dart';

/// Modèles Gemini disponibles (affichés dans les Settings)
class GeminiModels {
  static const List<Map<String, String>> available = [
    {
      'id': 'gemini-2.0-flash',
      'label': 'Gemini 2.0 Flash',
      'description': 'Rapide, recommandé ✅',
    },
    {
      'id': 'gemini-2.0-flash-lite',
      'label': 'Gemini 2.0 Flash Lite',
      'description': 'Ultra rapide, léger',
    },
    {
      'id': 'gemini-1.5-flash-latest',
      'label': 'Gemini 1.5 Flash (latest)',
      'description': 'Stable, bon équilibre',
    },
    {
      'id': 'gemini-1.5-pro-latest',
      'label': 'Gemini 1.5 Pro (latest)',
      'description': 'Plus puissant, plus lent',
    },
  ];

  static const String defaultModel = 'gemini-2.0-flash';
}

class AiRepository {
  final SupabaseClient _client;

  // Cache modèle : invalidé si la clé ou le nom du modèle change
  GenerativeModel? _model;
  String? _cachedApiKey;
  String? _cachedModelName;

  AiRepository(this._client);

  // ── Récupération de la config depuis Supabase ──────────────────────────

  Future<({String? apiKey, String modelName})> _getConfig() async {
    try {
      final response = await _client
          .from('showroom_settings')
          .select('gemini_api_key, gemini_model')
          .maybeSingle();

      if (response == null) {
        AppLogger.e('showroom_settings : aucune ligne trouvée');
        return (apiKey: null, modelName: GeminiModels.defaultModel);
      }

      final apiKey = response['gemini_api_key'] as String?;
      // gemini_model peut être null si la colonne n'existe pas encore
      final modelName = (response['gemini_model'] as String?)?.trim().isEmpty == false
          ? response['gemini_model'] as String
          : GeminiModels.defaultModel;

      return (apiKey: apiKey, modelName: modelName);
    } catch (e) {
      AppLogger.e('Erreur récupération config IA', error: e);
      return (apiKey: null, modelName: GeminiModels.defaultModel);
    }
  }

  // ── Initialisation du modèle (avec invalidation du cache) ─────────────

  Future<GenerativeModel?> _initModel() async {
    final config = await _getConfig();

    if (config.apiKey == null || config.apiKey!.isEmpty) {
      AppLogger.e('gemini_api_key introuvable dans showroom_settings');
      return null;
    }

    // Invalider le cache si la clé ou le modèle a changé
    if (_model != null &&
        _cachedApiKey == config.apiKey &&
        _cachedModelName == config.modelName) {
      return _model;
    }

    AppLogger.d(
        'AiRepository: Initialisation modèle "${config.modelName}"');

    _model = GenerativeModel(
      model: config.modelName,
      apiKey: config.apiKey!,
      systemInstruction: Content.system(_buildSystemPrompt()),
    );
    _cachedApiKey = config.apiKey;
    _cachedModelName = config.modelName;

    return _model;
  }

  // ── Prompt système ─────────────────────────────────────────────────────

  String _buildSystemPrompt() {
    return '''Tu es KarossaAI, l'assistant intelligent du showroom automobile Karossa (Algérie).
Tu aides les gérants à gérer leur flotte, analyser les performances financières et prendre de meilleures décisions.

RÈGLES ABSOLUES :
1. Tu parles principalement en Français, mais tu comprends le Darija algérien.
2. Tes réponses doivent être professionnelles, précises et orientées business.
3. Pour les montants, utilise toujours "DA" (Dinar Algérien).
4. Si on te pose une question sur un véhicule spécifique, utilise les données fournies dans le contexte.
5. Sois capable d'analyser les statistiques de location, de vente et les dépenses de réparation.''';
  }

  // ── Envoi de message ───────────────────────────────────────────────────

  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
    Map<String, dynamic>? vehiculeContext,
  }) async {
    try {
      final model = await _initModel();
      if (model == null) {
        return "❌ L'IA n'est pas configurée. Veuillez ajouter la clé API dans les paramètres du showroom.";
      }

      final geminiHistory = history
          .map((m) => Content(
                m.role == 'user' ? 'user' : 'model',
                [TextPart(m.content)],
              ))
          .toList();

      final chat = model.startChat(history: geminiHistory);

      String enrichedMessage = message;
      if (vehiculeContext != null) {
        enrichedMessage =
            "CONTEXTE VÉHICULE ACTUEL : $vehiculeContext\n\nQUESTION : $message";
      }

      final response =
          await chat.sendMessage(Content.text(enrichedMessage));
      return response.text ?? "Désolé, je n'ai pas pu générer de réponse.";
    } catch (e) {
      AppLogger.e('AiRepository.sendMessage', error: e);

      final err = e.toString();

      if (err.contains('API_KEY') || err.contains('api key') || err.contains('invalid')) {
        return '❌ La clé API configurée est invalide ou a expiré.';
      }

      if (err.contains('not found') || err.contains('not supported') || err.contains('ListModels')) {
        final modelName = _cachedModelName ?? GeminiModels.defaultModel;
        return '❌ Le modèle "$modelName" n\'est pas disponible.\n'
            'Allez dans Paramètres > Showroom et choisissez un autre modèle.\n'
            'Modèles recommandés : gemini-2.0-flash ou gemini-1.5-flash-latest.';
      }

      if (err.contains('quota') || err.contains('RESOURCE_EXHAUSTED')) {
        return '❌ Quota API dépassé. Réessayez dans quelques instants.';
      }

      return '❌ Erreur de connexion avec KarossaAI. Vérifiez votre connexion internet.';
    }
  }

  // ── Helpers spécialisés ────────────────────────────────────────────────

  Future<String> analyserVehicule(Map<String, dynamic> vehiculeData) async {
    final prompt = '''Analyse ce véhicule et donne-moi :
1. Un résumé de son état général.
2. Des recommandations d'entretien basées sur le kilométrage (${vehiculeData['kilometrage']} km).
3. Une estimation de rentabilité si loué à ${vehiculeData['prix_location_jour']} DA/jour.
4. Les points d'attention particuliers.

Données : ${vehiculeData.toString()}''';

    return sendMessage(message: prompt, history: []);
  }

  Future<String> suggererPrix({
    required String marque,
    required String modele,
    required int annee,
    required int kilometrage,
  }) async {
    final prompt =
        '''Pour un $marque $modele de $annee avec $kilometrage km en Algérie :
1. Quel prix de vente est réaliste sur le marché actuel ?
2. Quel tarif de location journalier est compétitif ?
3. Quelle est la tendance de ce modèle en Algérie ?''';

    return sendMessage(message: prompt, history: []);
  }

  /// Force la réinitialisation du modèle (à appeler après changement de settings)
  void resetModel() {
    _model = null;
    _cachedApiKey = null;
    _cachedModelName = null;
    AppLogger.d('AiRepository: cache modèle réinitialisé');
  }
}