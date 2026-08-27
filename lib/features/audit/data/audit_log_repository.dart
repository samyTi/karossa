// lib/features/audit/data/audit_log_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/audit_log_model.dart';
import '../../../core/utils/app_logger.dart';

class AuditLogRepository {
  final SupabaseClient _client;

  AuditLogRepository(this._client);

  static const _select = '''
    *,
    profiles(nom, prenom)
  ''';

  /// Journal filtrable par table, par utilisateur et par période.
  /// NB : `audit_log` n'a pas de showroom_id direct — la RLS (voir migration
  /// SQL) restreint déjà la lecture aux gérant/propriétaire/admin, et on
  /// filtre en plus côté table concernée si besoin.
  Future<List<AuditLogEntry>> fetch({
    String? tableName,
    String? userId,
    DateTime? dateDebut,
    DateTime? dateFin,
    int limit = 100,
  }) async {
    try {
      var query = _client.from('audit_log').select(_select);

      if (tableName != null) query = query.eq('table_name', tableName);
      if (userId != null) query = query.eq('user_id', userId);
      if (dateDebut != null) {
        query = query.gte('created_at', dateDebut.toIso8601String());
      }
      if (dateFin != null) {
        query = query.lte('created_at', dateFin.toIso8601String());
      }

      final data = await query.order('created_at', ascending: false).limit(limit);
      return (data as List)
          .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.e('AuditLogRepository.fetch', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Historique complet d'un enregistrement précis (ex: toutes les
  /// modifications d'une même location).
  Future<List<AuditLogEntry>> fetchForRecord(String tableName, String recordId) async {
    try {
      final data = await _client
          .from('audit_log')
          .select(_select)
          .eq('table_name', tableName)
          .eq('record_id', recordId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.e('AuditLogRepository.fetchForRecord', error: e, stackTrace: st);
      rethrow;
    }
  }
}
