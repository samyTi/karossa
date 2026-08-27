// lib/features/notifications/domain/notification_model.dart

import 'package:flutter/material.dart';

enum NotifType { info, success, warning, error, retard, entretien, gps, demandeWeb }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotifType type;
  final DateTime createdAt;
  final bool isRead;
  final String? routePath;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.routePath,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotifType? type,
    DateTime? createdAt,
    bool? isRead,
    String? routePath,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      routePath: routePath ?? this.routePath,
    );
  }

  Color get color {
    switch (type) {
      case NotifType.success:   return const Color(0xFF10B981);
      case NotifType.warning:   return const Color(0xFFF59E0B);
      case NotifType.error:     return const Color(0xFFEF4444);
      case NotifType.retard:    return const Color(0xFFEF4444);
      case NotifType.entretien: return const Color(0xFFF59E0B);
      case NotifType.gps:       return const Color(0xFF8B5CF6);
      case NotifType.demandeWeb: return const Color(0xFF06B6D4);
      case NotifType.info:      return const Color(0xFF3B82F6);
    }
  }

  IconData get icon {
    switch (type) {
      case NotifType.success:   return Icons.check_circle_outline;
      case NotifType.warning:   return Icons.warning_amber_outlined;
      case NotifType.error:     return Icons.error_outline;
      case NotifType.retard:    return Icons.timer_off_outlined;
      case NotifType.entretien: return Icons.car_repair_outlined;
      case NotifType.gps:       return Icons.gps_fixed_outlined;
      case NotifType.demandeWeb: return Icons.language_outlined;
      case NotifType.info:      return Icons.info_outline;
    }
  }

  String get typeLabel {
    switch (type) {
      case NotifType.success:   return 'Succès';
      case NotifType.warning:   return 'Attention';
      case NotifType.error:     return 'Erreur';
      case NotifType.retard:    return 'Retard';
      case NotifType.entretien: return 'Entretien';
      case NotifType.gps:       return 'GPS';
      case NotifType.demandeWeb: return 'Demande client';
      case NotifType.info:      return 'Info';
    }
  }

  /// Temps écoulé depuis la création (ex: "il y a 2h", "hier", "3 jan.")
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1)  return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24)   return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1)    return 'Hier';
    if (diff.inDays < 7)     return 'Il y a ${diff.inDays}j';

    const mois = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun',
                  'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${createdAt.day} ${mois[createdAt.month - 1]}';
  }
}