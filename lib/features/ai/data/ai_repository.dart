// lib/features/ai/data/ai_repository.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' hide FunctionResponse;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../domain/chat_message.dart';
import '../../../core/utils/app_logger.dart';
import 'ai_schema.dart';
import 'ai_tools_executor.dart';
import '../domain/ai_report_data.dart';

class GeminiModels {
  static const List<Map<String, String>> available = [
    {
      'id': 'gemini-2.5-flash',
      'label': 'Gemini 2.5 Flash',
      'description': 'Dernière génération, ultra-performant ✅',
    },
    {
      'id': 'gemini-2.0-flash',
      'label': 'Gemini 2.0 Flash',
      'description': 'Rapide et équilibré',
    },
    {
      'id': 'gemini-1.5-flash-latest',
      'label': 'Gemini 1.5 Flash',
      'description': 'Stable et robuste',
    },
  ];

  static const String defaultModel = 'gemini-2.0-flash';
}

class AiRepository {
  final SupabaseClient _client;
  final String showroomId;

  GenerativeModel? _model;
  String? _cachedApiKey;
  String? _cachedModelName;
  String? _cachedShowroomId;

  late final AiToolsExecutor _toolsExecutor;

  /// Exécuteur des actions d'écriture (whitelist fermée), déclenché
  /// UNIQUEMENT par un tap utilisateur sur une carte de confirmation —
  /// jamais directement par le modèle. Exposé en public pour l'UI
  /// (ai_action_card.dart).
  late final AiActionExecutor actionExecutor;

  /// Empêche une boucle infinie si le modèle s'obstine à appeler des outils.
  static const int _maxToolRounds = 6;

  AiRepository(this._client, {required this.showroomId}) {
    _toolsExecutor = AiToolsExecutor(_client, showroomId: showroomId);
    actionExecutor = AiActionExecutor(_client, showroomId: showroomId);
  }

  Future<({String? apiKey, String modelName})> _getConfig() async {
    if (showroomId.isEmpty) {
      return (apiKey: null, modelName: GeminiModels.defaultModel);
    }
    try {
      final response = await _client
          .from('showrooms')
          .select('gemini_api_key, gemini_model')
          .eq('id', showroomId)
          .maybeSingle();

      if (response == null) {
        AppLogger.e('Showroom introuvable en BDD : $showroomId');
        return (apiKey: null, modelName: GeminiModels.defaultModel);
      }

      final apiKey = response['gemini_api_key'] as String?;
      final modelName = (response['gemini_model'] as String?)?.trim().isEmpty == false
          ? response['gemini_model'] as String
          : GeminiModels.defaultModel;

      return (apiKey: apiKey, modelName: modelName);
    } catch (e) {
      AppLogger.e('Erreur lors de la récupération de la configuration IA', error: e);
      return (apiKey: null, modelName: GeminiModels.defaultModel);
    }
  }

  Future<GenerativeModel?> _initModel() async {
    if (showroomId.isEmpty) return null;

    final config = await _getConfig();

    if (config.apiKey == null || config.apiKey!.trim().isEmpty) {
      AppLogger.e('Clé gemini_api_key absente pour le showroom $showroomId');
      return null;
    }

    if (_model != null &&
        _cachedApiKey == config.apiKey &&
        _cachedModelName == config.modelName &&
        _cachedShowroomId == showroomId) {
      return _model;
    }

    _model = GenerativeModel(
      model: config.modelName,
      apiKey: config.apiKey!,
      systemInstruction: Content.system(_buildSystemPrompt()),
      tools: AiTools.tools,
    );
    _cachedApiKey = config.apiKey;
    _cachedModelName = config.modelName;
    _cachedShowroomId = showroomId;

    return _model;
  }

