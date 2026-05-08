// lib/features/ai/data/ai_repository.dart
// Stratégie double :
//   - Par défaut : appel direct Gemini (SDK google_generative_ai)
//   - Si BACKEND_URL est défini : délègue au backend Next.js (clé non exposée)

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../shared/services/backend_api_service.dart';
import '../domain/chat_message.dart';
import '../../../core/utils/app_logger.dart';

class AiRepository {
  AiRepository(this._client);

  final SupabaseClient _client;

  static const _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Si BACKEND_URL est configuré, on passe par le backend sécurisé
  static const _backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  );

  bool get _useBackend => _backendUrl.isNotEmpty;

  GenerativeModel? _model;

  GenerativeModel get _gemini {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(_buildSystemPrompt()),
    );
    return _model!;
  }

  String _buildSystemPrompt() {
    return '''Tu es KarossaAI, l'assistant intelligent du showroom automobile Karossa (Algérie).
Tu aides les gérants et propriétaires à gérer leur flotte, analyser les performances et prendre de meilleures décisions.

RÈGLES ABSOLUES:
- Réponds TOUJOURS en français
- Sois concis, professionnel et pratique
- Les montants sont en Dinars Algériens (DA)
- Si on te demande des calculs financiers, montre le détail étape par étape
- N'invente jamais de données non fournies
- Pour les alertes mécaniques, recommande de consulter un mécanicien professionnel
- Tu peux analyser des données de véhicules, locations, ventes et réparations''';
  }

  /// Envoie un message et retourne la réponse IA
  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
    Map<String, dynamic>? vehiculeContext,
    Map<String, dynamic>? showroomContext,
  }) async {
    try {
      // ── Voie backend sécurisée ────────────────────────────────────────────
      if (_useBackend) {
        final histList = history
            .where((m) => !m.isLoading && m.content.isNotEmpty)
            .map((m) => { 'role': m.role, 'content': m.content })
            .toList();
        return BackendApiService(_client).chatWithAi(
          message:         message,
          history:         histList,
          vehiculeContext: vehiculeContext,
        );
      }

      // ── Voie SDK direct ───────────────────────────────────────────────────
      if (_apiKey.isEmpty || _apiKey == '') {
        return '❌ Clé API Gemini manquante. Définissez GEMINI_API_KEY ou BACKEND_URL.';
      }

      String enrichedMessage = message;
      if (vehiculeContext != null) {
        enrichedMessage = '''[CONTEXTE VÉHICULE]
Véhicule: ${vehiculeContext['marque']} ${vehiculeContext['modele']} ${vehiculeContext['annee']}
Kilométrage: ${vehiculeContext['kilometrage']} km
Statut: ${vehiculeContext['statut']}
${vehiculeContext['prix_vente'] != null ? 'Prix vente: ${vehiculeContext['prix_vente']} DA' : ''}
${vehiculeContext['prix_location_jour'] != null ? 'Prix location/jour: ${vehiculeContext['prix_location_jour']} DA' : ''}
[FIN CONTEXTE]

$message''';
      }

      final geminiHistory = history
          .where((m) => !m.isLoading && m.content.isNotEmpty)
          .map((m) => Content(
                m.role == 'user' ? 'user' : 'model',
                [TextPart(m.content)],
              ))
          .toList();

      final chat     = _gemini.startChat(history: geminiHistory);
      final response = await chat.sendMessage(Content.text(enrichedMessage));
      return response.text ?? 'Désolé, je n ai pas pu générer de réponse.';

    } catch (e) {
      AppLogger.d('AiRepository.sendMessage: $e');
      if (e.toString().contains('API_KEY')) {
        return '❌ Clé API Gemini invalide.';
      }
      return '❌ Erreur de connexion à l IA. Vérifiez votre connexion.';
    }
  }

  /// Génère une analyse rapide d'un véhicule
  Future<String> analyserVehicule(Map<String, dynamic> vehiculeData) async {
    final prompt = '''Analyse ce véhicule et donne-moi:
1. Un résumé de son état général
2. Des recommandations d'entretien basées sur le kilométrage (${vehiculeData['kilometrage']} km)
3. Une estimation de rentabilité si loué à ${vehiculeData['prix_location_jour']} DA/jour
4. Les points d'attention particuliers

Données: ${vehiculeData.toString()}''';
    return sendMessage(message: prompt, history: []);
  }

  /// Génère des suggestions de prix
  Future<String> suggererPrix({
    required String marque,
    required String modele,
    required int annee,
    required int kilometrage,
  }) async {
    final prompt = '''Pour un $marque $modele de $annee avec $kilometrage km en Algérie:
1. Quel prix de vente est réaliste ?
2. Quel tarif de location journalier est compétitif ?
3. Quelle est la fourchette de prix habituelle pour ce type de véhicule ?
Donne des chiffres précis en DA.''';
    return sendMessage(message: prompt, history: []);
  }
}