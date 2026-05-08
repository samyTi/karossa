// lib/features/contrats/presentation/screens/contrats_screen.dart
//
// Écran Contrats — liste les contrats générés (locations, ventes, échanges)
// directement depuis Supabase avec actions PDF.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/contrat_generator_service.dart';
import '../../../locations/domain/location_model.dart';
import '../../../ventes/domain/vente_model.dart';
import '../../../echanges/domain/echange_model.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _contratsLocationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(supabaseClientProvider).from('locations').select(
        '*, vehicules(marque, modele, immatriculation), clients(prenom, nom)',
      ).order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _contratsVentesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(supabaseClientProvider).from('ventes').select(
        '*, vehicules(marque, modele, immatriculation), clients(prenom, nom)',
      ).order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _contratsEchangesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(supabaseClientProvider).from('echanges').select(
        '*, vehicules!echanges_vehicule_cede_id_fkey(marque, modele, immatriculation), clients(prenom, nom)',
      ).order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

// ── Types ────────────────────────────────────────────────────────────────────

enum _ContratType { location, vente, echange }

extension _ContratTypeExt on _ContratType {
  String get label => switch (this) {
        _ContratType.location => 'Locations',
        _ContratType.vente => 'Ventes',
        _ContratType.echange => 'Échanges',
      };
  IconData get icon => switch (this) {
        _ContratType.location => Icons.key_outlined,
        _ContratType.vente => Icons.sell_outlined,
        _ContratType.echange => Icons.swap_horiz,
      };
  Color get color => switch (this) {
        _ContratType.location => AppColors.primary,
        _ContratType.vente => AppColors.secondary,
        _ContratType.echange => AppColors.reserve,
      };
}

// ── Screen ───────────────────────────────────────────────────────────────────

class ContratsScreen extends ConsumerStatefulWidget {
  const ContratsScreen({super.key});

  @override
  ConsumerState<ContratsScreen> createState() => _ContratsScreenState();
}

class _ContratsScreenState extends ConsumerState<ContratsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Contrats',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: _ContratType.values
              .map((t) => Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t.icon, size: 16),
                        const SizedBox(width: 6),
                        Text(t.label,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _LocationsTab(),
          _VentesTab(),
          _EchangesTab(),
        ],
      ),
    );
  }
}

// ── Tab Locations ─────────────────────────────────────────────────────────────

