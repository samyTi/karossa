// lib/features/ventes/presentation/ventes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/vente_model.dart';
import 'ventes_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class VentesScreen extends ConsumerStatefulWidget {
  const VentesScreen({super.key});

  @override
  ConsumerState<VentesScreen> createState() => _VentesScreenState();
}

class _VentesScreenState extends ConsumerState<VentesScreen> {
  String? _filtreStatut;

  @override
  Widget build(BuildContext context) {
    final ventesAsync = ref.watch(ventesListProvider);
    final statsAsync = ref.watch(statsVentesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.titreVentes),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(ventesListProvider);
              ref.invalidate(statsVentesProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ventes/new'),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.nouvelleVente),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              _buildFilterChip('Tous', null),
              const SizedBox(width: 8),
              _buildFilterChip('Soldés', 'complet'),
              const SizedBox(width: 8),
              _buildFilterChip('Partiels', 'partiel'),
            ]),
          ),
          statsAsync.when(
            data: (stats) => _StatsBanner(stats: stats),
            loading: () => const SizedBox(height: 70),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: ventesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
              data: (ventes) {
                final filtered = _filtreStatut == null
                    ? ventes
                    : ventes.where((v) => v.statutPaiement.name == _filtreStatut).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.sell_outlined,
                    message: context.l10n.aucuneVenteEnregistree,
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

// ── Bannière de Statistiques ──────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsBanner({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats['total']?.toString() ?? '0';
    final revenu = (stats['revenu'] as num? ?? 0).toDouble();
    final encaisse = (stats['encaisse'] as num? ?? 0).toDouble();

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
          _Stat('Ventes', total, AppColors.primary),
          _Stat('CA total', '${(revenu / 1000).toStringAsFixed(0)}K DA', AppColors.secondary),
          _Stat('Encaissé', '${(encaisse / 1000).toStringAsFixed(0)}K DA', AppColors.accent),
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

// ── Carte de Vente ────────────────────────────────────────────────────────────

class _VenteCard extends StatelessWidget {
  final Vente vente;
  const _VenteCard({required this.vente});

  @override
  Widget build(BuildContext context) {
    // CORRECTION ICI : Utilisation de vehiculeNom et clientNom de votre modèle
    final nomVeh = vente.vehiculeNom ?? 'Véhicule inconnu';
    final nomCli = vente.clientNom ?? 'Client inconnu';

    final isPaid = vente.statutPaiement == VenteStatutPaiement.complet;
    final date = vente.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/ventes/${vente.id}'),
        borderRadius: BorderRadius.circular(12),
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
                _InfoCol('Prix', '${vente.prixVente.toInt()} DA'),
                _InfoCol('Encaissé', '${vente.totalPaye.toInt()} DA'),
                _InfoCol(
                  'Solde',
                  '${vente.soldeRestant.toInt()} DA',
                  color: vente.soldeRestant > 0 ? AppColors.retard : AppColors.secondary,
                ),
                _InfoCol(
                  'Date',
                  '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                ),
              ],
            ),
          ]),
        ),
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
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.textPrimary,
              )),
        ],
      );
}