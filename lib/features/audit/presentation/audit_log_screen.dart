// lib/features/audit/presentation/audit_log_screen.dart
//
// Journal d'audit — traçabilité des actions financières et contractuelles.
// Réservé aux rôles gérant / propriétaire / admin (voir RLS + router guard).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/modern_app_bar.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/audit_log_model.dart';
import '../../../core/extensions/l10n_extension.dart';
import 'audit_log_provider.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(auditLogListProvider);
    final filter = ref.watch(auditLogFilterProvider);

    return Scaffold(
      appBar: ModernAppBar(title: context.l10n.journalAudit),
      body: Column(
        children: [
          _FilterBar(filter: filter),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(context.l10n.erreurDeChargement(e.toString()), style: AppTextStyles.bodySecondary),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return EmptyState(
                    icon: Icons.history_toggle_off,
                    message: context.l10n.aucuneActiviteEnregistreePourCesFiltres,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _AuditTile(entry: entries[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final AuditLogFilter filter;
  const _FilterBar({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(context, ref, label: 'Tout', selected: filter.tableName == null,
                onTap: () => ref.read(auditLogFilterProvider.notifier).state =
                    filter.copyWith(clearTable: true)),
            ...auditTableLabels.entries.map((e) => _chip(
                  context, ref,
                  label: e.value,
                  selected: filter.tableName == e.key,
                  onTap: () => ref.read(auditLogFilterProvider.notifier).state =
                      filter.copyWith(tableName: e.key),
                )),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, WidgetRef ref,
      {required String label, required bool selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withOpacity(0.15),
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditLogEntry entry;
  const _AuditTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final montant = entry.montant;
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entry.action.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(entry.action.icon, color: entry.action.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${entry.action.label} — ${entry.tableLabel}',
                    style: AppTextStyles.bold(AppTextStyles.body)),
                const SizedBox(height: 2),
                Text(
                  '${entry.userNom?.isNotEmpty == true ? entry.userNom : 'Utilisateur inconnu'} · '
                  '${entry.createdAt.toDisplayDate()} '
                  '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
          if (montant != null)
            Text(montant.toDA(),
                style: AppTextStyles.withColor(
                    AppTextStyles.bold(AppTextStyles.body), AppColors.primary)),
        ],
      ),
    );
  }
}
