// lib/features/notifications/presentation/notifications_screen.dart
// Centre de notifications : alertes entretien + retards + GPS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(allNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationsServiceProvider).markAllRead(),
            child: const Text('Tout lire',
              style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: notifs.when(
        loading: () => const Center(child: const CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : \$e')),
        data: (list) => list.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                    size: 64, color: AppColors.textHint),
                  const SizedBox(height: 12),
                  Text('Aucune notification',
                    style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) => _NotifCard(notif: list[i], ref: ref),
            ),
      ),
    );
  }
}

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
        color: AppColors.retard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    ),
    onDismissed: (_) =>
      ref.read(notificationsServiceProvider).dismiss(notif.id),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notif.isRead ? Colors.white : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notif.isRead ? AppColors.border
            : AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: notif.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(notif.icon, color: notif.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notif.title,
              style: TextStyle(
                fontWeight: notif.isRead
                  ? FontWeight.normal : FontWeight.bold,
                fontSize: 13)),
            const SizedBox(height: 2),
            Text(notif.message,
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(notif.timeAgo,
              style: const TextStyle(
                fontSize: 10, color: AppColors.textHint)),
          ],
        )),
        if (!notif.isRead)
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(left: 8),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
      ]),
    ),
  );
}
