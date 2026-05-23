// lib/core/services/carte_grise_ocr_service.dart
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  CORRECTIF  "_Namespace / Unsupported operation"                        │
// │                                                                         │
// │  CAUSE : google_mlkit_text_recognition + path_provider s'appuient sur  │
// │  dart:io (File, Directory) → planté sur Flutter Web avec "_Namespace"  │
// │                                                                         │
// │  SOLUTION : stratégie double selon la plateforme                        │
// │  • Mobile (Android / iOS) → ML Kit local, comme avant, MAIS            │
// │    en écrivant le fichier temp SEULEMENT si pas Web                    │
// │  • Web → Gemini Vision REST API, bytes uniquement (pas de dart:io)     │
// │                                                                         │
// │  Toute la logique de parsing (_extractCarteGriseData) est conservée.   │
// │                                                                         │
// │  Dépendances à ajouter dans pubspec.yaml si absentes :                 │
// │    http: ^1.2.0                                                         │
// └─────────────────────────────────────────────────────────────────────────┘

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';

// Ces imports ne seront résolus que sur mobile grâce aux guards kIsWeb
// On les déclare ici mais on ne les appelle JAMAIS sur Web.
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;

// ─────────────────────────────────────────────────────────────────────────────
// Modèle de résultat  (identique à l'original)
// ─────────────────────────────────────────────────────────────────────────────
class CarteGriseData {
  final String? immatriculation;
  final String? marque;
  final String? modele;
  final String? datePremiereImmat;
  final String? nomTitulaire;
  final String? prenomTitulaire;
  final String? adresseTitulaire;
  final int? annee;
  final String? puissanceFiscale;
  final String? energie;
  final String? numChassis;
  final String? categorie;
  final int? nbPlaces;
  final int? poids;
  final String? couleur;

  const CarteGriseData({
    this.immatriculation,
    this.marque,
    this.modele,
    this.datePremiereImmat,
    this.nomTitulaire,
    this.prenomTitulaire,
    this.adresseTitulaire,
    this.annee,
    this.puissanceFiscale,
    this.energie,
    this.numChassis,
    this.categorie,
    this.nbPlaces,
    this.poids,
    this.couleur,
  });

