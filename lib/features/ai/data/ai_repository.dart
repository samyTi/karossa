// lib/features/ai/data/ai_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../domain/chat_message.dart';
import '../../../core/utils/app_logger.dart';

class AiRepository {
  final SupabaseClient _client;
  GenerativeModel? _model;

  AiRepository(this._client);

  /// Récupère la clé API depuis la table showroom_settings
  Future<String?> _getApiKey() async {
    try {
      final response = await _client
          .from('showroom_settings')
          .select('gemini_api_key')
          .maybeSingle();
      
      if (response == null || response['gemini_api_key'] == null) {
        AppLogger.e('Clé gemini_api_key introuvable dans showroom_settings');
        return null;
      }
      
      return response['gemini_api_key'] as String;
    } catch (e) {
      AppLogger.e('Erreur lors de la récupération de la configuration IA', error: e);
      return null;
    }
  }

  /// Initialise le modèle Gemini uniquement quand c'est nécessaire
  Future<GenerativeModel?> _initModel() async {
    if (_model != null) return _model;

    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(_buildSystemPrompt()),
    );
    return _model;
  }

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

  /// Envoie un message à l'IA avec gestion de l'historique et du contexte
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

      // Conversion de l'historique Karossa vers le format Gemini
      final geminiHistory = history.map((m) => Content(
        m.role == 'user' ? 'user' : 'model',
        [TextPart(m.content)],
      )).toList();

      final chat = model.startChat(history: geminiHistory);

      // Enrichissement du message avec le contexte véhicule si présent
      String enrichedMessage = message;
      if (vehiculeContext != null) {
        enrichedMessage = "CONTEXTE VÉHICULE ACTUEL : $vehiculeContext\n\nQUESTION : $message";
      }

      final response = await chat.sendMessage(Content.text(enrichedMessage));
      return response.text ?? 'Désolé, je n\'ai pas pu générer de réponse.';

    } catch (e) {
      AppLogger.e('AiRepository.sendMessage', error: e);
      if (e.toString().contains('API_KEY')) {
        return '❌ La clé API configurée est invalide ou a expiré.';
      }
      return '❌ Erreur de connexion avec KarossaAI. Vérifiez votre connexion internet.';
    }
  }

  /// Analyse rapide d'un véhicule (utile pour l'écran détail véhicule)
  Future<String> analyserVehicule(Map<String, dynamic> vehiculeData) async {
    final prompt = '''Analyse ce véhicule et donne-moi :
1. Un résumé de son état général.
2. Des recommandations d'entretien basées sur le kilométrage (${vehiculeData['kilometrage']} km).
3. Une estimation de rentabilité si loué à ${vehiculeData['prix_location_jour']} DA/jour.
4. Les points d'attention particuliers.

Données : ${vehiculeData.toString()}''';
    
    return sendMessage(message: prompt, history: []);
  }

  /// Suggestion de prix basée sur les caractéristiques
  Future<String> suggererPrix({
    required String marque,
    required String modele,
    required int annee,
    required int kilometrage,
  }) async {
    final prompt = '''Pour un $marque $modele de $annee avec $kilometrage km en Algérie :
1. Quel prix de vente est réaliste sur le marché actuel ?
2. Quel tarif de location journalier est compétitif ?
3. Quelle est la tendance de ce modèle en Algérie ?''';

    return sendMessage(message: prompt, history: []);
  }
}