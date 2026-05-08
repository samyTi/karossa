import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../domain/vehicule_model.dart';
import 'vehicules_provider.dart';

class CatalogueScreen extends ConsumerWidget {
  const CatalogueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicules = ref.watch(vehiculesFiltresProvider);
    final statut    = ref.watch(statutFiltreProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final hasActiveFilters = ref.watch(marqueFiltreProvider) != null ||
        ref.watch(anneeMinProvider) != null ||
        ref.watch(anneeMaxProvider) != null ||
        ref.watch(prixMaxProvider) != null;

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Catalogue',
        showBackButton: false,
        showHomeButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vehicules/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        // Barre de recherche
        _SearchBar(
          query: searchQuery,
          onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
          onCleared: () => ref.read(searchQueryProvider.notifier).state = '',
        ),
        // Barre de filtres avec bouton pour filtres avancés
        Row(
          children: [
            // Compteur de résultats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                vehicules.value?.length != null
                    ? '${vehicules.value!.length} véhicule${vehicules.value!.length > 1 ? 's' : ''}'
                    : '',
                style: AppTextStyles.label,
              ),
            ),
            const Spacer(),
            // Bouton filtres avancés
            if (hasActiveFilters)
              IconButton(
                icon: const Icon(Icons.filter_alt, color: AppColors.primary),
                onPressed: () => _showFiltersDialog(context, ref),
                tooltip: 'Filtres actifs',
              ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFiltersDialog(context, ref),
              tooltip: 'Filtres',
            ),
          ],
        ),
        // Filtres par statut
        _StatutFilterBar(selected: statut),
        Expanded(child: vehicules.when(
          loading: () => const VehiculesListShimmer(itemCount: 5),
          error:   (e, _) => Center(child: Text('Erreur: $e')),
          data:    (list) => list.isEmpty
            ? EmptyState(
                icon: searchQuery.isNotEmpty ? Icons.search : Icons.directions_car_outlined,
                message: searchQuery.isNotEmpty
                    ? 'Aucun véhicule ne correspond à "$searchQuery"'
                    : 'Aucun véhicule dans le stock',
                actionLabel: searchQuery.isNotEmpty ? 'Effacer la recherche' : null,
                onAction: searchQuery.isNotEmpty
                    ? () => ref.read(searchQueryProvider.notifier).state = ''
                    : null,
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: list.length,
                itemBuilder: (_, i) => _VehiculeCard(
                  vehicule: list[i],
                  onTap: () => context.push('/vehicules/${list[i].id}'),
                ),
              ),
        )),
      ]),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  const _SearchBar({
    required this.query,
    required this.onChanged,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: AppColors.surface,
    child: TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Rechercher un véhicule (marque, modèle, immatriculation...)',
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                onPressed: onCleared,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
  );
}

class _StatutFilterBar extends ConsumerWidget {
  final VehiculeStatut? selected;
  const _StatutFilterBar({required this.selected});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuts = [null, VehiculeStatut.disponible, VehiculeStatut.loue,
                     VehiculeStatut.reparation, VehiculeStatut.reserve];
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: statuts.map((s) {
          final isSelected = s == selected;
          final label = s == null ? 'Tous' : s.label;
          final color = s == null ? AppColors.primary : s.color;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label, style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : color)),
              selected: isSelected,
              onSelected: (_) =>
                ref.read(statutFiltreProvider.notifier).state = s,
              selectedColor: color,
              backgroundColor: color.withValues(alpha: 0.1),
              side: BorderSide(color: color.withValues(alpha: 0.3)),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _VehiculeCard extends StatelessWidget {
  final Vehicule vehicule;
  final VoidCallback onTap;
  const _VehiculeCard({required this.vehicule, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 80, height: 60,
              child: vehicule.photos.isNotEmpty
                ? CachedNetworkImage(imageUrl: vehicule.photos.first,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const _PhotoPlaceholder())
                : const _PhotoPlaceholder()),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(vehicule.displayName,
                  style: AppTextStyles.heading3, maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
                StatusBadge(statut: vehicule.statut),
              ]),
              const SizedBox(height: 4),
              Text('${vehicule.kilometrage} km'
                + (vehicule.immatriculation != null
                   ? ' · ${vehicule.immatriculation}' : ''),
                style: AppTextStyles.bodySecondary),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [
                if (vehicule.prixLocationJour != null)
                  _Chip('${vehicule.prixLocationJour!.toInt()} DA/j',
                    AppColors.secondary),
                if (vehicule.prixVente != null)
                  _Chip('${vehicule.prixVente!.toInt()} DA',
                    AppColors.primary),
              ]),
              if (vehicule.proprietes.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(vehicule.proprietes
                  .map((p) => '${p.proprietaireNom} ${p.partPct.toInt()}%')
                  .join(' · '),
                  style: AppTextStyles.label, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              ],
            ],
          )),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ]),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.inputFill,
    child: const Icon(Icons.directions_car, color: AppColors.border, size: 28),
  );
}

/// Dialogue de filtres avancés
void _showFiltersDialog(BuildContext context, WidgetRef ref) {
  final marqueController = TextEditingController(
    text: ref.read(marqueFiltreProvider) ?? '');
  final anneeMinController = TextEditingController(
    text: ref.read(anneeMinProvider)?.toString() ?? '');
  final anneeMaxController = TextEditingController(
    text: ref.read(anneeMaxProvider)?.toString() ?? '');
  final prixMaxController = TextEditingController(
    text: ref.read(prixMaxProvider)?.toString() ?? '');

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.filter_list, size: 24),
            const SizedBox(width: 8),
            const Text('Filtres avancés'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: marqueController,
                decoration: const InputDecoration(
                  labelText: 'Marque',
                  hintText: 'ex: Renault, Peugeot...',
                  prefixIcon: Icon(Icons.branding_watermark_outlined),
                ),
                onChanged: (value) => setDialogState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: anneeMinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Année min',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: anneeMaxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Année max',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: prixMaxController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prix max (DA)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Réinitialiser les filtres
              ref.read(marqueFiltreProvider.notifier).state = null;
              ref.read(anneeMinProvider.notifier).state = null;
              ref.read(anneeMaxProvider.notifier).state = null;
              ref.read(prixMaxProvider.notifier).state = null;
              Navigator.pop(context);
            },
            child: const Text('Réinitialiser'),
          ),
          ElevatedButton(
            onPressed: () {
              // Appliquer les filtres
              ref.read(marqueFiltreProvider.notifier).state =
                  marqueController.text.isEmpty ? null : marqueController.text;
              ref.read(anneeMinProvider.notifier).state =
                  int.tryParse(anneeMinController.text);
              ref.read(anneeMaxProvider.notifier).state =
                  int.tryParse(anneeMaxController.text);
              ref.read(prixMaxProvider.notifier).state =
                  double.tryParse(prixMaxController.text);
              Navigator.pop(context);
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    ),
  );
}
