import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/achat_model.dart';
import 'achats_provider.dart';

class AchatsScreen extends ConsumerStatefulWidget {
  const AchatsScreen({super.key});

  @override
  ConsumerState<AchatsScreen> createState() => _AchatsScreenState();
}

class _AchatsScreenState extends ConsumerState<AchatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AchatStatut? _filtreStatut;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // BUGFIX: déclencher setState à chaque changement d'onglet
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _filtrerParStatut(AchatStatut? statut) {
    setState(() {
      _filtreStatut = statut;
    });
  }

  @override
  Widget build(BuildContext context) {
    final achatsAsync = ref.watch(achatsProvider);
    final statsAsync = ref.watch(statsAchatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achats & Reprises'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(achatsProvider);
              ref.invalidate(statsAchatsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Tous'),
            Tab(text: 'En cours'),
            Tab(text: 'Validés'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stats summary
          statsAsync.when(
            data: (stats) => _StatsSummary(stats: stats),
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),
          // Content
          Expanded(
            child: achatsAsync.when(
              data: (achats) {
                List<Achat> filteredAchats = achats;
                final currentIndex = _tabController.index;
                
                if (currentIndex == 1) {
                  filteredAchats = achats
                      .where((a) => a.statut == AchatStatut.en_cours)
                      .toList();
                } else if (currentIndex == 2) {
                  filteredAchats = achats
                      .where((a) => a.statut == AchatStatut.valide)
                      .toList();
                }

                if (_filtreStatut != null) {
                  filteredAchats = filteredAchats
                      .where((a) => a.statut == _filtreStatut)
                      .toList();
                }

                if (filteredAchats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getEmptyMessage(currentIndex),
                          style: AppTextStyles.heading3,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/achats/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('Nouvel achat'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredAchats.length,
                  itemBuilder: (context, index) {
                    return _AchatCard(achat: filteredAchats[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.retard),
                    const SizedBox(height: 16),
                    Text('Erreur: $e',
                        style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(achatsProvider);
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/achats/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel achat'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  String _getEmptyMessage(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Aucun achat enregistré';
      case 1:
        return 'Aucun achat en cours';
      case 2:
        return 'Aucun achat validé';
      default:
        return 'Aucun achat';
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.clear),
            title: const Text('Aucun filtre'),
            onTap: () {
              _filtrerParStatut(null);
              Navigator.pop(context);
            },
          ),
          ...AchatStatut.values.map((statut) => ListTile(
                leading: Icon(
                  statut == _filtreStatut
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                ),
                title: Text(statut.label),
                onTap: () {
                  _filtrerParStatut(statut);
                  Navigator.pop(context);
                },
              )),
        ],
      ),
    );
  }
}

class _StatsSummary extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalAchats = stats['total_achats'] as int? ?? 0;
    final totalDepense = stats['total_depense'] as double? ?? 0;
    final enCours = stats['en_cours'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Total achats',
            value: totalAchats.toString(),
            icon: Icons.shopping_cart,
            color: AppColors.primary,
          ),
          _StatItem(
            label: 'Dépense totale',
            value: _formatPrice(totalDepense),
            icon: Icons.attach_money,
            color: AppColors.secondary,
          ),
          _StatItem(
            label: 'En cours',
            value: enCours.toString(),
            icon: Icons.pending_actions,
            color: AppColors.amber,
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M DA';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K DA';
    }
    return '${price.toStringAsFixed(0)} DA';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color.withValues(alpha: 0.7)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.label.copyWith(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AchatCard extends StatelessWidget {
  final Achat achat;

  const _AchatCard({required this.achat});

  static Color getColorFromStatut(AchatStatut statut) {
    return Color(int.parse('0x${statut.color.substring(1)}'));
  }

  @override
  Widget build(BuildContext context) {
        final vehNom = achat.vehiculeNom ?? 'Véhicule ${achat.vehiculeId.substring(0, 8)}...';
    final color = _AchatCard.getColorFromStatut(achat.statut);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/achats/${achat.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.shopping_cart,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehNom,
                          style: AppTextStyles.heading3,
                        ),
                        Text(
                          achat.vendeurNom,
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(statut: achat.statut),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prix accordé',
                        style: AppTextStyles.label,
                      ),
                      Text(
                        '${achat.prixAccorde.toStringAsFixed(0)} DA',
                        style: AppTextStyles.heading3.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Date achat',
                        style: AppTextStyles.label,
                      ),
                      Text(
                        '${achat.dateAchat.day}/${achat.dateAchat.month}/${achat.dateAchat.year}',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AchatStatut statut;

  const _StatusBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final color = _AchatCard.getColorFromStatut(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        statut.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}