  String _buildSystemPrompt() {
    return '''Tu es KarossaAI, l'assistant intelligent de gestion de flotte automobile en Algérie.
Tu guides les gérants et propriétaires de showrooms à analyser leurs performances commerciales, superviser le parc et optimiser la rentabilité.

RÈGLES STRICTES :
1. Tu parles principalement en Français, mais tu comprends et réponds naturellement si l'utilisateur utilise le Darija algérien.
2. Tes réponses doivent être hautement professionnelles, concises et structurées avec du Markdown (listes, gras, tableaux comparatifs).
3. Utilise obligatoirement l'unité "DA" (Dinar Algérien) pour toute donnée ou calcul monétaire.
4. N'affiche jamais d'identifiants techniques bruts (ex: UUID, clés primaires) à l'écran. Préfère les libellés, marques ou noms.
5. Tu as accès à des outils (function calling) pour interroger la base de données réelle du showroom en lecture seule. Utilise-les systématiquement dès qu'une question porte sur des chiffres, un état, une liste ou une tendance — ne réponds jamais "je n'ai pas accès aux données" sans avoir essayé un outil.
6. Base tes analyses exclusivement sur les données renvoyées par tes outils ou fournies en contexte. N'invente jamais de chiffre.

VISUALISATION :
7. Quand une réponse comporte une série de chiffres comparables (répartition, évolution mensuelle, top 5...), ajoute EN PLUS du texte un bloc de graphique au format :
```karossa-chart
{"type":"bar|line|donut","title":"...","unit":"DA|km|%|","series":[{"label":"...","value":123.0}]}
```
Un seul bloc par réponse, après le texte. "bar" pour des comparaisons, "line" pour une évolution dans le temps, "donut" pour une répartition en parts. N'invente jamais de valeur : uniquement celles obtenues via tes outils.

ACTIONS :
8. Tu ne peux JAMAIS écrire en base toi-même. Si une action concrète serait utile (créer une alerte d'entretien, enregistrer un rappel/anomalie à surveiller), termine ta réponse par UN bloc :
```karossa-action
{"action":"creer_alerte_entretien|creer_alerte_ia","label":"Texte du bouton de confirmation","payload":{...}}
```
- creer_alerte_entretien attend : vehicule_id ou immatriculation, type_alerte (vidange|controle_technique|assurance|vignette|pneus|autre), description, et date_echeance (YYYY-MM-DD) ou km_echeance.
- creer_alerte_ia attend : type (anomalie_financiere|entretien|rentabilite|opportunite|autre), severite (info|attention|urgent), titre, message.
Ce bloc n'exécute RIEN automatiquement : il affiche une carte que l'utilisateur doit confirmer. Ne le propose que si l'action est réellement pertinente, jamais par défaut.

VISION :
9. Si l'utilisateur envoie une photo (dommage carrosserie, facture, carte grise...), analyse-la et réponds normalement en texte. Pour une photo de dommage sur véhicule, ajoute EN PLUS un bloc :
```karossa-damage
{"synthese":"...", "cout_estime_da":[min,max], "points":[{"zone":"aile avant droite","gravite":"leger|moyen|grave","type":"rayure|bosse|casse|autre","description":"..."}]}
```
Reste prudent : "cout_estime_da" est une fourchette indicative, précise toujours que c'est une estimation à confirmer par un professionnel.

$_toolUseGuidance
''';
  }

