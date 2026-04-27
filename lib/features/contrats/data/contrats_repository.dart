// lib/features/contrats/data/contrats_repository.dart

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../main.dart';
import '../domain/contrat_template_model.dart';

class ContratsRepository {
  static final ContratsRepository _i = ContratsRepository._internal();
  factory ContratsRepository() => _i;
  ContratsRepository._internal();

  // ── Paramètres showroom (table settings) ──────────────────

  Future<Map<String, dynamic>> getShowroomSettings() async {
    try {
      final data = await supabase
          .from('showroom_settings')
          .select()
          .single();
      return Map<String, dynamic>.from(data);
    } catch (_) {
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
      final existing = await supabase.from('showroom_settings').select('id');
      if ((existing as List).isNotEmpty) {
        await supabase.from('showroom_settings')
            .update(settings)
            .eq('id', existing.first['id']);
      } else {
        await supabase.from('showroom_settings').insert(settings);
      }
    } catch (e) {
      debugPrint('ContratsRepository.updateShowroomSettings: $e');
    }
  }

  // ── Templates ──────────────────────────────────────────────

  Future<List<ContratTemplate>> getTemplates() async {
    try {
      final data = await supabase
          .from('contract_templates')
          .select()
          .eq('is_active', true)
          .order('created_at');
      return (data as List).map((j) => ContratTemplate.fromJson(j)).toList();
    } catch (e) {
      debugPrint('ContratsRepository.getTemplates: $e');
      return [];
    }
  }

  Future<ContratTemplate?> getActiveTemplate(String type) async {
    try {
      final data = await supabase
          .from('contract_templates')
          .select()
          .eq('type', type)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      return ContratTemplate.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<ContratTemplate?> createTemplate(ContratTemplate template) async {
    try {
      final data = await supabase
          .from('contract_templates')
          .insert(template.toJson())
          .select()
          .single();
      return ContratTemplate.fromJson(data);
    } catch (e) {
      debugPrint('ContratsRepository.createTemplate: $e');
      return null;
    }
  }

  Future<void> updateTemplate(String id, Map<String, dynamic> data) async {
    try {
      await supabase.from('contract_templates').update(data).eq('id', id);
    } catch (e) {
      debugPrint('ContratsRepository.updateTemplate: $e');
    }
  }

  // ── Sauvegarde PDF ─────────────────────────────────────────

  Future<String?> savePdfToStorage({
    required String fileName,
    required Uint8List pdfBytes,
    required String folder, // locations | ventes | echanges
  }) async {
    try {
      final path = '$folder/$fileName';
      await supabase.storage
          .from('contrats')
          .uploadBinary(path, pdfBytes,
              fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true));
      final url = supabase.storage.from('contrats').getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('ContratsRepository.savePdfToStorage: $e');
      return null;
    }
  }

  /// Sauvegarde locale du PDF (pour partage immédiat)
  Future<File?> savePdfLocally(Uint8List bytes, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file   = File('${appDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('ContratsRepository.savePdfLocally: $e');
      return null;
    }
  }

  /// Met à jour l'URL du contrat sur une location
  Future<void> linkContratToLocation(String locationId, String pdfUrl) async {
    try {
      await supabase.from('locations')
          .update({'contrat_pdf_url': pdfUrl})
          .eq('id', locationId);
    } catch (e) {
      debugPrint('ContratsRepository.linkContratToLocation: $e');
    }
  }

  Future<void> linkContratToVente(String venteId, String pdfUrl) async {
    try {
      await supabase.from('ventes')
          .update({'contrat_pdf_url': pdfUrl})
          .eq('id', venteId);
    } catch (e) {
      debugPrint('ContratsRepository.linkContratToVente: $e');
    }
  }
}
