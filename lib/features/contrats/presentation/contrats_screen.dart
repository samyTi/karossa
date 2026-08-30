// lib/features/contrats/presentation/contrats_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Core
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import 'dart:typed_data';
import '../../../../core/services/pdf/contrat_orchestrator.dart';
import '../../../../core/services/pdf/vehicle_schema_pdf_renderer.dart';
import '../domain/contrat_location_dto.dart' show ContratLocationTemplate;
import 'widgets/contrat_location_template_picker.dart';
import 'contrats_provider.dart' show contratLocationChampsProvider;
import '../../auth/presentation/auth_provider.dart';
import '../../admin/presentation/showroom_settings_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

// ── Providers (avec filtre showroom_id) ─────────────────────────────────────

final _contratsLocationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client     = ref.watch(supabaseClientProvider);
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null) return [];

  // ⚠️ FIX : ce select ne renvoyait que prenom/nom/telephone et
  // marque/modele/immatriculation. Résultat : quand un contrat de location
  // est régénéré depuis cet écran (Contrats → Locations), ContratLocationDto
  // recevait client['adresse'], client['num_permis'], client['num_cni'],
  // vehicule['couleur'], vehicule['carburant'], vehicule['boite'] et
  // vehicule['etat_vehicule'] tous à null → champs vides sur le contrat,
  // en français comme en arabe. On aligne le select sur tout ce que
  // _buildLocationDto (contrat_orchestrator.dart) lit réellement.
  final data = await client
      .from('locations')
      .select(
        '*, '
        'vehicules(marque, modele, immatriculation, couleur, carburant, boite, etat_vehicule, assurance, code_radio), '
        'clients(prenom, nom, telephone, email, adresse, num_permis, permis_date, num_cni, date_naissance)',
      )
      .eq('showroom_id', showroomId)
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _contratsVentesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client     = ref.watch(supabaseClientProvider);
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null) return [];

  final data = await client
      .from('ventes')
      .select('*, vehicules(marque, modele, immatriculation, annee, couleur, carburant, boite, kilometrage, num_chassis, etat_vehicule), clients(prenom, nom, telephone, email, adresse, num_permis, num_cni, statut, created_at)')
      .eq('showroom_id', showroomId)
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _contratsEchangesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client     = ref.watch(supabaseClientProvider);
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null) return [];

  final data = await client
      .from('echanges')
      .select(
        '*, vehicules!echanges_vehicule_cede_id_fkey(marque, modele, annee, immatriculation, couleur, carburant, boite), '
        'clients(prenom, nom, telephone, adresse, num_cni)',
      )
      .eq('showroom_id', showroomId)
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(data);
});

// ── Helper Settings ──────────────────────────────────────────────────────────

Future<Map<String, dynamic>> _fetchSettings(WidgetRef ref) async {
  final s = await ref.read(showroomSettingsTypedProvider.future);
  return {
    'nom':     s.nom,
    'adresse': s.adresse ?? '',
    'tel':     s.tel ?? '',
    'email':   s.email ?? '',
    'rc':      s.rc ?? '',
    'logo_url': s.logoUrl ?? '',
  };
}

// ── Snackbar helpers ─────────────────────────────────────────────────────────

void _showLoadingSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const SizedBox(
        width: 18, height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Text(message),
    ]),
    duration: const Duration(seconds: 30),
  ));
}

void _showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
      const SizedBox(width: 12),
      Text(message),
    ]),
    backgroundColor: AppColors.success,
    duration: const Duration(seconds: 3),
  ));
}

void _showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: AppColors.error,
    duration: const Duration(seconds: 4),
  ));
}

// ── Types ────────────────────────────────────────────────────────────────────

enum _ContratType { location, vente, echange }

extension _ContratTypeExt on _ContratType {
  String get label => switch (this) {
    _ContratType.location => 'Locations',
    _ContratType.vente    => 'Ventes',
    _ContratType.echange  => 'Échanges',
  };
  IconData get icon => switch (this) {
    _ContratType.location => Icons.key_outlined,
    _ContratType.vente    => Icons.sell_outlined,
    _ContratType.echange  => Icons.swap_horiz,
  };
  Color get color => switch (this) {
    _ContratType.location => AppColors.primary,
    _ContratType.vente    => AppColors.secondary,
    _ContratType.echange  => AppColors.reserve,
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
        title: Text(context.l10n.titreContrats, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: _ContratType.values
              .map((t) => Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t.icon, size: 16),
                        const SizedBox(width: 6),
                        Text(t.label),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _LocationsTab(),
          _VentesTab(),
          _EchangesTab(),
        ],
      ),
    );
  }
}

// ── Tabs ─────────────────────────────────────────────────────────────────────

