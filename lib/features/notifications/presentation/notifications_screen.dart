// lib/features/notifications/presentation/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/notification_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'notifications_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notifsFiltreesProvider);
    final filtre = ref.watch(notifTypeFiltreProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.l10n.notifications),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: context.l10n.actualiser,
            onPressed: () => ref.read(notificationsServiceProvider).refresh(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              if (val == 'clear_gps') {
                await ref.read(notificationsServiceProvider).markAllGpsRead();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'clear_gps',
                child: Row(children: [
                  Icon(Icons.gps_off_outlined, size: 18),
                  SizedBox(width: 8),
                  Text(context.l10n.marquerGpsCommeLues),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Chips de filtre ──────────────────────────────────────────────
          _FilterChips(filtre: filtre, ref: ref),

          // ── Liste ────────────────────────────────────────────────────────
          Expanded(
            child: notifsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 48, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    Text(context.l10n.impossibleDeChargerLesNotifications, style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.read(notificationsServiceProvider).refresh(),
                      child: Text(context.l10n.reessayer),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? _EmptyState(filtre: filtre)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, i) => _NotifCard(
                        notif: list[i],
                        ref: ref,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chips de filtre ──────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final NotifType? filtre;
  final WidgetRef ref;
  const _FilterChips({required this.filtre, required this.ref});

  @override
  Widget build(BuildContext context) {
    final filtres = [
      (null,                'Toutes',   Icons.notifications_outlined),
      (NotifType.retard,    'Retards',  Icons.timer_off_outlined),
      (NotifType.entretien, 'Entretien', Icons.car_repair_outlined),
      (NotifType.gps,       'GPS',      Icons.gps_fixed_outlined),
    ];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filtres.map((f) {
            final (type, label, icon) = f;
            final selected = filtre == type;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selected,
                label: Row(children: [
                  Icon(icon, size: 14,
                    color: selected ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(label),
                ]),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: AppColors.inputFill,
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
                showCheckmark: false,
                onSelected: (_) => ref
                    .read(notifTypeFiltreProvider.notifier)
                    .state = type,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Carte notification ───────────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final WidgetRef ref;
  const _NotifCard({required this.notif, required this.ref});

  @override
  Widget build(BuildContext context) => Dismissible(
        key: Key(notif.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) =>
            ref.read(notificationsServiceProvider).dismiss(notif.id),
        child: InkWell(
          onTap: notif.routePath != null
              ? () => context.push(notif.routePath!)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: notif.isRead
                  ? AppColors.surface
                  : AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: notif.isRead
                    ? AppColors.border
                    : notif.color.withValues(alpha: 0.3),
                width: notif.isRead ? 0.5 : 1,
              ),
            ),
            child: Row(children: [
              // Icône colorée
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: notif.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(notif.icon, color: notif.color, size: 20),
              ),
              const SizedBox(width: 12),

              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Badge type
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: notif.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          notif.typeLabel,
                          style: TextStyle(
                              fontSize: 9,
                              color: notif.color,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      notif.message,
                      style: AppTextStyles.bodySecondary
                          .copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.timeAgo,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),

              // Point non lu
              if (!notif.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: notif.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ]),
          ),
        ),
      );
}

// ── État vide ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final NotifType? filtre;
  const _EmptyState({this.filtre});

  @override
  Widget build(BuildContext context) {
    final label = filtre == null ? 'notification' : filtre!.name;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_none,
              size: 64, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            'Aucune $label',
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(context.l10n.toutEstEnOrdre, style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}