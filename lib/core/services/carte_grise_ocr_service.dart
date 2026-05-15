// lib/core/services/carte_grise_ocr_service.dart
// Service OCR pour extraire les données d'une carte grise (certificat d'immatriculation)
// Version améliorée avec gestion d'erreurs et debug

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_logger.dart';

/// Modèle pour les données extraites d'une carte grise
class CarteGriseData {
  final String? immatriculation;    // A.1 - Numéro d'immatriculation
  final String? marque;             // D.1 - Marque
  final String? modele;             // D.2 - Type, variante, version
  final String? datePremiereImmat;  // B.1 - Date première immatriculation
  final String? nomTitulaire;       // C.1 - Nom du titulaire
  final String? prenomTitulaire;    // C.2 - Prénom du titulaire
  final String? adresseTitulaire;   // C.3 - Adresse du titulaire
  final int? annee;                 // Déduite de B.1
  final String? puissanceFiscale;   // P.2 - Puissance fiscale
  final String? energie;            // P.3 - Type de carburant/énergie
  final String? numChassis;         // E.1 - Numéro d'identification du véhicule (VIN)
  final String? categorie;          // J.2 - Catégorie du véhicule
  final int? nbPlaces;              // J.1 - Nombre de places assises
  final int? poids;                 // F.1 - Poids en charge max
  final String? couleur;            // Couleur (si présente)

  CarteGriseData({
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

  /// Crée une instance à partir d'un JSON
  factory CarteGriseData.fromJson(Map<String, dynamic> json) {
    return CarteGriseData(
      immatriculation: json['immatriculation'],
      marque: json['marque'],
      modele: json['modele'],
      datePremiereImmat: json['date_premiere_immat'],
      nomTitulaire: json['nom_titulaire'],
      prenomTitulaire: json['prenom_titulaire'],
      adresseTitulaire: json['adresse_titulaire'],
      annee: json['annee'],
      puissanceFiscale: json['puissance_fiscale'],
      energie: json['energie'],
      numChassis: json['num_chassis'],
      categorie: json['categorie'],
      nbPlaces: json['nb_places'],
      poids: json['poids'],
      couleur: json['couleur'],
    );
  }

  /// Convertit en JSON
  Map<String, dynamic> toJson() {
    return {
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
  }

  /// Vérifie si les données minimales sont présentes
  bool get isValid => immatriculation != null && marque != null;

  /// Vérifie si au moins une donnée a été extraite
  bool get hasData => immatriculation != null || marque != null || modele != null;

  @override
  String toString() {
    return 'CarteGriseData(immat: $immatriculation, marque: $marque, modele: $modele, annee: $annee)';
  }
}

/// Service OCR pour carte grise utilisant Google ML Kit
class CarteGriseOcrService {
  static final CarteGriseOcrService _instance = CarteGriseOcrService._internal();
  factory CarteGriseOcrService() => _instance;
  CarteGriseOcrService._internal();

  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isInitialized = false;

  /// Initialise le service OCR
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Le TextRecognizer est prêt à l'emploi, pas d'initialisation spéciale nécessaire
    _isInitialized = true;
    AppLogger.d('CarteGriseOcrService: Initialisé avec succès');
  }

  /// Traite une image de carte grise et extrait les données
  Future<CarteGriseData> scanCarteGrise(File imageFile) async {
    try {
      await initialize();
      
      // Vérifier que le fichier existe
      if (!await imageFile.exists()) {
        throw Exception('Fichier image introuvable: ${imageFile.path}');
      }
      
      AppLogger.d('CarteGriseOcrService: Traitement de l\'image ${imageFile.path}');
      
      // Option 1: Utiliser InputImage.fromFile (méthode standard)
      InputImage inputImage;
      try {
        inputImage = InputImage.fromFile(imageFile);
      } catch (e) {
        AppLogger.d('CarteGriseOcrService: Erreur InputImage.fromFile: $e');
        // Option 2: Utiliser InputImage.fromFilePath (alternative)
        try {
          inputImage = InputImage.fromFilePath(imageFile.path);
          AppLogger.d('CarteGriseOcrService: Utilisation de InputImage.fromFilePath');
        } catch (e2) {
          AppLogger.d('CarteGriseOcrService: Erreur InputImage.fromFilePath: $e2');
          throw Exception('Impossible de charger l\'image: ${e.toString()}');
        }
      }
      
      // Reconnaître le texte
      AppLogger.d('CarteGriseOcrService: Démarrage de la reconnaissance de texte...');
      final recognizedText = await _textRecognizer.processImage(inputImage);
      AppLogger.d('CarteGriseOcrService: Texte reconnu (${recognizedText.text.length} caractères)');
      
      if (kDebugMode) {
        AppLogger.d('=== TEXTE OCR BRUT ===');
        AppLogger.d(recognizedText.text);
        AppLogger.d('=====================');
      }
      
      // Sauvegarder le texte brut pour debugging (optionnel)
      if (kDebugMode) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final logFile = File('${dir.path}/ocr_debug_${DateTime.now().millisecondsSinceEpoch}.txt');
          await logFile.writeAsString(recognizedText.text);
          AppLogger.d('CarteGriseOcrService: Texte brut sauvegardé dans ${logFile.path}');
        } catch (e) {
          // Ignorer les erreurs de sauvegarde
        }
      }
      
      // Extraire les données structurées
      final data = _extractCarteGriseData(recognizedText.text);
      
      AppLogger.d('CarteGriseOcrService: Données extraites: $data');
      
      return data;
    } catch (e) {
      AppLogger.d('CarteGriseOcrService: Erreur OCR carte grise: $e');
      rethrow;
    }
  }

