// lib/features/locations/presentation/locations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/delete_confirm.dart';
import '../../../shared/widgets/car_damage_map.dart';
import '../../vehicules/domain/etat_carrosserie_model.dart';
import '../../../shared/services/notification_service.dart';
import '../domain/location_model.dart';
import 'location_recap_screen.dart';
import 'locations_provider.dart';
import 'location_interruption_widget.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';
// `location_interruption_widget.dart` fournit notamment :
//   - showInterruptionManager(context, location) -> ouvre le bottom-sheet de gestion
//   - InterruptionBadge(location: location) -> badge compact (vide si rien d'actif)


// ─────────────────────────────────────────────────────────────────────────────
// ÉCRAN PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class LocationsScreen extends ConsumerStatefulWidget {
  const LocationsScreen({super.key});

  @override
  ConsumerState<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends ConsumerState<LocationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.l10n.titreLocations),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_view_week_outlined),
            tooltip: context.l10n.tooltipPlanning,
            onPressed: () => context.push('/locations/calendrier'),
            color: AppColors.textSecondary,
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: context.l10n.tooltipRetourAccueil,
            onPressed: () => context.go('/dashboard'),
            color: AppColors.textSecondary,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.secondary,
          unselectedLabelColor: AppColors.textInverse,
          indicatorColor: AppColors.secondary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: context.l10n.locationEnCours),
            Tab(text: context.l10n.tabHistorique),
            Tab(text: context.l10n.statistiques),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/locations/new'),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.nouveauContrat),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _ActivesTab(),
          _HistoriqueTab(),
          _StatsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET EN COURS
// ─────────────────────────────────────────────────────────────────────────────

