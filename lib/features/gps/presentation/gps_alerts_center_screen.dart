// lib/features/gps/presentation/gps_alerts_center_screen.dart
//
// ★ NOUVEAU — Centre d'alertes unifié
//   • GPS alerts + Entretien dans un seul flux
//   • Tabs : Toutes / GPS / Entretien / Non lues
//   • Badge total non lues
//   • Actions rapides : Marquer lu · Voir véhicule · Créer réparation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import 'gps_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class GpsAlertsCenterScreen extends ConsumerStatefulWidget {
  const GpsAlertsCenterScreen({super.key});

  @override
  ConsumerState<GpsAlertsCenterScreen> createState() => _GpsAlertsCenterScreenState();
}

class _GpsAlertsCenterScreenState extends ConsumerState<GpsAlertsCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final alertsAsync  = ref.watch(unifiedAlertsProvider);
    final unreadCount  = ref.watch(unreadUnifiedCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(context.l10n.centreAlertes),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:        AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              icon:    const Icon(Icons.done_all, size: 18),
              label:   Text(context.l10n.toutLu),
              onPressed: _markAllRead,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Toutes'),
            Tab(text: 'GPS'),
            Tab(text: 'Entretien'),
            Tab(text: 'Non lues'),
          ],
        ),
      ),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 8),
              Text(context.l10n.erreurAvecDetail(e.toString()), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(unifiedAlertsProvider),
                child: Text(context.l10n.reessayer),
              ),
            ],
          ),
        ),
        data: (allAlerts) {
          final gpsAlerts      = allAlerts.where((a) => a.type == 'gps').toList();
          final entretienAlerts = allAlerts.where((a) => a.type == 'entretien').toList();
          final unreadAlerts   = allAlerts.where((a) => !a.isRead).toList();

          return TabBarView(
            controller: _tabs,
            children: [
              _AlertList(alerts: allAlerts,        onAction: _handleAction, onRefresh: _refresh),
              _AlertList(alerts: gpsAlerts,        onAction: _handleAction, onRefresh: _refresh),
              _AlertList(alerts: entretienAlerts,  onAction: _handleAction, onRefresh: _refresh),
              _AlertList(alerts: unreadAlerts,     onAction: _handleAction, onRefresh: _refresh),
            ],
          );
        },
      ),
    );
  }

  void _handleAction(_AlertAction action, UnifiedAlert alert) {
    switch (action) {
      case _AlertAction.markRead:
        _markRead(alert);
      case _AlertAction.viewVehicle:
        if (alert.vehiculeId.isNotEmpty) context.push('/vehicules/${alert.vehiculeId}');
      case _AlertAction.createRepair:
        if (alert.vehiculeId.isNotEmpty) context.push('/vehicules/${alert.vehiculeId}/reparations/new');
    }
  }

  Future<void> _markRead(UnifiedAlert alert) async {
    try {
      if (alert.type == 'gps') {
        await ref.read(gpsAlerteSourceProvider).marquerAlerteLue(alert.id);
      }
      // Pour entretien : marquer comme ignorée
      _refresh();
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final alerts = ref.read(unifiedAlertsProvider).valueOrNull ?? [];
    final unread = alerts.where((a) => !a.isRead && a.type == 'gps');
    for (final a in unread) {
      await ref.read(gpsAlerteSourceProvider).marquerAlerteLue(a.id).catchError((_) {});
    }
    _refresh();
  }

  void _refresh() {
    ref.invalidate(unifiedAlertsProvider);
    ref.invalidate(toutesAlertesProvider);
    ref.invalidate(alertesNonLuesProvider);
    ref.invalidate(nombreAlertesNonLuesProvider);
  }
}

// ══════════════════════════════════════════════════════════════
// Liste d'alertes
// ══════════════════════════════════════════════════════════════

enum _AlertAction { markRead, viewVehicle, createRepair }

class _AlertList extends StatelessWidget {
  final List<UnifiedAlert>                       alerts;
  final void Function(_AlertAction, UnifiedAlert) onAction;
  final VoidCallback                             onRefresh;

  const _AlertList({
    required this.alerts,
    required this.onAction,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.secondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(context.l10n.aucuneAlerteIci, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding:         const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount:       alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _AlertCard(
          alert:    alerts[i],
          onAction: (action) => onAction(action, alerts[i]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Carte d'alerte avec actions
// ══════════════════════════════════════════════════════════════

class _AlertCard extends StatelessWidget {
  final UnifiedAlert alert;
  final void Function(_AlertAction) onAction;

  const _AlertCard({required this.alert, required this.onAction});

  (IconData, Color) get _iconColor {
    if (alert.type == 'gps') {
      return switch (alert.subType) {
        'vitesse'     => (Icons.speed_rounded,        AppColors.retard),
        'zone'        => (Icons.fence_rounded,         AppColors.accent),
        'kilometrage' => (Icons.timeline_rounded,      AppColors.primary),
        _             => (Icons.gps_fixed,             AppColors.textSecondary),
      };
    }
    // Entretien
    return switch (alert.subType) {
      'vidange'           => (Icons.oil_barrel_rounded,       AppColors.accent),
      'controle_technique'=> (Icons.verified_rounded,          AppColors.primary),
      'assurance'         => (Icons.security_rounded,          AppColors.loue),
      'vignette'          => (Icons.confirmation_num_rounded,  AppColors.reserve),
      'pneus'             => (Icons.tire_repair_rounded,       AppColors.secondary),
      _                   => (Icons.build_rounded,             AppColors.textSecondary),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconColor;
    final isUnread      = !alert.isRead;

    return Dismissible(
      key:       ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding:   const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color:        AppColors.secondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.done_all, color: AppColors.secondary),
            const SizedBox(height: 4),
            Text(context.l10n.lu, style: const TextStyle(color: AppColors.secondary, fontSize: 11)),
          ],
        ),
      ),
      onDismissed: (_) => onAction(_AlertAction.markRead),
      child: Container(
        decoration: BoxDecoration(
          color:        isUnread
              ? color.withValues(alpha: 0.05)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread ? color.withValues(alpha: 0.2) : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              leading: Stack(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color:        color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (isUnread)
                    Positioned(
                      top: 0, right: 0,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color:  color,
                          shape:  BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      alert.vehiculeNom,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color:        color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      alert.type == 'gps' ? 'GPS' : 'Entretien',
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.message, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(alert.date),
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              isThreeLine: true,
            ),
            // Actions rapides
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  if (isUnread)
                    _QuickAction(
                      icon:  Icons.done,
                      label: 'Marquer lu',
                      color: AppColors.secondary,
                      onTap: () => onAction(_AlertAction.markRead),
                    ),
                  if (alert.vehiculeId.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _QuickAction(
                      icon:  Icons.directions_car,
                      label: 'Voir véhicule',
                      color: AppColors.primary,
                      onTap: () => onAction(_AlertAction.viewVehicle),
                    ),
                  ],
                  if (alert.type == 'entretien') ...[
                    const SizedBox(width: 8),
                    _QuickAction(
                      icon:  Icons.build_rounded,
                      label: 'Créer réparation',
                      color: AppColors.accent,
                      onTap: () => onAction(_AlertAction.createRepair),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'À l\'instant';
    if (diff.inHours   < 1)  return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours   < 24) return 'Il y a ${diff.inHours}h';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
  }
}

class _QuickAction extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color:        color.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}