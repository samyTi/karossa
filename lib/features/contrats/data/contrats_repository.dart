// lib/features/contrats/data/contrats_repository.dart

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/contrat_template_model.dart';
import '../domain/contrat_location_champs.dart';
import '../../../core/utils/app_logger.dart';

class ContratsRepository {
  ContratsRepository(this._client, {required this.showroomId});

  final SupabaseClient _client;
  // Nullable : tant que le profil n'est pas chargé, showroomId reste null
  final String? showroomId;

  /// Vérifie que showroomId est valide avant toute requête UUID.
  /// Lance une exception explicite si ce n'est pas le cas.
  String get _safeShowroomId {
    final id = showroomId;
    if (id == null || id.isEmpty) {
      throw StateError(
        'ContratsRepository: showroomId non disponible. '
        'Le profil utilisateur est-il chargé ?',
      );
    }
    return id;
  }

  bool get isReady => showroomId != null && showroomId!.isNotEmpty;

  // ── Paramètres showroom ──────────────────────────────────────────────────
  // Cible la table `showrooms` (schéma réel — pas showroom_settings).

  Future<Map<String, dynamic>> getShowroomSettings() async {
    try {
      final data = await _client
          .from('showrooms')
          .select(
            'nom, adresse, tel, email, rc, logo_url, '
            'commission_vente_type, commission_vente_valeur, '
            'commission_echange_type, commission_echange_valeur, '
            'commission_location_type, commission_location_valeur, '
            'commission_achat_type, commission_achat_valeur, '
            'contrat_location_champs',
          )
          .eq('id', _safeShowroomId)
          .single();
      return Map<String, dynamic>.from(data);
    } catch (e) {
      AppLogger.w('ContratsRepository.getShowroomSettings: utilisation des defaults', error: e);
      return _defaultSettings;
    }
  }

  Future<void> updateShowroomSettings(Map<String, dynamic> settings) async {
    await _client
        .from('showrooms')
        .update(settings)
        .eq('id', _safeShowroomId);
  }

  // ── Champs affichés sur le contrat de location ──────────────────────────
  // Colonne showrooms.contrat_location_champs (jsonb) : { "cle": true/false }.
  // Voir migration SQL fournie séparément si la colonne n'existe pas encore.

  Future<Map<String, bool>> getContratLocationChamps() async {
    try {
      final data = await _client
          .from('showrooms')
          .select('contrat_location_champs')
          .eq('id', _safeShowroomId)
          .single();
      final raw = data['contrat_location_champs'] as Map<String, dynamic>?;
      return ContratLocationChamps.resolve(raw);
    } catch (e) {
      AppLogger.w('ContratsRepository.getContratLocationChamps: defaults utilisés', error: e);
      return ContratLocationChamps.defaults;
    }
  }

  Future<void> updateContratLocationChamps(Map<String, bool> champs) async {
    try {
      await _client
          .from('showrooms')
          .update({'contrat_location_champs': champs})
          .eq('id', _safeShowroomId);
    } catch (e) {
      AppLogger.e('ContratsRepository.updateContratLocationChamps', error: e);
      rethrow;
    }
  }

  // ── Templates ────────────────────────────────────────────────────────────
  // `contract_templates` n'a pas de colonne showroom_id → pas de filtre.

  Future<List<ContratTemplate>> getTemplates() async {
    try {
      final data = await _client
          .from('contract_templates')
          .select()
          .eq('is_active', true)
          .order('created_at');
      return (data as List).map((j) => ContratTemplate.fromJson(j)).toList();
    } catch (e) {
      AppLogger.e('ContratsRepository.getTemplates', error: e);
      return [];
    }
  }

  Future<ContratTemplate?> getActiveTemplate(String type) async {
    try {
      final data = await _client
          .from('contract_templates')
          .select()
          .eq('type', type)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      return ContratTemplate.fromJson(data);
    } catch (e) {
      AppLogger.w('ContratsRepository.getActiveTemplate: aucun template actif pour "$type"', error: e);
      return null;
    }
  }

  Future<ContratTemplate?> createTemplate(ContratTemplate template) async {
    try {
      final data = await _client
          .from('contract_templates')
          .insert(template.toJson())
          .select()
          .single();
      return ContratTemplate.fromJson(data);
    } catch (e) {
      AppLogger.e('ContratsRepository.createTemplate', error: e);
      rethrow;
    }
  }

  Future<void> updateTemplate(String id, Map<String, dynamic> data) async {
    try {
      await _client
          .from('contract_templates')
          .update(data)
          .eq('id', id);
    } catch (e) {
      AppLogger.e('ContratsRepository.updateTemplate', error: e);
      rethrow;
    }
  }

  // ── Sauvegarde PDF ───────────────────────────────────────────────────────

  Future<String> uploadContratPdf(
      String id, String bucketFolder, Uint8List fileBytes) async {
    final url = await savePdfToStorage(
      fileName: '$id.pdf',
      pdfBytes: fileBytes,
      folder: bucketFolder,
    );
    if (url == null) throw Exception('URL Supabase Storage nulle.');
    return url;
  }

  Future<String?> savePdfToStorage({
    required String fileName,
    required Uint8List pdfBytes,
    required String folder,
  }) async {
    try {
      final path = '${_safeShowroomId}/$folder/$fileName';
      await _client.storage.from('contrats').uploadBinary(
            path,
            pdfBytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );
      return _client.storage.from('contrats').getPublicUrl(path);
    } catch (e) {
      AppLogger.e('ContratsRepository.savePdfToStorage', error: e);
      rethrow;
    }
  }

  Future<File?> savePdfLocally(Uint8List bytes, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file   = File('${appDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      AppLogger.e('ContratsRepository.savePdfLocally', error: e);
      return null;
    }
  }

  // ── Liens vers les entités ───────────────────────────────────────────────

  Future<void> linkContratToLocation(String locationId, String pdfUrl) async {
    await _client
        .from('locations')
        .update({'contrat_pdf_url': pdfUrl})
        .eq('showroom_id', _safeShowroomId)
        .eq('id', locationId);
  }

  Future<void> linkContratToVente(String venteId, String pdfUrl) async {
    await _client
        .from('ventes')
        .update({'contrat_pdf_url': pdfUrl})
        .eq('showroom_id', _safeShowroomId)
        .eq('id', venteId);
  }

  Future<void> linkContratToEchange(String echangeId, String pdfUrl) async {
    await _client
        .from('echanges')
        .update({'contrat_pdf_url': pdfUrl})
        .eq('showroom_id', _safeShowroomId)
        .eq('id', echangeId);
  }

  // ── Articles dynamiques ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getArticlesActifs(String contratType) async {
    try {
      final data = await _client
          .from('contract_articles')
          .select()
          .eq('showroom_id', _safeShowroomId)
          .eq('contrat_type', contratType)
          .eq('actif', true)
          .order('ordre');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      AppLogger.e('ContratsRepository.getArticlesActifs', error: e);
      return [];
    }
  }

  // ── Defaults ─────────────────────────────────────────────────────────────

  static const _defaultSettings = <String, dynamic>{
    'nom':                         'Garage Auto',
    'adresse':                     '',
    'tel':                         '',
    'email':                       '',
    'rc':                          '',
    'logo_url':                    null,
    'commission_vente_type':       'pct',
    'commission_vente_valeur':     5,
    'commission_echange_type':     'pct',
    'commission_echange_valeur':   5,
    'commission_location_type':    'pct',
    'commission_location_valeur':  10,
    'commission_achat_type':       'pct',
    'commission_achat_valeur':     5,
  };
}