class _LocationsTab extends ConsumerWidget {
  const _LocationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_contratsLocationsProvider).when(
      loading: () => const _LoadingList(),
      error:   (e, _) => _ErrorState(message: e.toString()),
      data: (list) => list.isEmpty
          ? _EmptyState(message: context.l10n.aucuneLocationTrouvee)
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) => _ContratTile(
                type: _ContratType.location,
                data: list[i],
                onGeneratePdf: () async {
                  final template = await showContratLocationTemplatePicker(context);
                  if (template == null) return; // annulé par l'utilisateur
                  if (!context.mounted) return;
                  _showLoadingSnack(context, 'Génération en cours...');
                  try {
                    final orchestrator = ContratOrchestrator(
                      () => _fetchSettings(ref),
                      supabase:   ref.read(supabaseClientProvider),
                      showroomId: ref.read(currentShowroomIdProvider) ?? '',
                    );
                    //final orchestrator = ContratOrchestrator(() => _fetchSettings(ref));
                    // Pré-chargement blueprint pour Flutter Web
                    Uint8List? blueprintBytes;
                    try {
                      blueprintBytes = await VehicleSchemaPdfRenderer.loadBlueprintBytes();
                    } catch (_) {}
                    final locationDataWithBlueprint = {
                      ...list[i],
                      if (blueprintBytes != null) 'blueprint_bytes': blueprintBytes,
                    };
                    final champs = await ref.read(contratLocationChampsProvider.future);
                    await orchestrator.generateAndShareLocation(
                      locationData: locationDataWithBlueprint,
                      template: template,
                      champs: champs,
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
                },
              ),
            ),
    );
  }
}

class _VentesTab extends ConsumerWidget {
  const _VentesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_contratsVentesProvider).when(
      loading: () => const _LoadingList(),
      error:   (e, _) => _ErrorState(message: e.toString()),
      data: (list) => list.isEmpty
          ? _EmptyState(message: context.l10n.aucuneVenteTrouvee)
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) => _ContratTile(
                type: _ContratType.vente,
                data: list[i],
                // CORRECTION : on utilise generateAndShareVenteFromMap
                // au lieu de passer des Maps comme objets typés.
                onGeneratePdf: () async {
                  _showLoadingSnack(context, 'Génération en cours...');
                  try {
                    final orchestrator = ContratOrchestrator(
                      () => _fetchSettings(ref),
                      supabase:   ref.read(supabaseClientProvider),
                      showroomId: ref.read(currentShowroomIdProvider) ?? '',
                    );
                    //final orchestrator = ContratOrchestrator(() => _fetchSettings(ref));
                    await orchestrator.generateAndShareVenteFromMap(
                      venteMap: list[i],
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
                },
              ),
            ),
    );
  }
}

class _EchangesTab extends ConsumerWidget {
  const _EchangesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_contratsEchangesProvider).when(
      loading: () => const _LoadingList(),
      error:   (e, _) => _ErrorState(message: e.toString()),
      data: (list) => list.isEmpty
          ? _EmptyState(message: context.l10n.aucunEchangeTrouve)
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) => _ContratTile(
                type: _ContratType.echange,
                data: list[i],
                onGeneratePdf: () async {
                  _showLoadingSnack(context, 'Génération en cours...');
                  try {
                    final orchestrator = ContratOrchestrator(
                      () => _fetchSettings(ref),
                      supabase:   ref.read(supabaseClientProvider),
                      showroomId: ref.read(currentShowroomIdProvider) ?? '',
                    );
                    //final orchestrator = ContratOrchestrator(() => _fetchSettings(ref));
                    await orchestrator.generateAndShareEchange(
                      echangeData: list[i],
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
                },
              ),
            ),
    );
  }
}

// ── Composants partagés ──────────────────────────────────────────────────────

class _ContratTile extends StatelessWidget {
  const _ContratTile({
    required this.type,
    required this.data,
    required this.onGeneratePdf,
  });

  final _ContratType            type;
  final Map<String, dynamic>    data;
  final Future<void> Function() onGeneratePdf;

  @override
  Widget build(BuildContext context) {
    final client   = data['clients']   as Map<String, dynamic>?;
    final vehicule = data['vehicules'] as Map<String, dynamic>?;

    final clientNom = client != null
        ? '${client['prenom'] ?? ''} ${client['nom'] ?? ''}'.trim()
        : 'Client inconnu';

    final vehiculeInfos = vehicule != null
        ? '${vehicule['marque'] ?? ''} ${vehicule['modele'] ?? ''}'.trim()
        : 'Véhicule inconnu';

    final dateStr = data['created_at'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(data['created_at']))
        : '';

    final hasPdf = (data['contrat_pdf_url'] as String?)?.isNotEmpty == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: type.color.withOpacity(0.1),
          child: Icon(type.icon, color: type.color, size: 20),
        ),
        title: Text(
          clientNom,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('$vehiculeInfos • $dateStr'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPdf)
              const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 16),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: context.l10n.genererLeContratPdf,
              onPressed: onGeneratePdf,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: 6,
        itemBuilder: (_, __) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.black12),
            title: Container(height: 14, color: Colors.black12),
            subtitle: Container(height: 11, color: Colors.black12),
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error)),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
}