  String get _toolUseGuidance => buildSchemaSummaryForPrompt();

  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
    Map<String, dynamic>? vehiculeContext,
    Map<String, dynamic>? dataContext,
    void Function(String label)? onToolCall,
  }) async {
    try {
      final model = await _initModel();
      if (model == null) {
        return "❌ KarossaAI n'est pas configuré. Veuillez renseigner une clé API Gemini valide dans les paramètres de votre showroom.";
      }

      // L'historique passé au chat NE DOIT PAS contenir le message en cours
      // d'envoi (il est déjà ajouté à `history` côté ChatNotifier avant l'appel),
      // sinon la question est envoyée deux fois au modèle.
      final trimmedHistory = List<ChatMessage>.from(history);
      if (trimmedHistory.isNotEmpty &&
          trimmedHistory.last.role == 'user' &&
          trimmedHistory.last.content == message) {
        trimmedHistory.removeLast();
      }

      final geminiHistory = trimmedHistory
          .map((m) => Content(m.role == 'user' ? 'user' : 'model', [TextPart(m.content)]))
          .toList();

      final chat = model.startChat(history: geminiHistory);
      final buffer = StringBuffer();

      if (dataContext != null) {
        buffer.writeln('=== CONTEXTE DONNÉES SHOWROOM (${dataContext['label']}) ===');
        buffer.writeln(jsonEncode(dataContext['data']));
        buffer.writeln('=== FIN DU CONTEXTE ===\n');
      }

      if (vehiculeContext != null) {
        buffer.writeln('=== CONTEXTE VÉHICULE SÉLECTIONNÉ ===');
        buffer.writeln(jsonEncode(vehiculeContext));
        buffer.writeln('=====================================\n');
      }

      buffer.write('QUESTION : $message');

      var response = await chat.sendMessage(Content.text(buffer.toString()));

      // Boucle de function calling : le modèle peut enchaîner plusieurs
      // requêtes BDD avant de répondre (ex: locations en retard → véhicules
      // concernés → nom du propriétaire).
      var rounds = 0;
      while (response.functionCalls.isNotEmpty && rounds < _maxToolRounds) {
        rounds++;
        final calls = response.functionCalls.toList();
        AppLogger.d('KarossaAI appelle ${calls.length} outil(s) [round $rounds] : '
            '${calls.map((c) => c.name).join(', ')}');

        final functionResponses = <FunctionResponse>[];
        for (final call in calls) {
          onToolCall?.call(_toolTraceLabel(call.name, call.args));
          final result = await _toolsExecutor.execute(call.name, call.args);
          functionResponses.add(FunctionResponse(call.name, result));
        }

        response = await chat.sendMessage(Content.functionResponses(functionResponses));
      }

      return response.text ??
          (rounds >= _maxToolRounds
              ? "❌ KarossaAI n'est pas parvenu à conclure son analyse (trop d'allers-retours). Reformulez votre question."
              : "KarossaAI n'a pas pu formuler de réponse.");
    } catch (e) {
      AppLogger.e('Erreur de communication AiRepository.sendMessage', error: e);
      final err = e.toString().toLowerCase();

      if (err.contains('api_key') || err.contains('invalid')) {
        return '❌ La clé API configurée pour ce showroom est invalide.';
      }
      if (err.contains('quota') || err.contains('resource_exhausted')) {
        return '❌ Quota de requêtes atteint pour ce showroom. Veuillez réessuyer dans quelques instants.';
      }
      return '❌ Connexion impossible avec KarossaAI. Vérifiez l\'accès réseau de votre concession.';
    }
  }

  /// Variante "machine à écrire" de [sendMessage] : diffuse le texte de la
  /// réponse au fur et à mesure qu'il est généré (effet wow), tout en
  /// conservant la boucle de function calling (les tours d'outils restent
  /// silencieux côté flux, seul le texte final est streamé). Chaque valeur
  /// émise est un DELTA à concaténer, pas le texte complet.
  Stream<String> sendMessageStream({
    required String message,
    required List<ChatMessage> history,
    Map<String, dynamic>? vehiculeContext,
    Map<String, dynamic>? dataContext,
    void Function(String label)? onToolCall,
  }) async* {
    final model = await _initModel();
    if (model == null) {
      yield "❌ KarossaAI n'est pas configuré. Veuillez renseigner une clé API Gemini valide dans les paramètres de votre showroom.";
      return;
    }

    try {
      final trimmedHistory = List<ChatMessage>.from(history);
      if (trimmedHistory.isNotEmpty &&
          trimmedHistory.last.role == 'user' &&
          trimmedHistory.last.content == message) {
        trimmedHistory.removeLast();
      }
      final geminiHistory = trimmedHistory
          .map((m) => Content(m.role == 'user' ? 'user' : 'model', [TextPart(m.content)]))
          .toList();

      final chat = model.startChat(history: geminiHistory);

      final buffer = StringBuffer();
      if (dataContext != null) {
        buffer.writeln('=== CONTEXTE DONNÉES SHOWROOM (${dataContext['label']}) ===');
        buffer.writeln(jsonEncode(dataContext['data']));
        buffer.writeln('=== FIN DU CONTEXTE ===\n');
      }
      if (vehiculeContext != null) {
        buffer.writeln('=== CONTEXTE VÉHICULE SÉLECTIONNÉ ===');
        buffer.writeln(jsonEncode(vehiculeContext));
        buffer.writeln('=====================================\n');
      }
      buffer.write('QUESTION : $message');

      Content nextContent = Content.text(buffer.toString());
      var rounds = 0;
      var emittedAny = false;

      while (true) {
        final calls = <FunctionCall>[];
        await for (final chunk in chat.sendMessageStream(nextContent)) {
          if (chunk.functionCalls.isNotEmpty) {
            calls.addAll(chunk.functionCalls);
          }
          final delta = chunk.text;
          if (delta != null && delta.isNotEmpty) {
            emittedAny = true;
            yield delta;
          }
        }

        if (calls.isEmpty) {
          if (!emittedAny) {
            yield "KarossaAI n'a pas pu formuler de réponse.";
          }
          return;
        }

        rounds++;
        if (rounds > _maxToolRounds) {
          yield "\n\n❌ KarossaAI n'est pas parvenu à conclure son analyse (trop d'allers-retours). Reformulez votre question.";
          return;
        }

        AppLogger.d('KarossaAI (stream) appelle ${calls.length} outil(s) [round $rounds] : '
            '${calls.map((c) => c.name).join(', ')}');

        final functionResponses = <FunctionResponse>[];
        for (final call in calls) {
          onToolCall?.call(_toolTraceLabel(call.name, call.args));
          final result = await _toolsExecutor.execute(call.name, call.args);
          functionResponses.add(FunctionResponse(call.name, result));
        }
        nextContent = Content.functionResponses(functionResponses);
      }
    } catch (e) {
      AppLogger.e('Erreur de communication AiRepository.sendMessageStream', error: e);
      final err = e.toString().toLowerCase();
      if (err.contains('api_key') || err.contains('invalid')) {
        yield '❌ La clé API configurée pour ce showroom est invalide.';
      } else if (err.contains('quota') || err.contains('resource_exhausted')) {
        yield '❌ Quota de requêtes atteint pour ce showroom. Veuillez réessuyer dans quelques instants.';
      } else {
        yield '❌ Connexion impossible avec KarossaAI. Vérifiez l\'accès réseau de votre concession.';
      }
    }
  }

  /// Analyse une photo envoyée dans le chat (dommage carrosserie, facture,
  /// carte grise...). Ne fait pas partie de la boucle d'outils : c'est un
  /// message multimodal ponctuel, avec la même mémoire de conversation.
  Future<String> analyserPhoto({
    required Uint8List imageBytes,
    required String mimeType,
    required String message,
    required List<ChatMessage> history,
  }) async {
    final model = await _initModel();
    if (model == null) {
      return "❌ KarossaAI n'est pas configuré. Veuillez renseigner une clé API Gemini valide dans les paramètres de votre showroom.";
    }
    try {
      final geminiHistory = history
          .where((m) => !m.isLoading && m.content.isNotEmpty)
          .map((m) => Content(m.role == 'user' ? 'user' : 'model', [TextPart(m.content)]))
          .toList();

      final chat = model.startChat(history: geminiHistory);
      final response = await chat.sendMessage(
        Content.multi([TextPart(message), DataPart(mimeType, imageBytes)]),
      );

      // Les photos peuvent aussi déclencher des outils (ex: comparer avec
      // l'historique de réparations du véhicule identifié sur la photo).
      var resp = response;
      var rounds = 0;
      while (resp.functionCalls.isNotEmpty && rounds < _maxToolRounds) {
        rounds++;
        final functionResponses = <FunctionResponse>[];
        for (final call in resp.functionCalls) {
          final result = await _toolsExecutor.execute(call.name, call.args);
          functionResponses.add(FunctionResponse(call.name, result));
        }
        resp = await chat.sendMessage(Content.functionResponses(functionResponses));
      }

      return resp.text ?? "KarossaAI n'a pas pu analyser cette photo.";
    } catch (e) {
      AppLogger.e('Erreur AiRepository.analyserPhoto', error: e);
      return '❌ Analyse impossible : vérifiez la photo et votre connexion.';
    }
  }

  Future<String> analyserVehicule(Map<String, dynamic> vehiculeData) async {
    final prompt = '''Effectue une analyse globale pour ce véhicule :
1. Résumé de son état et fiche technique.
2. Plan de maintenance préventive personnalisé au kilométrage actuel (${vehiculeData['kilometrage']} km).
3. Étude de rentabilité sur la base d'une location à ${vehiculeData['prix_location_jour']} DA/jour, en t'appuyant si besoin sur l'historique réel des locations de ce véhicule via tes outils.

Fiche technique : ${vehiculeData.toString()}''';
    return sendMessage(message: prompt, history: []);
  }

  Future<String> suggererPrix({
    required String marque,
    required String modele,
    required int annee,
    required int kilometrage,
  }) async {
    final prompt = '''Analyse du marché automobile algérien pour : $marque $modele ($annee - $kilometrage km) :
1. Estimation de la fourchette de prix de vente réaliste.
2. Tarif journalier de location recommandé face à la concurrence.
3. Attractivité et liquidité de ce modèle en Algérie.
4. Si des véhicules similaires existent déjà dans le parc du showroom, compare avec leurs prix réels via tes outils.''';
    return sendMessage(message: prompt, history: []);
  }

  /// Construit un rapport mensuel prêt à être mis en PDF : données réelles
  /// (dashboard + anomalies calculées côté serveur, pas par le LLM) +
  /// synthèse rédigée en français par Gemini à partir de CES données précises.
  Future<AiReportData> genererRapportMensuel() async {
    final resume = await _toolsExecutor.execute('get_dashboard_summary', {});
    final anomaliesResult = await _toolsExecutor.execute('detect_anomalies', {});
    final anomalies =
        List<Map<String, dynamic>>.from(anomaliesResult['anomalies_detectees'] ?? []);

    final model = await _initModel();
    final now = DateTime.now();
    final periode = '${_moisFr(now.month)} ${now.year}';

    String narratif;
    if (model == null) {
      narratif = "KarossaAI n'a pas pu rédiger de synthèse (IA non configurée pour ce showroom).";
    } else {
      final prompt = '''Rédige une synthèse professionnelle et concise (5 à 8 phrases, Markdown léger,
DA obligatoire) du mois de $periode pour ce showroom, à partir EXCLUSIVEMENT des données suivantes.
N'ajoute aucun chiffre qui n'y figure pas. Termine par une recommandation actionnable si pertinent.

DONNÉES DU MOIS :
${jsonEncode(resume)}

ANOMALIES DÉTECTÉES (mois courant vs moyenne des 3 mois précédents) :
${jsonEncode(anomalies)}''';

      final response = await model.startChat().sendMessage(Content.text(prompt));
      narratif = response.text ?? 'Synthèse indisponible.';
    }

    return AiReportData(
      titre: 'Rapport mensuel KarossaAI',
      periode: periode,
      narratif: narratif,
      resume: resume,
      anomalies: anomalies,
    );
  }

  String _toolTraceLabel(String toolName, Map<String, Object?> args) {
    final table = args['table'] as String?;
    switch (toolName) {
      case 'query_table':
        return '🔍 Consultation de ${_tableLabel(table)}…';
      case 'aggregate_table':
        return '🧮 Calcul sur ${_tableLabel(table)}…';
      case 'detect_anomalies':
        return '🚨 Analyse des écarts financiers…';
      case 'get_dashboard_summary':
        return '📊 Génération du tableau de bord…';
      default:
        return '⚙️ Traitement en cours…';
    }
  }

  String _tableLabel(String? table) => const {
        'vehicules': 'la flotte de véhicules',
        'clients': 'la base clients',
        'locations': 'l\'historique des locations',
        'location_paiements': 'les paiements de location',
        'ventes': 'l\'historique des ventes',
        'vente_paiements': 'les paiements de vente',
        'echanges': 'les échanges de véhicules',
        'achats': 'les acquisitions de véhicules',
        'caisse_operations': 'la caisse',
        'reparations': 'l\'historique des réparations',
        'alertes_entretien': 'les alertes d\'entretien',
        'versements_proprietaires': 'les versements propriétaires',
        'reservations_web': 'les réservations en ligne',
        'demandes_devis': 'les demandes de devis',
        'propositions_vente': 'les propositions de vente',
        'profiles': 'les profils utilisateurs',
        'vehicule_proprietes': 'la répartition de propriété',
        'transferts_utilisateurs': 'les transferts internes',
      }[table] ??
      'la base de données';

  String _moisFr(int m) => const [
        'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
        'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
      ][m - 1];

  void resetModel() {
    _model = null;
    _cachedApiKey = null;
    _cachedModelName = null;
    _cachedShowroomId = null;
    AppLogger.d('AiRepository : Cache nettoyé.');
  }
}