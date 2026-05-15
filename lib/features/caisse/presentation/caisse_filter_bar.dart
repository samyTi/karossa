import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../data/caisse_operation.dart';
import '../domain/caisse_providers.dart';

class CaisseFilterBar extends ConsumerWidget {
  const CaisseFilterBar({super.key});

  static const _moisLabels = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
    'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(caisseFilterProvider);
    final notifier = ref.read(caisseFilterProvider.notifier);

    return Column(
      children: [
        // ── Ligne 1 : Période rapide (mois) + plage personnalisée
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Bouton "Tout"
              _PillChip(
                label: 'Tout',
                selected: !filter.hasActiveFilter &&
                    filter.mois == null &&
                    filter.annee == null,
                onTap: notifier.reset,
              ),
              const SizedBox(width: 6),
              // Sélecteur mois courant / précédent
              ..._buildMoisChips(filter, notifier, context),
              const SizedBox(width: 6),
              // Plage personnalisée
              _PillChip(
                label: filter.dateDebut != null
                    ? '${_fmt(filter.dateDebut!)} → ${filter.dateFin != null ? _fmt(filter.dateFin!) : '...'}'
                    : 'Plage dates',
                icon: Icons.date_range_outlined,
                selected: filter.dateDebut != null,
                onTap: () => _pickRange(context, ref, filter, notifier),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Ligne 2 : Type + Catégorie
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: filter.type == null
                    ? 'Type'
                    : filter.type == 'entree'
                        ? '↓ Entrée'
                        : '↑ Sortie',
                active: filter.type != null,
                onTap: () => _pickType(context, ref, filter, notifier),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                // ✅ Fix : categorieLabels (public) au lieu de _categorieLabels (privé)
                label: filter.categorie == null
                    ? 'Catégorie'
                    : CaisseOperation.categorieLabels[filter.categorie] ??
                        filter.categorie!,
                active: filter.categorie != null,
                onTap: () => _pickCategorie(context, ref, filter, notifier),
              ),
              if (filter.hasActiveFilter ||
                  filter.mois != DateTime.now().month) ...[
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Réinitialiser',
                  icon: Icons.close,
                  active: false,
                  danger: true,
                  onTap: notifier.reset,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _buildMoisChips(
    CaisseFilter filter,
    CaisseFilterNotifier notifier,
    BuildContext context,
  ) {
    final now = DateTime.now();
    final chips = <Widget>[];
    // 3 derniers mois
    for (var i = 0; i < 3; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final selected = filter.mois == d.month && filter.annee == d.year;
      chips.add(_PillChip(
        label: '${_moisLabels[d.month - 1]} ${d.year != now.year ? d.year : ''}',
        selected: selected,
        onTap: () => notifier.setMois(d.month, d.year),
      ));
      chips.add(const SizedBox(width: 6));
    }
    return chips;
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    CaisseFilter filter,
    CaisseFilterNotifier notifier,
  ) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: filter.dateDebut != null && filter.dateFin != null
          ? DateTimeRange(start: filter.dateDebut!, end: filter.dateFin!)
          : null,
      locale: const Locale('fr'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      notifier.setDateDebut(range.start);
      notifier.setDateFin(range.end);
    }
  }

  void _pickType(
    BuildContext context,
    WidgetRef ref,
    CaisseFilter filter,
    CaisseFilterNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: const Text('Tous les types'),
            leading: const Icon(Icons.all_inclusive),
            selected: filter.type == null,
            onTap: () {
              notifier.setType(null);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Entrées'),
            leading: Icon(Icons.arrow_downward, color: AppColors.secondary),
            selected: filter.type == 'entree',
            onTap: () {
              notifier.setType('entree');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Sorties'),
            leading: Icon(Icons.arrow_upward, color: AppColors.retard),
            selected: filter.type == 'sortie',
            onTap: () {
              notifier.setType('sortie');
              Navigator.pop(context);
            },
          ),
        ]),
      ),
    );
  }

  void _pickCategorie(
    BuildContext context,
    WidgetRef ref,
    CaisseFilter filter,
    CaisseFilterNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          children: [
            ListTile(
              title: const Text('Toutes les catégories'),
              leading: const Icon(Icons.all_inclusive),
              selected: filter.categorie == null,
              onTap: () {
                notifier.setCategorie(null);
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            // ✅ Fix : categorieLabels (public)
            ...CaisseOperation.allCategories.map((cat) => ListTile(
              title: Text(CaisseOperation.categorieLabels[cat] ?? cat),
              leading: Icon(_catIcon(cat), size: 20),
              selected: filter.categorie == cat,
              onTap: () {
                notifier.setCategorie(cat);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  IconData _catIcon(String cat) {
    return switch (cat) {
      'loyer_location' => Icons.home_outlined,
      'vente_vehicule' => Icons.sell_outlined,
      'echange' => Icons.swap_horiz,
      'reparation' => Icons.build_outlined,
      'entretien' => Icons.engineering_outlined,
      'carburant' => Icons.local_gas_station_outlined,
      'assurance' => Icons.shield_outlined,
      'controle_technique' => Icons.verified_outlined,
      'lavage' => Icons.water_drop_outlined,
      _ => Icons.category_outlined,
    };
  }
}

// ─── Widgets internes ────────────────────────────────────────────────────────

class _PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13,
                color: selected ? Colors.white : AppColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool danger;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.retard
        : active
            ? AppColors.primary
            : Colors.grey.shade600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.4) : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
            ],
            Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              )),
            if (!danger) ...[
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}