  /// Traite une image depuis des bytes (alternative)
  Future<CarteGriseData> scanCarteGriseFromBytes(Uint8List bytes) async {
    try {
      await initialize();
      
      // Sauvegarder temporairement les bytes
      final dir = await getApplicationDocumentsDirectory();
      final tempFile = File('${dir.path}/temp_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      
      try {
        return await scanCarteGrise(tempFile);
      } finally {
        // Nettoyer le fichier temporaire
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      AppLogger.d('CarteGriseOcrService: Erreur scanCarteGriseFromBytes: $e');
      rethrow;
    }
  }

  /// Extrait les données structurées du texte OCR
  CarteGriseData _extractCarteGriseData(String text) {
    if (text.isEmpty) {
      AppLogger.d('CarteGriseOcrService: Texte vide, aucune donnée à extraire');
      return CarteGriseData();
    }
    
    // Nettoyer et normaliser le texte
    final normalizedText = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\s:/.-]'), '');
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
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

    // Parser ligne par ligne
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lineUpper = line.toUpperCase();
      
      AppLogger.d('CarteGriseOcrService: Analyse ligne $i: "$line"');
      
      // A.1 - Immatriculation (format européen ou ancien)
      if (lineUpper.contains('A.1') || lineUpper.contains('A1')) {
        // Chercher le numéro d'immatriculation sur la même ligne ou la suivante
        final match = RegExp(r'([A-Z]{2}-\d{3}-[A-Z]{2}|\d{1,3}\s?[A-Z]{2,3}\s?\d{2,3}|\d{9})').firstMatch(line);
        if (match != null) {
          immatriculation = match.group(1)?.replaceAll(' ', '');
          AppLogger.d('CarteGriseOcrService: Immatriculation trouvée: $immatriculation');
        } else {
          // Essayer de prendre le reste de la ligne après A.1
          final parts = line.split(RegExp(r'A\.?1')).last.trim();
          if (parts.isNotEmpty && parts.length > 2) {
            immatriculation = parts.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
            AppLogger.d('CarteGriseOcrService: Immatriculation (reste ligne): $immatriculation');
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
        final match = RegExp(r'(\d{2}[/.-]\d{2}[/.-]\d{4})').firstMatch(line);
        if (match != null) {
          datePremiereImmat = match.group(1);
          AppLogger.d('CarteGriseOcrService: Date immat trouvée: $datePremiereImmat');
          // Extraire l'année
          final yearMatch = RegExp(r'(\d{4})$').firstMatch(datePremiereImmat!);
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
          AppLogger.d('CarteGriseOcrService: Nom titulaire trouvé: $nomTitulaire');
        }
      }
      
      // C.2 - Prénom du titulaire
      if (lineUpper.contains('C.2') || lineUpper.contains('C2')) {
        final parts = line.split(RegExp(r'C\.?2')).last.trim();
        if (parts.isNotEmpty) {
          prenomTitulaire = parts;
          AppLogger.d('CarteGriseOcrService: Prénom titulaire trouvé: $prenomTitulaire');
        }
      }
      
      // C.3 - Adresse du titulaire
      if (lineUpper.contains('C.3') || lineUpper.contains('C3')) {
        final parts = line.split(RegExp(r'C\.?3')).last.trim();
        if (parts.isNotEmpty) {
          adresseTitulaire = parts;
          AppLogger.d('CarteGriseOcrService: Adresse titulaire trouvée: $adresseTitulaire');
        }
      }
      
      // P.2 - Puissance fiscale
      if (lineUpper.contains('P.2') || lineUpper.contains('P2')) {
        final match = RegExp(r'(\d+)\s*CV').firstMatch(line);
        if (match != null) {
          puissanceFiscale = '${match.group(1)} CV';
          AppLogger.d('CarteGriseOcrService: Puissance fiscale trouvée: $puissanceFiscale');
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
      
      // E.1 - Numéro de châssis/VIN
      if (lineUpper.contains('E.1') || lineUpper.contains('E1') || lineUpper.contains('E')) {
        // VIN est généralement 17 caractères alphanumériques
        final vinMatch = RegExp(r'([A-HJ-NPR-Z0-9]{17})').firstMatch(line);
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

    // Si l'immatriculation n'a pas été trouvée via les champs, essayer de la détecter directement
    if (immatriculation == null) {
      final immatMatch = RegExp(r'([A-Z]{2}-\d{3}-[A-Z]{2})').firstMatch(normalizedText);
      if (immatMatch != null) {
        immatriculation = immatMatch.group(1);
        AppLogger.d('CarteGriseOcrService: Immatriculation détectée (regex globale): $immatriculation');
      }
    }

    // Si la marque n'a pas été trouvée, essayer de la deviner
    if (marque == null && modele != null) {
      // Les premières lettres du modèle sont souvent la marque
      final words = modele.split(' ');
      if (words.isNotEmpty) {
        marque = words.first;
        AppLogger.d('CarteGriseOcrService: Marque déduite du modèle: $marque');
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

  /// Normalise le type d'énergie
  String _normalizeEnergie(String energie) {
    final e = energie.toUpperCase().trim();
    if (e.contains('ES')) return 'Essence';
    if (e.contains('GAZ') || e.contains('GPL')) return 'GPL';
    if (e.contains('DIE') || e.contains('GAS')) return 'Diesel';
    if (e.contains('ELEC') || e.contains('ELE')) return 'Électrique';
    if (e.contains('HYB')) return 'Hybride';
    return e;
  }

  /// Libère les ressources
  void dispose() {
    _textRecognizer.close();
    _isInitialized = false;
  }
}