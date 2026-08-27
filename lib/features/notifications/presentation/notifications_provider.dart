// lib/features/notifications/presentation/notifications_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/notification_model.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/realtime_service.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../core/providers/locale_provider.dart';
import 'package:garage_auto/l10n/app_localizations.dart';

// ── Agrégateur principal ─────────────────────────────────────────────────────
// Les notifications sont calculées à la volée depuis les tables existantes :
//   • locations          → retards de retour
//   • alertes_entretien  → échéances dans les 7 prochains jours
//   • gps_alertes        → alertes GPS non lues
//   • reservations_web / demandes_devis / propositions_vente (en_attente)
//     → nouvelles demandes envoyées depuis la plateforme client
// Aucune table dédiée n'est nécessaire.

// ── Live (Realtime) ──────────────────────────────────────────────────────────
// Watché une seule fois (ex: dans le shell principal / dashboard) pour que
// les notifications se rafraîchissent automatiquement dès qu'un événement
// arrive côté base, sans que l'utilisateur ait à tirer pour rafraîchir.
final notificationsRealtimeProvider = Provider.autoDispose<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null) return;

  final group = RealtimeSubscriptionGroup();
  void refresh() => ref.invalidate(allNotificationsProvider);

  for (final table in [
    'gps_alertes',
    'locations',
    'reservations_web',
    'demandes_devis',
    'propositions_vente',
    'ai_alertes',
  ]) {
    group.add(RealtimeSubscription(
      client: client,
      table: table,
      showroomId: showroomId,
      onChange: refresh,
    ));
  }

  ref.onDispose(group.dispose);
});

final allNotificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) return [];

  final client = ref.watch(supabaseClientProvider);
  final l10n = lookupAppLocalizations(ref.watch(localeProvider));
  final notifs = <AppNotification>[];

  // ── 1. Locations en retard ─────────────────────────────────────────────────
  try {
    final retards = await client
        .from('locations')
        .select('id, vehicules(marque, modele), date_fin_prevue, client_id')
        .eq('statut', 'en_cours')
        .eq('showroom_id', showroomId)
        .lt('date_fin_prevue',
            DateTime.now().toIso8601String().substring(0, 10));

    for (final r in retards) {
      final marque = r['vehicules']?['marque'] ?? '';
      final modele = r['vehicules']?['modele'] ?? '';
      final datePrevue = r['date_fin_prevue'] as String? ?? '';
      final jours = DateTime.now()
          .difference(DateTime.tryParse(datePrevue) ?? DateTime.now())
          .inDays;
      notifs.add(AppNotification(
        id: 'retard_${r['id']}',
        title: l10n.retardDeRetour,
        message:
            '$marque $modele — dépassé de ${jours > 0 ? '$jours jour${jours > 1 ? 's' : ''}' : 'aujourd\'hui'}',
        type: NotifType.retard,
        createdAt: DateTime.tryParse(datePrevue) ?? DateTime.now(),
        routePath: '/locations',
      ));
    }
  } catch (_) {}

  // ── 2. Alertes entretien (échéance ≤ 7 jours) ─────────────────────────────
  try {
    final alertes = await client
        .from('alertes_entretien')
        .select('id, type_alerte, date_echeance, vehicules(marque, modele)')
        .eq('statut', 'active')
        .eq('showroom_id', showroomId)
        .lte(
          'date_echeance',
          DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String()
              .substring(0, 10),
        );

    for (final a in alertes) {
      final marque = a['vehicules']?['marque'] ?? '';
      final modele = a['vehicules']?['modele'] ?? '';
      final typeAlerte = _labelTypeAlerte(a['type_alerte'] as String? ?? '');
      final dateEch = DateTime.tryParse(a['date_echeance'] ?? '') ?? DateTime.now();
      final estDepasse = dateEch.isBefore(DateTime.now());

      notifs.add(AppNotification(
        id: 'entretien_${a['id']}',
        title: estDepasse ? 'Entretien dépassé' : 'Entretien à venir',
        message: l10n.msgMarqueModeleTypeAlerte(marque, modele, typeAlerte),
        type: NotifType.entretien,
        createdAt: dateEch,
        routePath: '/entretien',
      ));
    }
  } catch (_) {}

  // ── 3. Alertes GPS non lues ────────────────────────────────────────────────
  try {
    final gpsAlertes = await client
        .from('gps_alertes')
        .select('id, message, date_alerte, vehicule_nom, vehicule_id')
        .eq('lue', false)
        .order('date_alerte', ascending: false)
        .limit(10);

    for (final g in gpsAlertes) {
      notifs.add(AppNotification(
        id: 'gps_${g['id']}',
        title: l10n.alerteGpsVehicule(g['vehicule_nom'] ?? l10n.vehiculeInconnu),
        message: g['message'] ?? '',
        type: NotifType.gps,
        createdAt: g['date_alerte'] != null
            ? DateTime.parse(g['date_alerte'])
            : DateTime.now(),
        routePath: '/gps/alertes',
      ));
    }
  } catch (_) {}

  // ── 4. Nouvelles demandes de la plateforme web (en attente) ───────────────
  try {
    final reservations = await client
        .from('reservations_web')
        .select('id, created_at, vehicule_id, vehicules(marque, modele), date_debut, date_fin')
        .eq('statut', 'en_attente')
        .eq('showroom_id', showroomId)
        .order('created_at', ascending: false)
        .limit(10);

    for (final r in reservations) {
      final marque = r['vehicules']?['marque'] ?? '';
      final modele = r['vehicules']?['modele'] ?? '';
      notifs.add(AppNotification(
        id: 'resa_${r['id']}',
        title: l10n.nouvelleReservationWeb,
        message: l10n.msgReservationWeb(marque, modele, r['date_debut'] ?? '?', r['date_fin'] ?? '?'),
        type: NotifType.demandeWeb,
        createdAt: r['created_at'] != null
            ? DateTime.parse(r['created_at'])
            : DateTime.now(),
        routePath: '/more/web-demandes',
      ));
    }
  } catch (_) {}

  try {
    final devis = await client
        .from('demandes_devis')
        .select('id, created_at, type, vehicules(marque, modele)')
        .eq('statut', 'en_attente')
        .eq('showroom_id', showroomId)
        .order('created_at', ascending: false)
        .limit(10);

    for (final d in devis) {
      final marque = d['vehicules']?['marque'] ?? '';
      final modele = d['vehicules']?['modele'] ?? '';
      notifs.add(AppNotification(
        id: 'devis_${d['id']}',
        title: l10n.nouvelleDemandeDevis,
        message: [marque, modele].where((s) => (s as String).isNotEmpty).join(' '),
        type: NotifType.demandeWeb,
        createdAt: d['created_at'] != null
            ? DateTime.parse(d['created_at'])
            : DateTime.now(),
        routePath: '/more/web-demandes',
      ));
    }
  } catch (_) {}

  try {
    final propositions = await client
        .from('propositions_vente')
        .select('id, created_at, marque, modele')
        .eq('statut', 'en_attente')
        .eq('showroom_id', showroomId)
        .order('created_at', ascending: false)
        .limit(10);

    for (final p in propositions) {
      notifs.add(AppNotification(
        id: 'prop_${p['id']}',
        title: l10n.propositionRepriseClient,
        message: '${p['marque'] ?? ''} ${p['modele'] ?? ''}',
        type: NotifType.demandeWeb,
        createdAt: p['created_at'] != null
            ? DateTime.parse(p['created_at'])
            : DateTime.now(),
        routePath: '/more/web-demandes',
      ));
    }
  } catch (_) {}

  // Tri chronologique décroissant
  notifs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return notifs;
});

