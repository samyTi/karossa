// lib/features/contrats/data/contrats_repository.dart

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/contrat_template_model.dart';
import '../../../core/utils/app_logger.dart';

class ContratsRepository {
  ContratsRepository(this._client);

  final SupabaseClient _client;

  // ── Paramètres showroom (table settings) ──────────────────

  Future<Map<String, dynamic>> getShowroomSettings() async {
    try {
      final data = await _client
          .from('showroom_settings')
          .select()
          .single();
      return Map<String, dynamic>.from(data);
    } catch (e) {
    AppLogger.w('Erreur silencieuse ignorée', error: e);
      // Paramètres par défaut si la table est vide
      return {
        'nom':      'Garage Auto',
        'adresse':  '',
        'tel':      '',
        'email':    '',
        'rc':       '',
        'logo_url': null,
      };
    }
  }

  Future<void> updateShowroomSettings(Map<String, dynamic> settings) async {
    try {
      final existing = await _client.from('showroom_settings').select('id');
      if ((existing as List).isNotEmpty) {
        await _client.from('showroom_settings')
            .update(settings)
            .eq('id', existing.first['id']);
      } else {
        await _client.from('showroom_settings').insert(settings);
      }
    } catch (e) {
      AppLogger.d('ContratsRepository.updateShowroomSettings: $e');
    }
  }

  // ── Templates ──────────────────────────────────────────────

  Future<List<ContratTemplate>> getTemplates() async {
    try {
      final data = await _client
          .from('contract_templates')
          .select()
          .eq('is_active', true)
          .order('created_at');
      return (data as List).map((j) => ContratTemplate.fromJson(j)).toList();
    } catch (e) {
      AppLogger.d('ContratsRepository.getTemplates: $e');
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
    AppLogger.w('Erreur silencieuse ignorée', error: e);
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
      AppLogger.d('ContratsRepository.createTemplate: $e');
      return null;
    }
  }

  Future<void> updateTemplate(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('contract_templates').update(data).eq('id', id);
    } catch (e) {
      AppLogger.d('ContratsRepository.updateTemplate: $e');
    }
  }

  // ── Sauvegarde PDF ─────────────────────────────────────────

  Future<String?> savePdfToStorage({
    required String fileName,
    required Uint8List pdfBytes,
    required String folder, // locations | ventes | echanges
  }) async {
    // ✅ FIX : on ne catch plus l'exception — elle remonte à l'appelant
    // pour qu'un message d'erreur soit affiché dans l'UI.
    // Causes fréquentes d'échec : bucket "contrats" absent dans Supabase
    // Storage, ou policy RLS manquante.
    final path = '$folder/$fileName';
    AppLogger.d('ContratsRepository: upload → contrats/$path (${pdfBytes.length} bytes)');
    await _client.storage
        .from('contrats')
        .uploadBinary(path, pdfBytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true));
    final url = _client.storage.from('contrats').getPublicUrl(path);
    AppLogger.d('ContratsRepository: PDF URL = $url');
    return url;
  }

  /// Sauvegarde locale du PDF (pour partage immédiat)
  Future<File?> savePdfLocally(Uint8List bytes, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file   = File('${appDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      AppLogger.d('ContratsRepository.savePdfLocally: $e');
      return null;
    }
  }

  /// Met à jour l'URL du contrat sur une location
  Future<void> linkContratToLocation(String locationId, String pdfUrl) async {
    try {
      await _client.from('locations')
          .update({'contrat_pdf_url': pdfUrl})
          .eq('id', locationId);
    } catch (e) {
      AppLogger.d('ContratsRepository.linkContratToLocation: $e');
    }
  }

  Future<void> linkContratToVente(String venteId, String pdfUrl) async {
    try {
      await _client.from('ventes')
          .update({'contrat_pdf_url': pdfUrl})
          .eq('id', venteId);
    } catch (e) {
      AppLogger.d('ContratsRepository.linkContratToVente: $e');
    }
  }

  // ✅ FIX : méthode manquante — les échanges écrivaient dans la table
  // locations avec un ID d'échange inexistant (mauvaise table).
  Future<void> linkContratToEchange(String echangeId, String pdfUrl) async {
    try {
      await _client.from('echanges')
          .update({'contrat_pdf_url': pdfUrl})
          .eq('id', echangeId);
      AppLogger.d('ContratsRepository: echange $echangeId → contrat_pdf_url mis à jour');
    } catch (e) {
      AppLogger.d('ContratsRepository.linkContratToEchange: $e');
      rethrow;
    }
  }
}
