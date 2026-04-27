import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../main.dart';
import '../domain/vehicule_model.dart';
import 'vehicules_provider.dart';

class VehiculeDetailScreen extends ConsumerWidget {
  final String id;
  const VehiculeDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicule = ref.watch(vehiculeDetailProvider(id));

    return vehicule.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erreur: $e'))),
      data: (v) => _Body(vehicule: v, ref: ref),
    );
  }
}

class _Body extends StatelessWidget {
  final Vehicule vehicule;
  final WidgetRef ref;
  const _Body({required this.vehicule, required this.ref});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(slivers: [
      // AppBar avec photo
      SliverAppBar(
        expandedHeight: 240,
        pinned: true,
        flexibleSpace: FlexibleSpaceBar(
          title: Text(vehicule.displayName,
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700)),
          background: vehicule.photos.isNotEmpty
            ? PageView.builder(
                itemCount: vehicule.photos.length,
                itemBuilder: (_, i) => CachedNetworkImage(
                  imageUrl: vehicule.photos[i],
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                    const _NoPhoto()))
            : const _NoPhoto(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique',
            onPressed: () =>
              context.push('/vehicules/${vehicule.id}/history'),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
              context.push('/vehicules/${vehicule.id}/edit'),
          ),
        ],
      ),

      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statut + actions
              Row(children: [
                StatusBadge(statut: vehicule.statut),
                const Spacer(),
                if (vehicule.statut == VehiculeStatut.disponible) ...[
                  _ActionBtn(
                    'Louer', Icons.car_rental,
                    AppColors.secondary,
                    () => context.push(
                      '/locations/new?vehiculeId=${vehicule.id}')),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    'Vendre', Icons.sell_outlined,
                    AppColors.primary,
                    () => context.push(
                      '/ventes/new?vehiculeId=${vehicule.id}')),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    'Echanger', Icons.swap_horiz,
                    AppColors.accent,
                    () => context.push(
                      '/echanges/new?vehiculeId=${vehicule.id}')),
                ],
              ]),
              const SizedBox(height: 20),

              // Infos principales
              _InfoCard('Caracteristiques', [
                _InfoRow('Marque / Modele',
                  '${vehicule.marque} ${vehicule.modele}'),
                _InfoRow('Annee', '${vehicule.annee}'),
                if (vehicule.couleur != null)
                  _InfoRow('Couleur', vehicule.couleur!),
                if (vehicule.immatriculation != null)
                  _InfoRow('Immatriculation', vehicule.immatriculation!),
                if (vehicule.carburant != null)
                  _InfoRow('Carburant', vehicule.carburant!),
                if (vehicule.boite != null)
                  _InfoRow('Boite', vehicule.boite!),
                _InfoRow('Kilometrage',
                  '${vehicule.kilometrage} km'),
              ]),
              const SizedBox(height: 12),

              // Prix
              _InfoCard('Tarifs', [
                if (vehicule.prixLocationJour != null)
                  _InfoRow('Location / jour',
                    '${vehicule.prixLocationJour!.toInt()} DA',
                    color: AppColors.secondary),
                if (vehicule.prixVente != null)
                  _InfoRow('Prix de vente',
                    '${vehicule.prixVente!.toInt()} DA',
                    color: AppColors.primary),
              ]),
              const SizedBox(height: 12),

              // Propriétaires
              if (vehicule.proprietes.isNotEmpty)
                _InfoCard('Proprietaires', vehicule.proprietes.map((p) =>
                  _InfoRow(p.proprietaireNom,
                    '${p.partPct.toInt()}%')).toList()),
              const SizedBox(height: 12),

              // Notes
              if (vehicule.notes != null && vehicule.notes!.isNotEmpty)
                _InfoCard('Notes', [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(vehicule.notes!,
                      style: AppTextStyles.body)),
                ]),
              const SizedBox(height: 12),

              // Changer statut
              if (vehicule.statut == VehiculeStatut.reparation)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary),
                    icon: const Icon(Icons.check),
                    label: const Text('Marquer disponible'),
                    onPressed: () async {
                      await supabase.from('vehicules')
                        .update({'statut': 'disponible'})
                        .eq('id', vehicule.id);
                      ref.invalidate(vehiculesProvider);
                      ref.invalidate(vehiculeDetailProvider(vehicule.id));
                    },
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    icon: Icon(icon, size: 14),
    label: Text(label),
    onPressed: onTap,
  );
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard(this.title, this.children);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title.toUpperCase(), style: AppTextStyles.label),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(children: children),
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _InfoRow(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(
        color: AppColors.border, width: 0.5))),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySecondary),
        Text(value, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: color ?? AppColors.textPrimary)),
      ],
    ),
  );
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.inputFill,
    child: const Icon(Icons.directions_car,
      size: 64, color: AppColors.border),
  );
}
