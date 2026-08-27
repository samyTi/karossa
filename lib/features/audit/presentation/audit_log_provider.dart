// lib/features/audit/presentation/audit_log_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/audit_log_repository.dart';
import '../domain/audit_log_model.dart';

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepository(ref.watch(supabaseClientProvider));
});

class AuditLogFilter {
  final String? tableName;
  final String? userId;
  final DateTime? dateDebut;
  final DateTime? dateFin;

  const AuditLogFilter({this.tableName, this.userId, this.dateDebut, this.dateFin});

  AuditLogFilter copyWith({
    String? tableName,
    bool clearTable = false,
    String? userId,
    bool clearUser = false,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) =>
      AuditLogFilter(
        tableName: clearTable ? null : (tableName ?? this.tableName),
        userId: clearUser ? null : (userId ?? this.userId),
        dateDebut: dateDebut ?? this.dateDebut,
        dateFin: dateFin ?? this.dateFin,
      );
}

final auditLogFilterProvider =
    StateProvider.autoDispose<AuditLogFilter>((ref) => const AuditLogFilter());

final auditLogListProvider =
    FutureProvider.autoDispose<List<AuditLogEntry>>((ref) {
  final filter = ref.watch(auditLogFilterProvider);
  return ref.watch(auditLogRepositoryProvider).fetch(
        tableName: filter.tableName,
        userId: filter.userId,
        dateDebut: filter.dateDebut,
        dateFin: filter.dateFin,
      );
});

/// Historique d'un enregistrement précis — utile pour un bouton
/// "Voir l'historique des modifications" sur une fiche vente/location/etc.
final auditLogForRecordProvider = FutureProvider.autoDispose
    .family<List<AuditLogEntry>, ({String table, String recordId})>((ref, params) {
  return ref.watch(auditLogRepositoryProvider).fetchForRecord(params.table, params.recordId);
});
