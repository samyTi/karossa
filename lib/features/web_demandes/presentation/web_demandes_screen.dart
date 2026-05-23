// lib/features/web_demandes/presentation/web_demandes_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/web_demande_model.dart';
import '../domain/web_demandes_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Écran principal
// ─────────────────────────────────────────────────────────────────────────────

class WebDemandesScreen extends ConsumerWidget {
  const WebDemandesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Demandes Web & Leads'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            // Bouton actualiser
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
              onPressed: () {
                ref.invalidate(webDemandesListProvider);
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            onTap: (index) {
              final types = [
                null,
                DemandeWebType.location,
                DemandeWebType.propositionVente,
                DemandeWebType.demandeDevis,
              ];
              ref.read(webDemandesTypeFilterProvider.notifier).state =
                  types[index];
            },
            tabs: const [
              Tab(text: 'Toutes'),
              Tab(icon: Icon(Icons.car_rental, size: 16), text: 'Location'),
              Tab(
                icon: Icon(Icons.handshake_outlined, size: 16),
                text: 'Reprises',
              ),
              Tab(
                icon: Icon(Icons.request_quote_outlined, size: 16),
                text: 'Devis/Achat',
              ),
            ],
          ),
        ),
        body: const _BodyWithFilters(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _BodyWithFilters extends ConsumerWidget {
  const _BodyWithFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(webDemandesStatsProvider);

    return Column(
      children: [
        // ── Bandeau de statistiques ──────────────────────────────────────────
        statsAsync.when(
          loading: () => const _StatsBarSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
          data: (stats) => _StatsBar(stats: stats),
        ),

        // ── Barre de recherche ───────────────────────────────────────────────
        const _SearchBar(),

        // ── Filtre par statut ────────────────────────────────────────────────
        const _StatutFilterBar(),

        // ── Liste filtrée ────────────────────────────────────────────────────
        const Expanded(child: _DemandesListView()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barre de recherche
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          hintText: 'Rechercher (client, téléphone, véhicule…)',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _ctrl.clear();
                    ref.read(webDemandesSearchProvider.notifier).state = '';
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        onChanged: (v) {
          setState(() {}); // pour afficher/masquer le bouton clear
          ref.read(webDemandesSearchProvider.notifier).state = v;
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBarSkeleton extends StatelessWidget {
  const _StatsBarSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        color: AppColors.primary.withValues(alpha: 0.05),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

class _StatsBar extends StatelessWidget {
  final WebDemandesStats stats;
  const _StatsBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatChip(
            label: 'En attente',
            count: stats.enAttente,
            color: Colors.orange,
          ),
          _StatChip(
            label: 'Approuvées',
            count: stats.approuvees,
            color: Colors.green,
          ),
          _StatChip(
            label: 'Rejetées',
            count: stats.rejetees,
            color: Colors.red,
          ),
          _StatChip(
            label: 'Total',
            count: stats.total,
            color: Colors.blueGrey,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count.toString(),
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filtre statut
// ─────────────────────────────────────────────────────────────────────────────

class _StatutFilterBar extends ConsumerWidget {
  const _StatutFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(webDemandesStatutFilterProvider);

    // Ordre intentionnel : En attente en premier (cas le plus fréquent)
    final options = <DemandeWebStatut?, String>{
      null: 'Toutes',
      DemandeWebStatut.enAttente: 'En attente',
      DemandeWebStatut.approuve: 'Approuvées',
      DemandeWebStatut.rejete: 'Rejetées',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: options.entries.map((e) {
          final isSelected = selected == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(e.value),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(webDemandesStatutFilterProvider.notifier).state =
                      e.key,
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color:
                    isSelected ? AppColors.primary : Colors.grey.shade700,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Liste
// ─────────────────────────────────────────────────────────────────────────────

class _DemandesListView extends ConsumerWidget {
  const _DemandesListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demandesAsync = ref.watch(webDemandesFiltreesProvider);

    return demandesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) {
        debugPrint('Erreur web_demandes: $err\n$stack');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.red),
              const SizedBox(height: 12),
              Text('Erreur de synchronisation',
                  style: AppTextStyles.bodySecondary),
              const SizedBox(height: 4),
              Text(err.toString(),
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(webDemandesListProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        );
      },
      data: (demandes) {
        if (demandes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_done_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('Aucune demande trouvée',
                    style: AppTextStyles.bodySecondary),
                const SizedBox(height: 8),
                Text('Essayez de modifier les filtres',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade400)),
                const SizedBox(height: 20),
                // Bouton diagnostic RLS — utile si 0 résultats suspects
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(webDemandesRepositoryProvider)
                        .diagnosticRLS();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              '🔍 Logs de diagnostic écrits dans la console Flutter'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.bug_report_outlined, size: 18),
                  label: const Text('Diagnostic RLS (console)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(webDemandesListProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: demandes.length,
            itemBuilder: (context, index) =>
                _DemandeCard(demande: demandes[index]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte demande
// ─────────────────────────────────────────────────────────────────────────────

class _DemandeCard extends StatelessWidget {
  final WebDemande demande;
  const _DemandeCard({required this.demande});

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(demande.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: demande.statut == DemandeWebStatut.enAttente
              ? Colors.orange.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.12),
          child:
              Icon(_typeIcon(demande.type), color: typeColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                demande.clientFullName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87),
              ),
            ),
            // Badge "Anonyme" si pas de fiche client liée
            if (!demande.hasClient)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Anonyme',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(demande.typeLabel,
                style: TextStyle(fontSize: 12, color: typeColor)),
            Row(
              children: [
                Text(_formatDate(demande.createdAt),
                    style: AppTextStyles.bodySecondary),
                const SizedBox(width: 8),
                _StatutBadge(statut: demande.statut),
              ],
            ),
          ],
        ),
        children: [_DemandeDetail(demande: demande)],
      ),
    );
  }

  Color _typeColor(DemandeWebType type) => switch (type) {
        DemandeWebType.location => AppColors.primary,
        DemandeWebType.propositionVente => AppColors.secondary,
        DemandeWebType.demandeDevis => Colors.purple,
      };

  IconData _typeIcon(DemandeWebType type) => switch (type) {
        DemandeWebType.location => Icons.car_rental,
        DemandeWebType.propositionVente => Icons.handshake_outlined,
        DemandeWebType.demandeDevis => Icons.request_quote_outlined,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Détail de la demande
// ─────────────────────────────────────────────────────────────────────────────

class _DemandeDetail extends StatelessWidget {
  final WebDemande demande;
  const _DemandeDetail({required this.demande});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),

          // ── Contact ──────────────────────────────────────────────────────
          if (demande.telephone != null)
            _InfoRowTappable(
              icon: Icons.phone_outlined,
              label: 'Téléphone',
              value: demande.telephone!,
              onTap: () => _callPhone(demande.telephone!),
              trailing: IconButton(
                icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                tooltip: 'Copier',
                onPressed: () =>
                    _copyToClipboard(context, demande.telephone!),
              ),
            ),

          if (demande.message != null && demande.message!.isNotEmpty)
            _InfoRow(
              icon: Icons.message_outlined,
              label: 'Message',
              value: demande.message!,
            ),

          // ── Détails selon le type ─────────────────────────────────────────
          ..._buildTypeDetails(context),

          const SizedBox(height: 12),

          // ── Boutons d'action ─────────────────────────────────────────────
          _ActionButtons(demande: demande),
        ],
      ),
    );
  }

  List<Widget> _buildTypeDetails(BuildContext context) {
    return switch (demande.type) {
      // ── Location ────────────────────────────────────────────────────────
      DemandeWebType.location => [
          // Véhicule : affiche marque/modèle/immat si disponible, sinon l'UUID
          if (demande.vehiculeMarque != null || demande.vehiculeImmat != null)
            _InfoRow(
              icon: Icons.directions_car_outlined,
              label: 'Véhicule',
              value: [
                if (demande.vehiculeMarque != null) demande.vehiculeMarque!,
                if (demande.vehiculeModele != null) demande.vehiculeModele!,
                if (demande.vehiculeImmat != null)
                  '(${demande.vehiculeImmat})',
              ].join(' '),
            )
          else if (demande.vehiculeId != null)
            _InfoRow(
              icon: Icons.directions_car_outlined,
              label: 'Véhicule ID',
              value: demande.vehiculeId!,
            ),

          if (demande.dateDebut != null)
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Période',
              value:
                  '${_formatDate(demande.dateDebut)} → ${_formatDate(demande.dateFin)}'
                  '${demande.nbJours != null ? "  (${demande.nbJours} j)" : ""}',
            ),

          // Montant : calculé automatiquement si non fourni par le web
          if (demande.montantEstimeCalcule != null)
            _InfoRow(
              icon: Icons.payments_outlined,
              label: demande.montantEstime != null
                  ? 'Montant estimé'
                  : 'Montant calculé',
              value: '${_fmt(demande.montantEstimeCalcule!)} DA',
            ),
        ],

      // ── Proposition de vente ─────────────────────────────────────────────
      DemandeWebType.propositionVente => [
          if (demande.propMarque != null || demande.propModele != null)
            _InfoRow(
              icon: Icons.directions_car_outlined,
              label: 'Véhicule proposé',
              value:
                  '${demande.propMarque ?? ""} ${demande.propModele ?? ""}'
                      .trim(),
            ),
          if (demande.propAnnee != null)
            _InfoRow(
              icon: Icons.date_range_outlined,
              label: 'Année',
              value: demande.propAnnee!.toString(),
            ),
          if (demande.propKm != null)
            _InfoRow(
              icon: Icons.speed_outlined,
              label: 'Kilométrage',
              value: '${_fmtInt(demande.propKm!)} km',
            ),
          if (demande.propPrixDemande != null)
            _InfoRow(
              icon: Icons.sell_outlined,
              label: 'Prix souhaité',
              value: '${_fmt(demande.propPrixDemande!)} DA',
            ),
          // Photos de la proposition
          if (demande.propPhotos.isNotEmpty)
            _PhotosRow(photos: demande.propPhotos),
        ],

      // ── Demande de devis ─────────────────────────────────────────────────
      DemandeWebType.demandeDevis => [
          if (demande.devisType != null)
            _InfoRow(
              icon: Icons.category_outlined,
              label: 'Type',
              value: _devisTypeLabel(demande.devisType!),
            ),
          if (demande.vehiculeMarque != null || demande.vehiculeImmat != null)
            _InfoRow(
              icon: Icons.directions_car_outlined,
              label: 'Véhicule ciblé',
              value: [
                if (demande.vehiculeMarque != null) demande.vehiculeMarque!,
                if (demande.vehiculeModele != null) demande.vehiculeModele!,
                if (demande.vehiculeImmat != null)
                  '(${demande.vehiculeImmat})',
              ].join(' '),
            )
          else if (demande.vehiculeId != null)
            _InfoRow(
              icon: Icons.directions_car_outlined,
              label: 'Véhicule ciblé',
              value: demande.vehiculeId!,
            ),
          if (demande.vehiculePrixLocation != null)
            _InfoRow(
              icon: Icons.sell_outlined,
              label: 'Prix catalogue',
              value: '${_fmt(demande.vehiculePrixLocation!)} DA',
            ),
          if (demande.budgetMax != null)
            _InfoRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Budget max',
              value: '${_fmt(demande.budgetMax!)} DA',
            ),
        ],
    };
  }

  String _devisTypeLabel(DevisType t) => switch (t) {
        DevisType.achat => 'Achat de véhicule',
        DevisType.echange => 'Échange de véhicule',
        DevisType.devis => 'Demande de devis',
      };

  void _callPhone(String phone) {
    // Dans un vrai projet : url_launcher -> tel:$phone
    // launch('tel:$phone');
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Téléphone copié'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  static String _fmtInt(int v) => v
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ─────────────────────────────────────────────────────────────────────────────
// Boutons d'action
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  final WebDemande demande;
  const _ActionButtons({required this.demande});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Demande déjà traitée : affiche uniquement Supprimer
    if (demande.statut != DemandeWebStatut.enAttente) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline,
                color: Colors.red, size: 18),
            label: const Text('Supprimer',
                style: TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ],
      );
    }

    // Demande en attente : Rejeter + action principale selon le type
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bouton de conversion contextuel (si en attente)
        if (demande.type == DemandeWebType.location)
          _ConvertirLocationButton(demande: demande)
        else if (demande.type == DemandeWebType.propositionVente)
          _ConvertirRepriseButton(demande: demande),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Rejeter
            TextButton.icon(
              onPressed: () => _confirmAction(
                context,
                ref,
                statut: DemandeWebStatut.rejete,
                label: 'Rejeter',
                message: 'Confirmer le rejet de cette demande ?',
                color: AppColors.retard,
              ),
              icon:
                  const Icon(Icons.cancel_outlined, color: AppColors.retard),
              label: const Text('Rejeter',
                  style: TextStyle(color: AppColors.retard)),
            ),
            const SizedBox(width: 8),
            // Approuver (simple changement de statut)
            ElevatedButton.icon(
              onPressed: () => _confirmAction(
                context,
                ref,
                statut: DemandeWebStatut.approuve,
                label: 'Approuver',
                message:
                    "Confirmer l'approbation de cette demande ?",
                color: Colors.green,
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Approuver'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmAction(
    BuildContext context,
    WidgetRef ref, {
    required DemandeWebStatut statut,
    required String label,
    required String message,
    required Color color,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(label, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(webDemandesRepositoryProvider)
          .updateStatut(demande.id, demande.type, statut);
      ref.invalidate(webDemandesListProvider);

      if (context.mounted) {
        final verb =
            statut == DemandeWebStatut.approuve ? 'approuvée' : 'rejetée';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Demande $verb avec succès.'),
          backgroundColor: statut == DemandeWebStatut.approuve
              ? Colors.green
              : AppColors.retard,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.retard,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la demande'),
        content:
            const Text('Cette action est irréversible. Confirmer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(webDemandesRepositoryProvider)
          .deleteDemande(demande.id, demande.type);
      ref.invalidate(webDemandesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Demande supprimée.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur suppression : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton "Convertir en Location"
// ─────────────────────────────────────────────────────────────────────────────

class _ConvertirLocationButton extends ConsumerWidget {
  final WebDemande demande;
  const _ConvertirLocationButton({required this.demande});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => _convertir(context, ref),
      icon: const Icon(Icons.car_rental, size: 18),
      label: const Text('Convertir en Location'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Future<void> _convertir(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Créer la location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Cette action va créer une location depuis cette réservation web.'),
            const SizedBox(height: 8),
            if (demande.vehiculeId == null)
              const Text(
                '⚠️ Aucun véhicule associé — la location ne peut pas être créée.',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            if (demande.vehiculeId != null)
              Text(
                'Véhicule : ${[demande.vehiculeMarque, demande.vehiculeModele].whereType<String>().join(" ")}\n'
                'Période : ${_formatDate(demande.dateDebut)} → ${_formatDate(demande.dateFin)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          if (demande.vehiculeId != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Créer la location',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(webDemandesRepositoryProvider)
          .convertirEnLocation(demande);
      ref.invalidate(webDemandesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Location créée avec succès !'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur conversion : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton "Convertir en Reprise Stock"
// ─────────────────────────────────────────────────────────────────────────────

class _ConvertirRepriseButton extends ConsumerWidget {
  final WebDemande demande;
  const _ConvertirRepriseButton({required this.demande});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => _convertir(context, ref),
      icon: const Icon(Icons.add_box_outlined, size: 18),
      label: const Text('Ajouter au Stock'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.secondary,
        side: const BorderSide(color: AppColors.secondary),
      ),
    );
  }

  Future<void> _convertir(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter au stock'),
        content: Text(
          'Ajouter le véhicule proposé '
          '(${[demande.propMarque, demande.propModele].whereType<String>().join(" ")}) '
          'à votre stock de véhicules ?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ajouter au stock',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(webDemandesRepositoryProvider)
          .convertirEnVehiculeStock(demande);
      ref.invalidate(webDemandesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Véhicule ajouté au stock !'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets utilitaires
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style:
                    const TextStyle(color: Colors.black87, fontSize: 13),
                children: [
                  TextSpan(
                      text: '$label : ',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// InfoRow avec action au tap + widget trailing (ex: bouton copier)
class _InfoRowTappable extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _InfoRowTappable({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      color: Colors.black87, fontSize: 13),
                  children: [
                    TextSpan(
                        text: '$label : ',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(
                      text: value,
                      style: onTap != null
                          ? const TextStyle(
                              color: AppColors.primary,
                              decoration: TextDecoration.underline)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final DemandeWebStatut statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (statut) {
      DemandeWebStatut.enAttente => (Colors.orange, 'En attente'),
      DemandeWebStatut.approuve => (Colors.green, 'Approuvé'),
      DemandeWebStatut.rejete => (Colors.red, 'Rejeté'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold)),
    );
  }
}

/// Galerie miniature des photos d'une proposition de vente
class _PhotosRow extends StatelessWidget {
  final List<String> photos;
  const _PhotosRow({required this.photos});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text('Photos (${photos.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 13)),
            ],
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () => _showFullImage(context, photos[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photos[i],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image,
                          color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Photo'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper global
// ─────────────────────────────────────────────────────────────────────────────

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}