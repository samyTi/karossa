import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import 'ventes_provider.dart';

class VentesScreen extends ConsumerStatefulWidget {
  const VentesScreen({super.key});

  @override
  ConsumerState<VentesScreen> createState() => _VentesScreenState();
}

class _VentesScreenState extends ConsumerState<VentesScreen> {
  String? _filtreStatut; // null = tous, 'complet', 'partiel'

  @override
  Widget build(BuildContext context) {
    final ventesAsync = ref.watch(ventesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ventesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ventes/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle vente'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtre statut paiement
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              _buildFilterChip('Tous',    null),
              const SizedBox(width: 8),
              _buildFilterChip('Soldés', 'complet'),
              const SizedBox(width: 8),
              _buildFilterChip('Partiels', 'partiel'),
            ]),
          ),

          // Résumé stats
          ventesAsync.when(
            data: (ventes) => _StatsBanner(ventes: ventes),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Liste
          Expanded(
            child: ventesAsync.when(
              loading: () => const Center(child: const CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (ventes) {
                final filtered = _filtreStatut == null
                  ? ventes
                  : ventes.where((v) => v['statut_paiement'] == _filtreStatut).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.sell_outlined,
                    message: 'Aucune vente enregistrée',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _VenteCard(vente: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? statut) => ChoiceChip(
    label: Text(label),
    selected: _filtreStatut == statut,
    onSelected: (_) => setState(() => _filtreStatut = statut),
    selectedColor: AppColors.primary.withValues(alpha: 0.15),
    labelStyle: TextStyle(
      color: _filtreStatut == statut ? AppColors.primary : AppColors.textSecondary,
      fontWeight: _filtreStatut == statut ? FontWeight.w600 : FontWeight.w400,
    ),
  );
}

class _StatsBanner extends StatelessWidget {
  final List<Map<String, dynamic>> ventes;
  const _StatsBanner({required this.ventes});

  @override
  Widget build(BuildContext context) {
    double totalVentes = 0;
    double totalEncaisse = 0;

    for (final v in ventes) {
      final prix = (v['prix_vente'] as num? ?? 0).toDouble();
      final acompte = (v['acompte'] as num? ?? 0).toDouble();
      totalVentes += prix;
      totalEncaisse += acompte;
      // totalSoldes non affiché dans ce widget — calcul supprimé
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat('Ventes',    ventes.length.toString(),        AppColors.primary),
          _Stat('CA total',  '${(totalVentes/1000).toStringAsFixed(0)}K DA',  AppColors.secondary),
          _Stat('Encaissé',  '${(totalEncaisse/1000).toStringAsFixed(0)}K DA', AppColors.accent),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
    Text(label, style: AppTextStyles.label),
  ]);
}

class _VenteCard extends StatelessWidget {
  final Map<String, dynamic> vente;
  const _VenteCard({required this.vente});

  @override
  Widget build(BuildContext context) {
    final veh = vente['vehicules'];
    final cli = vente['clients'];
    final nomVeh = veh != null
      ? '${veh['marque']} ${veh['modele']} ${veh['annee'] ?? ''}'.trim()
      : 'Véhicule inconnu';
    final nomCli = cli != null
      ? '${cli['prenom']} ${cli['nom']}'
      : 'Client inconnu';

    final prix    = (vente['prix_vente'] as num? ?? 0).toDouble();
    final acompte = (vente['acompte'] as num? ?? 0).toDouble();
    final solde   = (vente['solde_restant'] as num? ?? 0).toDouble();
    final statut  = vente['statut_paiement'] as String? ?? 'partiel';
    final isPaid  = statut == 'complet';
    final date    = DateTime.tryParse(vente['created_at'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nomVeh, style: AppTextStyles.heading3),
                Text(nomCli, style: AppTextStyles.bodySecondary),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isPaid ? AppColors.secondary : AppColors.accent).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isPaid ? AppColors.secondary : AppColors.accent).withValues(alpha: 0.3)),
              ),
              child: Text(
                isPaid ? 'Soldé' : 'Partiel',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPaid ? AppColors.secondary : AppColors.accent,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InfoCol('Prix vente', '${prix.toInt()} DA'),
              _InfoCol('Acompte', '${acompte.toInt()} DA'),
              _InfoCol('Solde restant',
                '${solde.toInt()} DA',
                color: solde > 0 ? AppColors.retard : AppColors.secondary),
              if (date != null)
                _InfoCol('Date',
                  '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}'),
            ],
          ),
        ]),
      ),
    );
  }
}

class _InfoCol extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _InfoCol(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.label),
      Text(value, style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      )),
    ],
  );
}