// ── Badge count (non lus) ────────────────────────────────────────────────────
final notificationBadgeCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final notifs = await ref.watch(allNotificationsProvider.future);
  return notifs.where((n) => !n.isRead).length;
});

// ── Filtre par type ──────────────────────────────────────────────────────────
final notifTypeFiltreProvider =
    StateProvider.autoDispose<NotifType?>((ref) => null);

final notifsFiltreesProvider =
    Provider.autoDispose<AsyncValue<List<AppNotification>>>((ref) {
  final filtre = ref.watch(notifTypeFiltreProvider);
  return ref.watch(allNotificationsProvider).whenData((list) {
    if (filtre == null) return list;
    return list.where((n) => n.type == filtre).toList();
  });
});

// ── Service (actions) ────────────────────────────────────────────────────────
final notificationsServiceProvider =
    Provider((ref) => NotificationsService(ref));

class NotificationsService {
  final Ref _ref;
  NotificationsService(this._ref);

  /// Marque une alerte GPS comme lue en base, puis invalide le cache.
  Future<void> dismiss(String id) async {
    if (id.startsWith('gps_')) {
      final gpsId = id.replaceFirst('gps_', '');
      try {
        await _ref
            .read(supabaseClientProvider)
            .from('gps_alertes')
            .update({'lue': true}).eq('id', gpsId);
      } catch (_) {}
    }
    _ref.invalidate(allNotificationsProvider);
  }

  /// Marque toutes les alertes GPS comme lues, puis recharge.
  Future<void> markAllGpsRead() async {
    try {
      await _ref
          .read(supabaseClientProvider)
          .from('gps_alertes')
          .update({'lue': true}).eq('lue', false);
    } catch (_) {}
    _ref.invalidate(allNotificationsProvider);
  }

  /// Rafraîchit toutes les notifications.
  void refresh() => _ref.invalidate(allNotificationsProvider);
}

// ── Helpers privés ───────────────────────────────────────────────────────────
String _labelTypeAlerte(String raw) {
  const map = {
    'vidange':            'Vidange',
    'controle_technique': 'Contrôle technique',
    'assurance':          'Assurance',
    'vignette':           'Vignette',
    'pneus':              'Pneus',
    'autre':              'Entretien',
  };
  return map[raw] ?? raw;
}