  factory CarteGriseData.fromJson(Map<String, dynamic> json) {
    return CarteGriseData(
      immatriculation: json['immatriculation'] as String?,
      marque: json['marque'] as String?,
      modele: json['modele'] as String?,
      datePremiereImmat: json['date_premiere_immat'] as String?,
      nomTitulaire: json['nom_titulaire'] as String?,
      prenomTitulaire: json['prenom_titulaire'] as String?,
      adresseTitulaire: json['adresse_titulaire'] as String?,
      annee: (json['annee'] as num?)?.toInt(),
      puissanceFiscale: json['puissance_fiscale'] as String?,
      energie: json['energie'] as String?,
      numChassis: json['num_chassis'] as String?,
      categorie: json['categorie'] as String?,
      nbPlaces: (json['nb_places'] as num?)?.toInt(),
      poids: (json['poids'] as num?)?.toInt(),
      couleur: json['couleur'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'immatriculation': immatriculation,
        'marque': marque,
        'modele': modele,
        'date_premiere_immat': datePremiereImmat,
        'nom_titulaire': nomTitulaire,
        'prenom_titulaire': prenomTitulaire,
        'adresse_titulaire': adresseTitulaire,
        'annee': annee,
        'puissance_fiscale': puissanceFiscale,
        'energie': energie,
        'num_chassis': numChassis,
        'categorie': categorie,
        'nb_places': nbPlaces,
        'poids': poids,
        'couleur': couleur,
      };

  bool get isValid => immatriculation != null && marque != null;
  bool get hasData =>
      immatriculation != null || marque != null || modele != null;

  @override
  String toString() =>
      'CarteGriseData(immat: $immatriculation, marque: $marque, modele: $modele, annee: $annee)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Service OCR — compatible Web + Mobile
// ─────────────────────────────────────────────────────────────────────────────

/// Service OCR pour carte grise.
///
/// Usage (dans vehicule_form_screen.dart) :
///   // Récupérer la clé depuis Supabase showroom_settings
///   final row = await supabase.from('showroom_settings')
///       .select('gemini_api_key').limit(1).maybeSingle();
///   final key = row?['gemini_api_key'] as String? ?? '';
///
///   final svc = CarteGriseOcrService(geminiApiKey: key);
///   final Uint8List bytes = await xfile.readAsBytes();   // ← pas de dart:io File
///   final data = await svc.scanCarteGrise(bytes);
class CarteGriseOcrService {
  // Singleton souple : la clé peut être mise à jour entre les appels
  static CarteGriseOcrService? _instance;

  factory CarteGriseOcrService({String? geminiApiKey}) {
    _instance ??= CarteGriseOcrService._internal();
    if (geminiApiKey != null) _instance!._geminiApiKey = geminiApiKey;
    return _instance!;
  }

  CarteGriseOcrService._internal();

  String? _geminiApiKey;

  // ML Kit TextRecognizer — instancié uniquement sur mobile
  TextRecognizer? _textRecognizer;
  bool _mlkitInitialized = false;

  // ── Initialisation ML Kit (mobile seulement) ──────────────────────────────
  Future<void> _initMlKit() async {
    if (_mlkitInitialized) return;
    _textRecognizer = TextRecognizer();
    _mlkitInitialized = true;
    AppLogger.d('CarteGriseOcrService: ML Kit initialisé');
  }

  // ── Point d'entrée public ─────────────────────────────────────────────────

  /// [imageBytes] → résultat de XFile.readAsBytes() (fonctionne partout)
  /// [mimeType]   → 'image/jpeg' ou 'image/png'
  Future<CarteGriseData> scanCarteGrise(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final String rawText;

      if (kIsWeb) {
        // ── WEB : Gemini Vision REST ──────────────────────────────────────
        AppLogger.d('CarteGriseOcrService: Mode Web → Gemini Vision REST');
        rawText = await _geminiOcr(imageBytes, mimeType);
      } else {
        // ── MOBILE : ML Kit local ─────────────────────────────────────────
        AppLogger.d('CarteGriseOcrService: Mode Mobile → ML Kit local');
        rawText = await _mlKitOcr(imageBytes);
      }

      AppLogger.d(
          'CarteGriseOcrService: Texte reconnu (${rawText.length} car.)');
      if (kDebugMode) {
        AppLogger.d('=== TEXTE OCR BRUT ===\n$rawText\n=====================');
      }

      final data = _extractCarteGriseData(rawText);
      AppLogger.d('CarteGriseOcrService: Données extraites: $data');
      return data;
    } catch (e, st) {
      AppLogger.d('CarteGriseOcrService: Erreur OCR carte grise: $e\n$st');
      rethrow;
    }
  }

  // ── ML Kit (Android / iOS) ────────────────────────────────────────────────

  Future<String> _mlKitOcr(Uint8List bytes) async {
    await _initMlKit();

    // Écriture dans un fichier temporaire (dart:io OK sur mobile)
    final dir = await getApplicationDocumentsDirectory();
    final tempPath =
        '${dir.path}/temp_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tempFile = io.File(tempPath);
    await tempFile.writeAsBytes(bytes);

    try {
      InputImage inputImage;
      try {
        inputImage = InputImage.fromFile(tempFile);
      } catch (_) {
        inputImage = InputImage.fromFilePath(tempPath);
      }

      final recognized = await _textRecognizer!.processImage(inputImage);

      // Debug : sauvegarde texte brut
      if (kDebugMode) {
        try {
          final logFile = io.File(
              '${dir.path}/ocr_debug_${DateTime.now().millisecondsSinceEpoch}.txt');
          await logFile.writeAsString(recognized.text);
          AppLogger.d(
              'CarteGriseOcrService: Log brut → ${logFile.path}');
        } catch (_) {}
      }

      return recognized.text;
    } finally {
      // Nettoyage fichier temp
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  // ── Gemini Vision REST (Web) ──────────────────────────────────────────────

  Future<String> _geminiOcr(Uint8List bytes, String mimeType) async {
    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      throw Exception(
          'Clé API Gemini non configurée. '
          'Allez dans Paramètres > Showroom pour la renseigner.');
    }

    // On demande à Gemini de retourner le texte brut ligne par ligne
    // (exactement comme ML Kit le ferait), pour que _extractCarteGriseData
    // fonctionne identiquement sur Web et Mobile.
    const prompt =
        'Tu es un expert OCR de cartes grises. '
        'Retourne UNIQUEMENT le texte brut tel qu\'il apparaît sur le document, '
        'ligne par ligne, en conservant les codes de champs (A.1, D.1, D.2, B.1, '
        'C.1, C.2, C.3, P.2, P.3, E, J.1, J.2, F.1, etc.). '
        'Ne reformate pas, ne traduis pas, ne résume pas.';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(bytes),
              }
            },
            {'text': prompt},
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.0,
        'maxOutputTokens': 1024,
      },
    });

    final response = await http
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/'
            'gemini-1.5-flash:generateContent?key=$_geminiApiKey',
          ),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API erreur ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini: réponse vide (candidates absent)');
    }
    final parts = (candidates[0]['content']?['parts'] as List?) ?? [];
    return parts
        .whereType<Map>()
        .map((p) => p['text'] ?? '')
        .join('');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Parsing OCR  (logique originale conservée à l'identique)
  // ─────────────────────────────────────────────────────────────────────────

  CarteGriseData _extractCarteGriseData(String text) {
    if (text.isEmpty) {
      AppLogger.d('CarteGriseOcrService: Texte vide, aucune donnée à extraire');
      return const CarteGriseData();
    }

    final normalizedText =
        text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\s:/.-]'), '');
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    AppLogger.d('CarteGriseOcrService: ${lines.length} lignes à analyser');

    String? immatriculation;
    String? marque;
    String? modele;
    String? datePremiereImmat;
    String? nomTitulaire;
    String? prenomTitulaire;
    String? adresseTitulaire;
    int? annee;
    String? puissanceFiscale;
    String? energie;
    String? numChassis;
    String? categorie;
    int? nbPlaces;
    int? poids;
    String? couleur;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lineUpper = line.toUpperCase();

      AppLogger.d('CarteGriseOcrService: Analyse ligne $i: "$line"');

      // A.1 - Immatriculation
      if (lineUpper.contains('A.1') || lineUpper.contains('A1')) {
        final match = RegExp(
                r'([A-Z]{2}-\d{3}-[A-Z]{2}|\d{1,3}\s?[A-Z]{2,3}\s?\d{2,3}|\d{9})')
            .firstMatch(line);
        if (match != null) {
          immatriculation = match.group(1)?.replaceAll(' ', '');
          AppLogger.d(
              'CarteGriseOcrService: Immatriculation trouvée: $immatriculation');
        } else {
          final parts = line.split(RegExp(r'A\.?1')).last.trim();
          if (parts.isNotEmpty && parts.length > 2) {
            immatriculation = parts.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
            AppLogger.d(
                'CarteGriseOcrService: Immatriculation (reste ligne): $immatriculation');
          }
        }
      }

      // D.1 - Marque
      if (lineUpper.contains('D.1') || lineUpper.contains('D1')) {
        final parts = line.split(RegExp(r'D\.?1')).last.trim();
        if (parts.isNotEmpty && parts.length > 2) {
          marque = parts;
          AppLogger.d('CarteGriseOcrService: Marque trouvée: $marque');
        }
      }

      // D.2 - Modèle/Type
      if (lineUpper.contains('D.2') || lineUpper.contains('D2')) {
        final parts = line.split(RegExp(r'D\.?2')).last.trim();
        if (parts.isNotEmpty) {
          modele = parts;
          AppLogger.d('CarteGriseOcrService: Modèle trouvé: $modele');
        }
      }

      // B.1 - Date première immatriculation
      if (lineUpper.contains('B.1') || lineUpper.contains('B1')) {
        final match =
            RegExp(r'(\d{2}[/.-]\d{2}[/.-]\d{4})').firstMatch(line);
        if (match != null) {
          datePremiereImmat = match.group(1);
          AppLogger.d(
              'CarteGriseOcrService: Date immat trouvée: $datePremiereImmat');
          final yearMatch =
              RegExp(r'(\d{4})$').firstMatch(datePremiereImmat!);
          if (yearMatch != null) {
            annee = int.tryParse(yearMatch.group(1)!);
            AppLogger.d('CarteGriseOcrService: Année déduite: $annee');
          }
        }
      }

      // C.1 - Nom du titulaire
      if (lineUpper.contains('C.1') || lineUpper.contains('C1')) {
        final parts = line.split(RegExp(r'C\.?1')).last.trim();
        if (parts.isNotEmpty) {
          nomTitulaire = parts;
          AppLogger.d(
              'CarteGriseOcrService: Nom titulaire trouvé: $nomTitulaire');
        }
      }

      // C.2 - Prénom du titulaire
      if (lineUpper.contains('C.2') || lineUpper.contains('C2')) {
        final parts = line.split(RegExp(r'C\.?2')).last.trim();
        if (parts.isNotEmpty) {
          prenomTitulaire = parts;
          AppLogger.d(
              'CarteGriseOcrService: Prénom titulaire trouvé: $prenomTitulaire');
        }
      }

      // C.3 - Adresse du titulaire
      if (lineUpper.contains('C.3') || lineUpper.contains('C3')) {
        final parts = line.split(RegExp(r'C\.?3')).last.trim();
        if (parts.isNotEmpty) {
          adresseTitulaire = parts;
          AppLogger.d(
              'CarteGriseOcrService: Adresse titulaire trouvée: $adresseTitulaire');
        }
      }

      // P.2 - Puissance fiscale
      if (lineUpper.contains('P.2') || lineUpper.contains('P2')) {
        final match = RegExp(r'(\d+)\s*CV').firstMatch(line);
        if (match != null) {
          puissanceFiscale = '${match.group(1)} CV';
          AppLogger.d(
              'CarteGriseOcrService: Puissance fiscale trouvée: $puissanceFiscale');
        }
      }

      // P.3 - Type de carburant/énergie
      if (lineUpper.contains('P.3') || lineUpper.contains('P3')) {
        final parts = line.split(RegExp(r'P\.?3')).last.trim();
        if (parts.isNotEmpty) {
          energie = _normalizeEnergie(parts);
          AppLogger.d('CarteGriseOcrService: Énergie trouvée: $energie');
        }
      }

      // E / E.1 - VIN (17 caractères alphanumériques)
      if (lineUpper.contains('E.1') ||
          lineUpper.contains('E1') ||
          lineUpper.contains(' E ')) {
        final vinMatch =
            RegExp(r'([A-HJ-NPR-Z0-9]{17})').firstMatch(line);
        if (vinMatch != null) {
          numChassis = vinMatch.group(1);
          AppLogger.d('CarteGriseOcrService: VIN trouvé: $numChassis');
        }
      }

      // J.1 - Nombre de places
      if (lineUpper.contains('J.1') || lineUpper.contains('J1')) {
        final match = RegExp(r'(\d+)').firstMatch(line);
        if (match != null) {
          nbPlaces = int.tryParse(match.group(1)!);
          AppLogger.d('CarteGriseOcrService: Nb places trouvé: $nbPlaces');
        }
      }

      // J.2 - Catégorie
      if (lineUpper.contains('J.2') || lineUpper.contains('J2')) {
        final parts = line.split(RegExp(r'J\.?2')).last.trim();
        if (parts.isNotEmpty) {
          categorie = parts;
          AppLogger.d('CarteGriseOcrService: Catégorie trouvée: $categorie');
        }
      }

      // F.1 - Poids
      if (lineUpper.contains('F.1') || lineUpper.contains('F1')) {
        final match = RegExp(r'(\d+)\s*KG').firstMatch(line);
        if (match != null) {
          poids = int.tryParse(match.group(1)!);
          AppLogger.d('CarteGriseOcrService: Poids trouvé: $poids');
        }
      }
    }

    // Fallback immatriculation globale (format européen)
    if (immatriculation == null) {
      final immatMatch =
          RegExp(r'([A-Z]{2}-\d{3}-[A-Z]{2})').firstMatch(normalizedText);
      if (immatMatch != null) {
        immatriculation = immatMatch.group(1);
        AppLogger.d(
            'CarteGriseOcrService: Immatriculation (regex globale): $immatriculation');
      }
    }

    // Fallback marque depuis modèle
    if (marque == null && modele != null) {
      final words = modele.split(' ');
      if (words.isNotEmpty) {
        marque = words.first;
        AppLogger.d(
            'CarteGriseOcrService: Marque déduite du modèle: $marque');
      }
    }

    return CarteGriseData(
      immatriculation: immatriculation,
      marque: marque,
      modele: modele,
      datePremiereImmat: datePremiereImmat,
      nomTitulaire: nomTitulaire,
      prenomTitulaire: prenomTitulaire,
      adresseTitulaire: adresseTitulaire,
      annee: annee,
      puissanceFiscale: puissanceFiscale,
      energie: energie,
      numChassis: numChassis,
      categorie: categorie,
      nbPlaces: nbPlaces,
      poids: poids,
      couleur: couleur,
    );
  }

  String _normalizeEnergie(String energie) {
    final e = energie.toUpperCase().trim();
    if (e.contains('ES')) return 'Essence';
    if (e.contains('GAZ') || e.contains('GPL')) return 'GPL';
    if (e.contains('DIE') || e.contains('GAS')) return 'Diesel';
    if (e.contains('ELEC') || e.contains('ELE')) return 'Électrique';
    if (e.contains('HYB')) return 'Hybride';
    return e;
  }

  /// Libère les ressources ML Kit (à appeler dans dispose() du widget si besoin)
  void dispose() {
    _textRecognizer?.close();
    _mlkitInitialized = false;
  }
}