// lib/features/notifications/presentation/notifications_provider.dart



import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';


import '../../../core/theme/app_colors.dart';



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



  IconData get icon {

    switch (type) {

      case NotifType.retard:      return Icons.access_time;

      case NotifType.entretien:   return Icons.build_outlined;

      case NotifType.gps:         return Icons.gps_fixed;

      case NotifType.paiement:    return Icons.payment;

      case NotifType.info:        return Icons.info_outline;

    }

  }



  Color get color {

    switch (type) {

      case NotifType.retard:    return AppColors.retard;

      case NotifType.entretien: return AppColors.accent;

      case NotifType.gps:       return AppColors.primary;

      case NotifType.paiement:  return AppColors.secondary;

      case NotifType.info:      return AppColors.textSecondary;

    }

  }



  String get timeAgo {

    final diff = DateTime.now().difference(createdAt);

    if (diff.inMinutes < 60) return 'il y a \${diff.inMinutes}min';

    if (diff.inHours < 24)   return 'il y a \${diff.inHours}h';

    return 'il y a \${diff.inDays}j';

  }



  AppNotification copyWith({bool? isRead}) => AppNotification(

    id: id, title: title, message: message, type: type,

    createdAt: createdAt, isRead: isRead ?? this.isRead,

    routePath: routePath,

  );

}



enum NotifType { retard, entretien, gps, paiement, info }



// ── Provider liste de toutes les notifications ──────────────────

final allNotificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {

  final notifs = <AppNotification>[];



  // Locations en retard

  final retards = await ref.watch(supabaseClientProvider)

    .from('locations')

    .select('id, vehicules(marque, modele), date_fin_prevue')

    .eq('statut', 'en_cours')

    .lt('date_fin_prevue', DateTime.now().toIso8601String().substring(0, 10));



  for (final r in retards) {

    notifs.add(AppNotification(

      id: "retard_${r['id']}",

      title: 'Retard de retour',

      message: "${r['vehicules']?['marque']} ${r['vehicules']?['modele']} — retour dépassé",

      type: NotifType.retard,

      createdAt: DateTime.now(),

      routePath: '/locations',

    ));

  }



  // Alertes entretien urgentes

  final alertes = await ref.watch(supabaseClientProvider)

    .from('alertes_entretien')

    .select('id, type_alerte, date_echeance, vehicules(marque, modele)')

    .eq('statut', 'active')

    .lte('date_echeance',

      DateTime.now().add(const Duration(days: 7)).toIso8601String().substring(0, 10));



  for (final a in alertes) {

    notifs.add(AppNotification(

      id: "entretien_${a['id']}",

      title: 'Alerte entretien',

      message: "${a['vehicules']?['marque']} ${a['vehicules']?['modele']} — ${a['type_alerte']}",

      type: NotifType.entretien,

      createdAt: DateTime.now(),

      routePath: '/entretien',

    ));

  }



  // Alertes GPS non lues

  final gpsAlertes = await ref.watch(supabaseClientProvider)

    .from('gps_alertes')

    .select('id, message, date_alerte, vehicule_nom')

    .eq('lue', false)

    .order('date_alerte', ascending: false)

    .limit(5);



  for (final g in gpsAlertes) {

    notifs.add(AppNotification(

      id: "gps_${g['id']}",

      title: "Alerte GPS — ${g['vehicule_nom'] ?? ''}",

      message: g['message'] ?? '',

      type: NotifType.gps,

      createdAt: g['date_alerte'] != null

        ? DateTime.parse(g['date_alerte']) : DateTime.now(),

      routePath: '/gps/alertes',

    ));

  }



  notifs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return notifs;

});



// Badge count

final notificationBadgeCountProvider = FutureProvider.autoDispose<int>((ref) async {

  final notifs = await ref.watch(allNotificationsProvider.future);

  return notifs.where((n) => !n.isRead).length;

});



// Service

final notificationsServiceProvider = Provider((ref) => NotificationsService(ref));



class NotificationsService {

  final Ref _ref;

  NotificationsService(this._ref);



  void markAllRead() {

    _ref.invalidate(allNotificationsProvider);

  }



  void dismiss(String id) {

    // Marquer alerte GPS comme lue si préfixe 'gps_'

    if (id.startsWith('gps_')) {

      final gpsId = id.replaceFirst('gps_', '');

      _ref.watch(supabaseClientProvider).from('gps_alertes').update({'lue': true}).eq('id', gpsId);

    }

    _ref.invalidate(allNotificationsProvider);

  }

}