class _ActivesTab extends ConsumerWidget {
  const _ActivesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actives = ref.watch(locationsActivesProvider);

    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: () async {
        ref.invalidate(locationsActivesProvider);
        ref.invalidate(locationsRetardProvider);
      },
      child: actives.when(
        loading: () => const LocationsListShimmer(),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: AppColors.retard, size: 48),
            const SizedBox(height: 12),
            Text(context.l10n.erreurAvecDetail(e.toString()), style: AppTextStyles.bodySecondary),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(locationsActivesProvider),
              child: Text(context.l10n.reessayer),
            ),
          ]),
        ),
        data: (list) {
          final retards = list.where((l) => l.isOverdue).toList();
          final normales = list.where((l) => !l.isOverdue).toList();

          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.car_rental,
              message: context.l10n.aucuneLocationActive,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              if (retards.isNotEmpty) ...[
                _SectionHeader(
                  label: '⚠️ En retard (${retards.length})',
                  color: AppColors.retard,
                ),
                ...retards.map((l) => _LocationCard(location: l, showActions: true)),
                const SizedBox(height: 8),
              ],
              if (normales.isNotEmpty) ...[
                if (retards.isNotEmpty)
                  _SectionHeader(
                    label: 'En cours (${normales.length})',
                    color: AppColors.secondary,
                  ),
                ...normales.map((l) => _LocationCard(location: l, showActions: true)),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET HISTORIQUE
// ─────────────────────────────────────────────────────────────────────────────

class _HistoriqueTab extends ConsumerStatefulWidget {
  const _HistoriqueTab();

  @override
  ConsumerState<_HistoriqueTab> createState() => _HistoriqueTabState();
}

class _HistoriqueTabState extends ConsumerState<_HistoriqueTab> {
  final _searchCtrl = TextEditingController();
  String? _filterStatut;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(locationsSearchProvider.notifier).state = _searchCtrl.text;
      ref.read(locationsStatutFilterProvider.notifier).state = _filterStatut;
    });

    final filtered = ref.watch(locationsHistoriqueFiltreesProvider);

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.l10n.rechercherVehiculeOuClient,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          })
                      : null,
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tous',
                      selected: _filterStatut == null,
                      color: AppColors.textSecondary,
                      onTap: () => setState(() => _filterStatut = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: context.l10n.termine,
                      selected: _filterStatut == 'termine',
                      color: AppColors.secondary,
                      onTap: () => setState(
                          () => _filterStatut = _filterStatut == 'termine' ? null : 'termine'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: context.l10n.locationAnnule,
                      selected: _filterStatut == 'annule',
                      color: AppColors.retard,
                      onTap: () => setState(
                          () => _filterStatut = _filterStatut == 'annule' ? null : 'annule'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.secondary,
            onRefresh: () async => ref.invalidate(locationsHistoriqueProvider),
            child: filtered.when(
              loading: () => const LocationsListShimmer(),
              error: (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
              data: (list) => list.isEmpty
                  ? EmptyState(
                      icon: Icons.history,
                      message: _searchCtrl.text.isNotEmpty
                          ? 'Aucun résultat pour "${_searchCtrl.text}"'
                          : 'Aucun historique de location',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _LocationCard(
                        location: list[i],
                        showActions: false,
                        isHistorique: true,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET STATISTIQUES
// ─────────────────────────────────────────────────────────────────────────────

class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(locationsStatsProvider);

    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: () async => ref.invalidate(locationsStatsProvider),
      child: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  label: context.l10n.totalLocations,
                  value: '${s['total']}',
                  icon: Icons.assignment,
                  color: AppColors.primary,
                ),
                _StatCard(
                  label: context.l10n.locationEnCours,
                  value: '${s['actives']}',
                  icon: Icons.play_circle_outline,
                  color: AppColors.secondary,
                ),
                _StatCard(
                  label: context.l10n.terminees,
                  value: '${s['terminees']}',
                  icon: Icons.check_circle_outline,
                  color: AppColors.vendu,
                ),
                _StatCard(
                  label: context.l10n.annulees,
                  value: '${s['annulees']}',
                  icon: Icons.cancel_outlined,
                  color: AppColors.retard,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, AppColors.secondaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.payments_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(context.l10n.revenusLocatifs, style: AppTextStyles.heading3.copyWith(color: Colors.white)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: _RevenusItem(
                      label: context.l10n.revenuTotal,
                      value: _fmt(s['revenus']),
                    )),
                    Container(width: 1, height: 50, color: Colors.white30),
                    Expanded(
                        child: _RevenusItem(
                      label: context.l10n.encaisse,
                      value: _fmt(s['encaisse']),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _RevenusItem(
                      label: context.l10n.resteAPercevoir,
                      value: _fmt((s['revenus'] as double) - (s['encaisse'] as double)),
                    )),
                    Expanded(
                        child: _RevenusItem(
                      label: context.l10n.moyenneLocation,
                      value: _fmt(s['moyen']),
                    )),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '0 DA';
    final n = (v as num).toDouble();
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M DA';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k DA';
    return '${n.toInt()} DA';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE LOCATION
// ─────────────────────────────────────────────────────────────────────────────

class _LocationCard extends ConsumerWidget {
  final Location location;
  final bool showActions;
  final bool isHistorique;

  const _LocationCard({
    required this.location,
    this.showActions = true,
    this.isHistorique = false,
  });

  Color get _statusColor => switch (location.statut) {
        LocationStatut.en_cours =>
          location.isOverdue ? AppColors.retard : AppColors.secondary,
        LocationStatut.termine => AppColors.vendu,
        LocationStatut.annule => AppColors.retard,
        LocationStatut.retard => AppColors.retard,
      };

  String get _statusLabel => switch (location.statut) {
        LocationStatut.en_cours => location.isOverdue ? 'En retard' : 'En cours',
        LocationStatut.termine => 'Terminé',
        LocationStatut.annule => 'Annulé',
        LocationStatut.retard => 'En retard',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: location.isOverdue
            ? BorderSide(color: AppColors.retard.withValues(alpha: 0.3), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetailSheet(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Text(
                    location.vehiculeNom ?? '---',
                    style: AppTextStyles.heading3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(label: _statusLabel, color: _statusColor),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location.clientNom ?? '---',
                    style: AppTextStyles.bodySecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (location.clientTel != null)
                  Text(location.clientTel!,
                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 11)),
              ]),

              // ── Badge interruption active ────────────────────────────────────
              if (location.hasInterruptionActive) ...[
                const SizedBox(height: 6),
                InterruptionBadge(location: location),
              ],

              const SizedBox(height: 8),

              // ── Période ─────────────────────────────────────────────────────
              Row(children: [
                Icon(Icons.date_range, size: 13, color: _statusColor),
                const SizedBox(width: 4),
                Text(
                  '${_d(location.dateDebut)} → '
                  '${location.dateFinPrevue != null ? _d(location.dateFinPrevue!) : 'Contrat ouvert'}',
                  style: TextStyle(
                      fontSize: 12, color: _statusColor, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${location.nbJours}j × ${location.prixJour.toInt()} DA',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ]),

              // ── Badge retard ─────────────────────────────────────────────────
              if (location.isOverdue)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Icon(Icons.warning_amber, size: 13, color: AppColors.retard),
                    const SizedBox(width: 4),
                    Text(
                      '${location.joursRetard} jour(s) de retard',
                      style: const TextStyle(
                          color: AppColors.retard,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              const SizedBox(height: 10),

              // ── Footer : montant + actions ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${location.montantCalcule.toInt()} DA',
                      style: AppTextStyles.money.copyWith(fontSize: 15),
                    ),
                    if (location.caution > 0)
                      Text(context.l10n.cautionMontantDa(location.caution.toInt().toString()),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                  Row(children: _buildActionButtons(context, ref)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Boutons d'action ──────────────────────────────────────────────────────

  List<Widget> _buildActionButtons(BuildContext context, WidgetRef ref) {
    // Bouton résumé — présent partout
    final btnResume = _ActionBtn(
      icon: Icons.analytics_outlined,
      tooltip: context.l10n.resumeFinancier,
      color: AppColors.accent,
      onPressed: () => showLocationRecap(context, location.id),
    );

    if (isHistorique) {
      return [
        btnResume,
        const SizedBox(width: 6),
        _ActionBtn(
          icon: Icons.edit_outlined,
          tooltip: context.l10n.btnModifier,
          color: AppColors.primary,
          onPressed: () => context.push('/locations/${location.id}/edit'),
        ),
        const SizedBox(width: 6),
        _ActionBtn(
          icon: Icons.copy_outlined,
          tooltip: context.l10n.dupliquer,
          color: AppColors.primary,
          onPressed: () => _dupliquer(context, ref),
        ),
        const SizedBox(width: 6),
        _ActionBtn(
          icon: Icons.delete_outline,
          tooltip: context.l10n.btnSupprimer,
          color: AppColors.retard,
          onPressed: () => _supprimer(context, ref),
        ),
      ];
    }

    if (location.statut == LocationStatut.en_cours || location.isOverdue) {
      return [
        btnResume,
        const SizedBox(width: 6),
        _ActionBtn(
          icon: Icons.pause_circle_outline,
          tooltip: context.l10n.gererLesInterruptions,
          color: AppColors.warning,
          onPressed: () => showInterruptionManager(context, location),
        ),
        const SizedBox(width: 6),
        _ActionBtn(
          icon: Icons.keyboard_return,
          tooltip: context.l10n.retourVehicule,
          color: AppColors.secondary,
          label: context.l10n.btnRetour,
          onPressed: () => context.push('/locations/${location.id}/retour'),
        ),
        const SizedBox(width: 4),
        // Menu secondaire (actions moins fréquentes : Modifier, etc.)
        _OverflowMenuBtn(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                context.push('/locations/${location.id}/edit');
                break;
            }
          },
          items: [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined, color: AppColors.primary),
                title: Text(context.l10n.btnModifier),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ];
    }

    // Cas résiduel
    return [
      btnResume,
      const SizedBox(width: 6),
      _ActionBtn(
        icon: Icons.edit_outlined,
        tooltip: context.l10n.btnModifier,
        color: AppColors.primary,
        onPressed: () => context.push('/locations/${location.id}/edit'),
      ),
    ];
  }

  void _showDetailSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationDetailSheet(location: location),
    );
  }

  Future<void> _dupliquer(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    context.push('/locations/new?vehiculeId=${location.vehiculeId}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.selectionnezLeMemeClientPourDupliquer),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final ok = await showDeleteConfirm(
      context,
      title: context.l10n.supprimerLaLocation,
      message: context.l10n.confirmerSuppressionLocationMessage(
          location.vehiculeNom ?? "ce véhicule", location.clientNom ?? "ce client"),
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(locationsRepositoryProvider).delete(location.id);
      ref.invalidate(locationsHistoriqueProvider);
      ref.invalidate(locationsAllProvider);
      ref.invalidate(locationsStatsProvider);
      if (context.mounted) NotificationService().success(context.l10n.locationSupprimee);
    } catch (e) {
      if (context.mounted) NotificationService().error(context.l10n.erreurAvecDetail(e.toString()));
    }
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET DÉTAIL
// ─────────────────────────────────────────────────────────────────────────────

class _LocationDetailSheet extends ConsumerWidget {
  final Location location;
  const _LocationDetailSheet({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = location;
    final paiements = ref.watch(locationPaiementsProvider(l.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.vehiculeNom ?? '---', style: AppTextStyles.heading2),
                      Text(
                        l.clientNom ?? '---',
                        style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Bouton Résumé financier
                IconButton(
                  icon: const Icon(Icons.analytics_outlined),
                  color: AppColors.accent,
                  tooltip: context.l10n.resumeFinancier,
                  onPressed: () {
                    Navigator.of(context).pop();
                    showLocationRecap(context, l.id);
                  },
                ),
                // Bouton Modifier
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: AppColors.primary,
                  tooltip: context.l10n.modifierLaLocation,
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/locations/${l.id}/edit');
                  },
                ),
              ]),
            ),
            const Divider(height: 1),

            // ── Corps scrollable ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // Statut
                  _StatusBadgeRow(location: l),
                  const SizedBox(height: 12),

                  // Période
                  _DetailSection(
                    icon: Icons.date_range,
                    title: context.l10n.periode,
                    child: Row(children: [
                      Expanded(child: _InfoTile(label: context.l10n.depart, value: _d(l.dateDebut))),
                      Expanded(
                        child: _InfoTile(
                          label: context.l10n.retourPrevu,
                          value: l.dateFinPrevue != null
                              ? _d(l.dateFinPrevue!)
                              : 'Contrat ouvert',
                        ),
                      ),
                      if (l.dateFinReelle != null)
                        Expanded(
                            child: _InfoTile(
                                label: context.l10n.retourReel, value: _d(l.dateFinReelle!))),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Kilométrage
                  _DetailSection(
                    icon: Icons.speed,
                    title: context.l10n.kilometrage,
                    child: Row(children: [
                      Expanded(
                          child: _InfoTile(label: context.l10n.kmDepart, value: '${l.kmDepart} km')),
                      Expanded(
                          child: _InfoTile(
                        label: context.l10n.kmRetour,
                        value: l.kmRetour != null ? '${l.kmRetour} km' : '—',
                      )),
                      if (l.kmRetour != null)
                        Expanded(
                            child: _InfoTile(
                          label: 'Distance',
                          value: '${l.kmRetour! - l.kmDepart} km',
                        )),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Financier
                  _DetailSection(
                    icon: Icons.payments_outlined,
                    title: context.l10n.champFinancier,
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                            child: _InfoTile(
                                label: context.l10n.prixJour,
                                value: '${l.prixJour.toInt()} DA')),
                        Expanded(
                            child:
                                _InfoTile(label: context.l10n.duree, value: '${l.nbJours} jours')),
                        Expanded(
                            child: _InfoTile(
                                label: 'Total',
                                value: '${l.montantCalcule.toInt()} DA',
                                bold: true)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _InfoTile(
                                label: context.l10n.champCaution,
                                value: '${l.caution.toInt()} DA')),
                        if (l.retenueCaution > 0)
                          Expanded(
                              child: _InfoTile(
                            label: context.l10n.retenueCaution,
                            value: '${l.retenueCaution.toInt()} DA',
                            color: AppColors.retard,
                          )),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Paiements
                  _DetailSection(
                    icon: Icons.receipt_long_outlined,
                    title: context.l10n.titrePaiements,
                    child: paiements.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(context.l10n.erreurAvecDetail(e.toString())),
                      data: (list) {
                        if (list.isEmpty) {
                          return Text(context.l10n.aucunPaiementEnregistre, style: TextStyle(color: AppColors.textSecondary),
                          );
                        }
                        final total =
                            list.fold<double>(0, (s, p) => s + p.montant);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...list.map((p) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(children: [
                                    const Icon(Icons.check_circle,
                                        size: 14, color: AppColors.secondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: Text(
                                      _d(p.datePaiement) +
                                          (p.mode != null
                                              ? ' (${p.mode})'
                                              : ''),
                                      style: const TextStyle(fontSize: 12),
                                    )),
                                    Text('${p.montant.toInt()} ${context.l10n.uniteDa}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                                )),
                            const Divider(height: 12),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(context.l10n.totalEncaisse, style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text('${total.toInt()} ${context.l10n.uniteDa}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.secondary)),
                                ]),
                            if (total < l.montantCalcule)
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(context.l10n.resteAPercevoir, style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
                                    Text(
                                        '${(l.montantCalcule - total).toInt()} DA',
                                        style: const TextStyle(
                                            color: AppColors.retard,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12)),
                                  ]),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  if (l.notesDepart != null || l.notesRetour != null)
                    _DetailSection(
                      icon: Icons.note_outlined,
                      title: context.l10n.champNotes,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (l.notesDepart != null)
                              Text(context.l10n.labelNotesDepart(l.notesDepart ?? ''),
                                  style: AppTextStyles.bodySecondary),
                            if (l.notesRetour != null) ...[
                              const SizedBox(height: 6),
                              Text(context.l10n.labelNotesRetour(l.notesRetour ?? ''),
                                  style: AppTextStyles.bodySecondary),
                            ],
                          ]),
                    ),

                  // Carrosserie départ
                  if (l.etatCarrosserieDepart != null) ...[
                    const SizedBox(height: 12),
                    _CarrosserieSection(
                      jsonStr: l.etatCarrosserieDepart,
                      title: context.l10n.etatCarrosserieDepart,
                    ),
                  ],

                  // Carrosserie retour
                  if (l.etatCarrosserieRetour != null) ...[
                    const SizedBox(height: 12),
                    _CarrosserieSection(
                      jsonStr: l.etatCarrosserieRetour,
                      title: context.l10n.etatCarrosserieRetour,
                      accentColor: AppColors.warning,
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── CTA bas de sheet ─────────────────────────────────────
                  Row(children: [
                    // Résumé financier
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          showLocationRecap(context, l.id);
                        },
                        icon: const Icon(Icons.analytics_outlined, size: 16),
                        label: Text(context.l10n.resume, style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Modifier
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/locations/${l.id}/edit');
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(context.l10n.btnModifier, style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS UTILITAIRES
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadgeRow extends StatelessWidget {
  final Location location;
  const _StatusBadgeRow({required this.location});

  Color get _color => switch (location.statut) {
        LocationStatut.en_cours =>
          location.isOverdue ? AppColors.retard : AppColors.secondary,
        LocationStatut.termine => AppColors.vendu,
        LocationStatut.annule => AppColors.retard,
        LocationStatut.retard => AppColors.retard,
      };

  String get _label => switch (location.statut) {
        LocationStatut.en_cours => location.isOverdue ? 'En retard' : 'En cours',
        LocationStatut.termine => 'Terminé',
        LocationStatut.annule => 'Annulé',
        LocationStatut.retard => 'En retard',
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 8, color: _color),
          const SizedBox(width: 6),
          Text(_label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _color)),
          if (location.isOverdue) ...[
            const SizedBox(width: 8),
            Text(context.l10n.nJoursRetardBullet(location.joursRetard.toString()),
                style: TextStyle(fontSize: 11, color: _color)),
          ],
        ]),
      );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style:
                TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: selected ? color : color.withValues(alpha: 0.3)),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color,
              )),
        ),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final String? label;
  final VoidCallback onPressed;
  const _ActionBtn(
      {required this.icon,
      required this.tooltip,
      required this.color,
      this.label,
      required this.onPressed});

  @override
  Widget build(BuildContext context) => label != null
      ? OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 12),
          ),
          icon: Icon(icon, size: 14),
          label: Text(label!),
          onPressed: onPressed,
        )
      : Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
          ),
        );
}

/// Bouton "⋮" stylé pour matcher visuellement les `_ActionBtn` (même fond
/// arrondi semi-transparent), utilisé pour regrouper les actions secondaires.
class _OverflowMenuBtn extends StatelessWidget {
  final List<PopupMenuEntry<String>> items;
  final void Function(String value) onSelected;
  const _OverflowMenuBtn({required this.items, required this.onSelected});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: context.l10n.tooltipPlusOptions,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          onSelected: onSelected,
          itemBuilder: (_) => items,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.more_vert,
                size: 16, color: AppColors.textSecondary),
          ),
        ),
      );
}

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _DetailSection(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _InfoTile(
      {required this.label,
      required this.value,
      this.bold = false,
      this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 14 : 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: color ?? AppColors.textPrimary,
              )),
        ],
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      );
}

class _RevenusItem extends StatelessWidget {
  final String label;
  final String value;
  const _RevenusItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION CARROSSERIE DANS LE DÉTAIL
// ─────────────────────────────────────────────────────────────────────────────

class _CarrosserieSection extends StatelessWidget {
  final String? jsonStr;
  final String title;
  final Color accentColor;

  const _CarrosserieSection({
    required this.jsonStr,
    required this.title,
    this.accentColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (jsonStr == null) return const SizedBox.shrink();
    final etat = EtatCarrosserie.fromJsonString(jsonStr);
    if (!etat.hasAnyDamage &&
        (etat.observations == null || etat.observations!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final damaged = etat.zonesEndommagees;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.directions_car_outlined, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor)),
            const Spacer(),
            if (damaged.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(context.l10n.nZones(damaged.length.toString()),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accentColor)),
              ),
          ]),
          if (damaged.isNotEmpty) ...[
            const SizedBox(height: 10),
            CarDamageMap(etat: etat, readOnly: true),
          ],
          if (etat.observations != null && etat.observations!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.note_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(etat.observations!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textPrimary))),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}