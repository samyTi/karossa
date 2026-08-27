// lib/features/audit/domain/audit_log_model.dart
//
// Traçabilité des actions sensibles (caisse, ventes, locations, échanges,
// répartitions propriétaires, versements, transferts).
// Alimenté automatiquement par le trigger SQL `fn_audit_log` — voir
// migration_2026_07_wow_features.sql. Rien à écrire manuellement côté app.

import 'package:flutter/material.dart';

enum AuditAction { insert, update, delete }

extension AuditActionX on AuditAction {
  static AuditAction fromRaw(String raw) {
    switch (raw.toUpperCase()) {
      case 'INSERT':
        return AuditAction.insert;
      case 'DELETE':
        return AuditAction.delete;
      default:
        return AuditAction.update;
    }
  }

  String get label {
    switch (this) {
      case AuditAction.insert:
        return 'Création';
      case AuditAction.update:
        return 'Modification';
      case AuditAction.delete:
        return 'Suppression';
    }
  }

  IconData get icon {
    switch (this) {
      case AuditAction.insert:
        return Icons.add_circle_outline;
      case AuditAction.update:
        return Icons.edit_outlined;
      case AuditAction.delete:
        return Icons.delete_outline;
    }
  }

  Color get color {
    switch (this) {
      case AuditAction.insert:
        return const Color(0xFF10B981);
      case AuditAction.update:
        return const Color(0xFF3B82F6);
      case AuditAction.delete:
        return const Color(0xFFEF4444);
    }
  }
}

/// Libellés lisibles pour les noms techniques de table.
const Map<String, String> auditTableLabels = {
  'caisse_operations': 'Caisse',
  'ventes': 'Vente',
  'locations': 'Location',
  'echanges': 'Échange',
  'vehicule_proprietes': 'Répartition véhicule',
  'versements_proprietaires': 'Versement propriétaire',
  'transferts_utilisateurs': 'Transfert interne',
};

class AuditLogEntry {
  final String id;
  final String? userId;
  final String? userNom;
  final AuditAction action;
  final String tableName;
  final String? recordId;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    this.userId,
    this.userNom,
    required this.action,
    required this.tableName,
    this.recordId,
    this.details,
    required this.createdAt,
  });

  String get tableLabel => auditTableLabels[tableName] ?? tableName;

  /// Tente d'extraire un montant (avant/après) pour affichage rapide.
  double? get montant {
    final apres = details?['apres'] as Map<String, dynamic>?;
    final avant = details?['avant'] as Map<String, dynamic>?;
    final m = (apres?['montant'] ?? apres?['prix_vente'] ?? apres?['montant_brut']) ??
        (avant?['montant'] ?? avant?['prix_vente'] ?? avant?['montant_brut']);
    if (m == null) return null;
    return (m as num).toDouble();
  }

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        userNom: json['profiles'] != null
            ? '${json['profiles']['prenom'] ?? ''} ${json['profiles']['nom'] ?? ''}'.trim()
            : null,
        action: AuditActionX.fromRaw(json['action'] as String? ?? 'UPDATE'),
        tableName: json['table_name'] as String? ?? '',
        recordId: json['record_id'] as String?,
        details: json['details'] as Map<String, dynamic>?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}