class _LocationsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_contratsLocationsProvider);
    return async.when(
      loading: () => const _LoadingList(),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState(
              icon: Icons.key_outlined, message: 'Aucun contrat de location');
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_contratsLocationsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: list.length,
            itemBuilder: (ctx, i) => _ContratTile(
              type: _ContratType.location,
              data: list[i],
              onGeneratePdf: () => _generateLocationPdf(ctx, ref, list[i]),
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateLocationPdf(
      BuildContext context, WidgetRef ref, Map<String, dynamic> data) async {
    final id = data['id'] as String;
    try {
      _showLoadingSnack(context, 'Génération du contrat…');
      final client = ref.read(supabaseClientProvider);
      // Recharger la location complète avec toutes les jointures
      final full = await client
          .from('locations')
          .select(
              '*, vehicules(marque, modele, annee, couleur, immatriculation, carburant, boite, etat_vehicule, num_chassis),'
              'clients(prenom, nom, telephone, adresse, num_cni, num_permis),'
              'location_repartitions(*, profiles(prenom))')
          .eq('id', id)
          .single();

      final location = Location.fromJson(full);
      await ContratGeneratorService.generateAndShareLocation(
        location: location,
        ref: ref,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSuccessSnack(context, 'Contrat généré avec succès');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showErrorSnack(context, 'Erreur : $e');
      }
    }
  }
}

// ── Tab Ventes ────────────────────────────────────────────────────────────────

class _VentesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_contratsVentesProvider);
    return async.when(
      loading: () => const _LoadingList(),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState(
              icon: Icons.sell_outlined, message: 'Aucun contrat de vente');
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_contratsVentesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: list.length,
            itemBuilder: (ctx, i) => _ContratTile(
              type: _ContratType.vente,
              data: list[i],
              onGeneratePdf: () => _generateVentePdf(ctx, ref, list[i]),
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateVentePdf(
      BuildContext context, WidgetRef ref, Map<String, dynamic> data) async {
    final id = data['id'] as String;
    try {
      _showLoadingSnack(context, 'Génération du contrat…');
      final client = ref.read(supabaseClientProvider);
      final full = await client
          .from('ventes')
          .select(
              '*, vehicules(marque, modele, annee, couleur, immatriculation, carburant, boite, num_chassis),'
              'clients(prenom, nom, telephone, adresse, num_cni),'
              'vente_paiements(id, montant, date_paiement, mode)')
          .eq('id', id)
          .single();

      final vente = Vente.fromJson(full);
      await ContratGeneratorService.generateAndShareVente(
        vente: vente,
        ref: ref,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSuccessSnack(context, 'Contrat généré avec succès');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showErrorSnack(context, 'Erreur : $e');
      }
    }
  }
}

// ── Tab Échanges ──────────────────────────────────────────────────────────────

class _EchangesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_contratsEchangesProvider);
    return async.when(
      loading: () => const _LoadingList(),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState(
              icon: Icons.swap_horiz, message: 'Aucun contrat d\'échange');
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_contratsEchangesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: list.length,
            itemBuilder: (ctx, i) => _ContratTile(
              type: _ContratType.echange,
              data: list[i],
              onGeneratePdf: () => _generateEchangePdf(ctx, ref, list[i]),
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateEchangePdf(
      BuildContext context, WidgetRef ref, Map<String, dynamic> data) async {
    final id = data['id'] as String;
    try {
      _showLoadingSnack(context, 'Génération du contrat…');
      final client = ref.read(supabaseClientProvider);
      final full = await client
          .from('echanges')
          .select(
              '*, vehicules!echanges_vehicule_cede_id_fkey(marque, modele, annee, couleur, immatriculation),'
              'clients(prenom, nom, telephone, adresse, num_cni)')
          .eq('id', id)
          .single();

      final echange = Echange.fromJson(full);
      await ContratGeneratorService.generateAndShareEchange(
        echange: echange,
        ref: ref,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSuccessSnack(context, 'Contrat généré avec succès');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showErrorSnack(context, 'Erreur : $e');
      }
    }
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _ContratTile extends StatelessWidget {
  final _ContratType type;
  final Map<String, dynamic> data;
  final VoidCallback onGeneratePdf;

  const _ContratTile({
    required this.type,
    required this.data,
    required this.onGeneratePdf,
  });

  String get _clientNom {
    final c = data['clients'];
    if (c == null) return 'Client inconnu';
    return '${c['prenom'] ?? ''} ${c['nom'] ?? ''}'.trim();
  }

  String get _vehiculeNom {
    final v = data['vehicules'];
    if (v == null) {
      // échange: nom du véhicule repris en texte
      return '${data['vehicule_reprise_marque'] ?? ''} ${data['vehicule_reprise_modele'] ?? ''}'.trim();
    }
    final immat = v['immatriculation'];
    return '${v['marque'] ?? ''} ${v['modele'] ?? ''}${immat != null ? ' • $immat' : ''}';
  }

  String get _date {
    final raw = data['created_at'] ?? data['date_echange'] ?? data['date_vente'];
    if (raw == null) return '';
    return DateFormat('dd/MM/yyyy', 'fr').format(DateTime.parse(raw));
  }

  String get _montant {
    final fmt = NumberFormat('#,###', 'fr');
    final m = (data['prix_jour'] ?? data['prix_vente'] ?? data['valeur_reprise'] as num?)?.toDouble() ?? 0;
    final suffix = type == _ContratType.location ? '/jour' : '';
    return '${fmt.format(m)} DA$suffix';
  }

  bool get _hasPdf => (data['contrat_pdf_url'] as String?)?.isNotEmpty == true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icône type
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: type.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(type.icon, color: type.color, size: 22),
            ),
            const SizedBox(width: 12),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _clientNom,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _vehiculeNom,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _montant,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: type.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                // Badge contrat existant
                if (_hasPdf)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PDF',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.successDark,
                        ),
                      ),
                    ),
                  ),
                // Bouton génération PDF
                IconButton(
                  icon: Icon(
                    _hasPdf
                        ? Icons.picture_as_pdf
                        : Icons.picture_as_pdf_outlined,
                    color: _hasPdf ? AppColors.success : AppColors.textHint,
                    size: 22,
                  ),
                  tooltip: _hasPdf ? 'Re-générer le PDF' : 'Générer le PDF',
                  onPressed: onGeneratePdf,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $message',
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center),
        ),
      );
}

// ── Snackbars ─────────────────────────────────────────────────────────────────

void _showLoadingSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(msg),
      ]),
      duration: const Duration(seconds: 30),
      backgroundColor: AppColors.primary,
    ),
  );
}

void _showSuccessSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 3),
    ),
  );
}

void _showErrorSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
    ),
  );
}