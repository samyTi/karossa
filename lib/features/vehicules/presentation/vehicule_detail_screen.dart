// lib/features/vehicules/presentation/vehicule_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../shared/widgets/status_badge.dart';
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

// ════════════════════════════════════════════════════════════════════════════
//  BODY PRINCIPAL
// ════════════════════════════════════════════════════════════════════════════

class _Body extends StatelessWidget {
  final Vehicule vehicule;
  final WidgetRef ref;
  const _Body({required this.vehicule, required this.ref});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: CustomScrollView(slivers: [
          // ── AppBar avec galerie photos ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                vehicule.displayName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              background: vehicule.photos.isNotEmpty
                  ? _PhotoGallery(photos: vehicule.photos)
                  : const _NoPhoto(),
            ),
            actions: [
              // Bouton GPS — visible seulement si un boîtier est associé
              if (vehicule.traccarDeviceId != null)
                IconButton(
                  icon: const Icon(Icons.gps_fixed),
                  tooltip: 'Localiser',
                  onPressed: () => context.push(
                    '/gps/map?vehiculeId=${vehicule.id}',
                  ),
                ),
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
                  // ── Statut + actions principales ───────────────────────
                  Row(children: [
                    StatusBadge(statut: vehicule.statut),
                    const Spacer(),
                    if (vehicule.statut == VehiculeStatut.disponible) ...[
                      _ActionBtn(
                        'Louer',
                        Icons.car_rental,
                        AppColors.secondary,
                        () => context.push(
                            '/locations/new?vehiculeId=${vehicule.id}'),
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        'Vendre',
                        Icons.sell_outlined,
                        AppColors.primary,
                        () => context.push(
                            '/ventes/new?vehiculeId=${vehicule.id}'),
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        'Échanger',
                        Icons.swap_horiz,
                        AppColors.accent,
                        () => context.push(
                            '/echanges/new?vehiculeId=${vehicule.id}'),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 16),

                  // ── Boutons IA + Analyse financière ────────────────────
                  _SmartActionsRow(vehicule: vehicule),
                  const SizedBox(height: 20),

                  // ── Caractéristiques ───────────────────────────────────
                  _InfoCard('Caractéristiques', [
                    _InfoRow('Marque / Modèle',
                        '${vehicule.marque} ${vehicule.modele}'),
                    _InfoRow('Année', '${vehicule.annee}'),
                    if (vehicule.couleur != null)
                      _InfoRow('Couleur', vehicule.couleur!),
                    if (vehicule.immatriculation != null)
                      _InfoRow('Immatriculation', vehicule.immatriculation!),
                    if (vehicule.carburant != null)
                      _InfoRow('Carburant', vehicule.carburant!),
                    if (vehicule.boite != null)
                      _InfoRow('Boîte', vehicule.boite!),
                    _InfoRow('Kilométrage', '${vehicule.kilometrage} km'),
                  ]),
                  const SizedBox(height: 12),

                  // ── Tarifs ─────────────────────────────────────────────
                  _InfoCard('Tarifs', [
                    if (vehicule.prixLocationJour != null)
                      _InfoRow(
                        'Location / jour',
                        vehicule.prixLocationJour!.toDA(),
                        color: AppColors.secondary,
                      ),
                    if (vehicule.prixVente != null)
                      _InfoRow(
                        'Prix de vente',
                        vehicule.prixVente!.toDA(),
                        color: AppColors.primary,
                      ),
                    if (vehicule.prixAchat != null)
                      _InfoRow(
                        'Prix d\'achat',
                        vehicule.prixAchat!.toDA(),
                        color: AppColors.textSecondary,
                      ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Propriétaires ──────────────────────────────────────
                  if (vehicule.proprietes.isNotEmpty)
                    _InfoCard(
                      'Propriétaires',
                      vehicule.proprietes
                          .map((p) => _InfoRow(
                                p.proprietaireNom,
                                '${p.partPct.toInt()}%',
                              ))
                          .toList(),
                    ),
                  if (vehicule.proprietes.isNotEmpty)
                    const SizedBox(height: 12),

                  // ── État du véhicule ────────────────────────────────────
                  if (vehicule.etatVehicule != null &&
                      vehicule.etatVehicule!.isNotEmpty) ...[
                    _InfoCard('🔧 État du véhicule (dommages / pannes)', [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          vehicule.etatVehicule!,
                          style: AppTextStyles.body.copyWith(
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                  ],

                  // ── Notes ──────────────────────────────────────────────
                  if (vehicule.notes != null &&
                      vehicule.notes!.isNotEmpty)
                    _InfoCard('Notes', [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(vehicule.notes!,
                            style: AppTextStyles.body),
                      ),
                    ]),
                  if (vehicule.notes != null &&
                      vehicule.notes!.isNotEmpty)
                    const SizedBox(height: 12),

                  // ── Alerte kilométrage ─────────────────────────────────
                  if (vehicule.kmCritique)
                    _KmAlerteWidget(vehicule: vehicule),

                  // ── Action : remettre disponible ───────────────────────
                  if (vehicule.statut == VehiculeStatut.reparation)
                    _MarquerDisponibleBtn(vehicule: vehicule, ref: ref),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  SMART ACTIONS ROW — IA + Analyse financière
// ════════════════════════════════════════════════════════════════════════════

class _SmartActionsRow extends StatelessWidget {
  final Vehicule vehicule;
  const _SmartActionsRow({required this.vehicule});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Analyse financière ─────────────────────────────────────────
        Expanded(
          child: _SmartCard(
            icon: Icons.analytics_outlined,
            label: 'Analyse\nfinancière',
            color: AppColors.accent,
            onTap: () => context.push(
              '/vehicules/${vehicule.id}/financials'
              '?nom=${Uri.encodeComponent(vehicule.displayName)}',
            ),
          ),
        ),
        const SizedBox(width: 10),

        // ── Demander à l'IA ────────────────────────────────────────────
        Expanded(
          child: _SmartCard(
            icon: Icons.auto_awesome_outlined,
            label: 'Demander\nà l\'IA',
            color: AppColors.primary,
            onTap: () => context.push(
              '/ai-chat',
              extra: {
                'vehiculeNom': vehicule.displayName,
                'vehiculeContext': {
                  'marque': vehicule.marque,
                  'modele': vehicule.modele,
                  'annee': vehicule.annee,
                  'kilometrage': vehicule.kilometrage,
                  'statut': vehicule.statut.name,
                  'prix_vente': vehicule.prixVente,
                  'prix_location_jour': vehicule.prixLocationJour,
                  'notes': vehicule.notes,
                },
              },
            ),
          ),
        ),
        const SizedBox(width: 10),

        // ── Contrat PDF ────────────────────────────────────────────────
        Expanded(
          child: _SmartCard(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Contrats\nPDF',
            color: AppColors.secondary,
            onTap: () => context.push(
              '/vehicules/${vehicule.id}/contracts?nom=${Uri.encodeComponent(vehicule.displayName)}',
            ),
          ),
        ),
      ],
    );
  }
}

/// Carte d'action rapide avec icône + libellé
class _SmartCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmartCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GALERIE PHOTOS
// ════════════════════════════════════════════════════════════════════════════

class _PhotoGallery extends StatefulWidget {
  final List<String> photos;
  const _PhotoGallery({required this.photos});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: widget.photos[i],
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const _NoPhoto(),
          ),
        ),
        // Indicateur de pages
        if (widget.photos.length > 1)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photos.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _current == i ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _current == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ALERTE KILOMÉTRAGE
// ════════════════════════════════════════════════════════════════════════════

class _KmAlerteWidget extends StatelessWidget {
  final Vehicule vehicule;
  const _KmAlerteWidget({required this.vehicule});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.reparation.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.reparation.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.reparation, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kilométrage proche du seuil d\'alerte '
              '(${vehicule.kilometrage} / ${vehicule.kmAlerteSeuil} km)',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.reparation,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BOUTON MARQUER DISPONIBLE
// ════════════════════════════════════════════════════════════════════════════

class _MarquerDisponibleBtn extends StatelessWidget {
  final Vehicule vehicule;
  final WidgetRef ref;
  const _MarquerDisponibleBtn(
      {required this.vehicule, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Marquer disponible',
              style: TextStyle(fontWeight: FontWeight.w600)),
          onPressed: () async {
            await ref.read(supabaseClientProvider)
                .from('vehicules')
                .update({'statut': 'disponible'}).eq('id', vehicule.id);
            ref.invalidate(vehiculesProvider);
            ref.invalidate(vehiculeDetailProvider(vehicule.id));
          },
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  WIDGETS UTILITAIRES
// ════════════════════════════════════════════════════════════════════════════

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
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          textStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600),
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
              border:
                  Border.all(color: AppColors.border, width: 0.5),
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
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodySecondary),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.textPrimary,
              ),
            ),
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