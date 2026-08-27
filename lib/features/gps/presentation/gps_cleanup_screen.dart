// lib/features/gps/presentation/gps_cleanup_screen.dart
//
// ★ NOUVEAU — Nettoyage / rétention de l'historique GPS (gps_positions)
//   • Réservé au gérant / propriétaire (vérifié côté serveur ET côté client)
//   • Deux modes :
//       - Suppression totale sur un intervalle
//       - Décimation : ne garder qu'1 point toutes les X minutes
//   • S'applique à un véhicule précis ou à toute la flotte du showroom.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../auth/presentation/auth_provider.dart';
import 'gps_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

// ── Autorisation ───────────────────────────────────────────────────────────

/// Vrai si l'utilisateur connecté peut purger l'historique GPS (gérant
/// uniquement — un profil "externe" est en lecture seule). Interrogé
/// directement en base — indépendant du provider de profil utilisé ailleurs
/// dans l'appli, pour rester autonome.
final gpsCleanupAllowedProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return false;
  try {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    final role = row?['role'] as String?;
    return role == 'gerant';
  } catch (_) {
    return false;
  }
});

// ── Liste des véhicules GPS du showroom (pour le sélecteur) ───────────────

class _VehiculeOption {
  final String id;
  final String label;
  const _VehiculeOption(this.id, this.label);
}

final _cleanupVehiculesProvider =
    FutureProvider.autoDispose<List<_VehiculeOption>>((ref) async {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) return [];
  final rows = await Supabase.instance.client
      .from('vehicules')
      .select('id, marque, modele, immatriculation')
      .eq('showroom_id', showroomId)
      .not('flespi_device_id', 'is', null);
  return (rows as List<dynamic>)
      .map((r) => _VehiculeOption(
            r['id'] as String,
            '${r['marque']} ${r['modele']} (${r['immatriculation'] ?? '—'})',
          ))
      .toList();
});

enum _CleanupMode { deleteAll, decimate }

const List<(int, String)> kDecimationIntervals = [
  (5, '1 point / 5 min'),
  (15, '1 point / 15 min'),
  (30, '1 point / 30 min'),
  (60, '1 point / 1 heure'),
  (180, '1 point / 3 heures'),
  (360, '1 point / 6 heures'),
  (720, '1 point / 12 heures'),
  (1440, '1 point / 24 heures'),
];

class GpsCleanupScreen extends ConsumerStatefulWidget {
  const GpsCleanupScreen({super.key});

  @override
  ConsumerState<GpsCleanupScreen> createState() => _GpsCleanupScreenState();
}

class _GpsCleanupScreenState extends ConsumerState<GpsCleanupScreen> {
  String? _vehiculeId; // null = toute la flotte
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to   = DateTime.now();
  _CleanupMode _mode = _CleanupMode.decimate;
  int _intervalMinutes = 60;
  bool _busy = false;

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      locale: const Locale('fr'),
    );
    if (range == null) return;
    setState(() {
      _from = DateTime(range.start.year, range.start.month, range.start.day);
      _to   = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
    });
  }

  Future<void> _confirmAndRun() async {
    final isDelete = _mode == _CleanupMode.deleteAll;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isDelete 
          ? context.l10n.supprimerDefinitivement 
          : context.l10n.confirmerDecimation
        ),
        content: Text(isDelete
            ? "${context.l10n.tousPointsGpsEntre} "
              "${DateFormat('dd/MM/yyyy').format(_from)} ${context.l10n.etLe} "
              "${DateFormat('dd/MM/yyyy').format(_to)} ${context.l10n.serontSupprimesDefinitivement}"
              "${_vehiculeId == null ? ' ${context.l10n.pourTouteLaFlotte}' : ''}. "
              "${context.l10n.actionIrreversible}"
            : "${context.l10n.surCetIntervalle} "
              "${kDecimationIntervals.firstWhere((e) => e.$1 == _intervalMinutes).$2.replaceFirst('1 point / ', '')}"
              "${_vehiculeId == null ? ' ${context.l10n.pourTouteLaFlotte}' : ''}. "
              "${context.l10n.autresPointsSupprimes}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text(context.l10n.btnAnnuler)
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: isDelete ? AppColors.error : null),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isDelete ? context.l10n.btnSupprimer : context.l10n.decimer),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(gpsRepositoryProvider);
      final deleted = isDelete
          ? await repo.deletePositionsInRange(vehiculeId: _vehiculeId, from: _from, to: _to)
          : await repo.decimatePositions(
              vehiculeId: _vehiculeId, from: _from, to: _to, intervalMinutes: _intervalMinutes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.enregistrementsSupprimes(deleted.toString()))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.erreurAvecDetail(e.toString())), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowedAsync = ref.watch(gpsCleanupAllowedProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: context.l10n.nettoyageHistoriqueGps, 
        showHomeButton: true
      ),
      body: allowedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _AccessDenied(),
        data: (allowed) => allowed ? _buildBody(context) : const _AccessDenied(),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final vehiculesAsync = ref.watch(_cleanupVehiculesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.gpsCleanupInfo,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(context.l10n.vehicule, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        vehiculesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(context.l10n.erreurAvecDetail(e.toString())),
          data: (list) => DropdownButtonFormField<String?>(
            value: _vehiculeId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(context.l10n.touteLaFlotte)),
              ...list.map((v) => DropdownMenuItem(value: v.id, child: Text(v.label))),
            ],
            onChanged: (v) => setState(() => _vehiculeId = v),
          ),
        ),

        const SizedBox(height: 20),
        Text(context.l10n.intervalleDates, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickDateRange,
          icon: const Icon(Icons.date_range),
          label: Text(
            '${DateFormat('dd MMM yyyy', 'fr').format(_from)}  →  '
            '${DateFormat('dd MMM yyyy', 'fr').format(_to)}',
          ),
        ),

        const SizedBox(height: 20),
        Text(context.l10n.action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        RadioListTile<_CleanupMode>(
          contentPadding: EdgeInsets.zero,
          value: _CleanupMode.decimate,
          groupValue: _mode,
          onChanged: (v) => setState(() => _mode = v!),
          title: Text(context.l10n.decimerGarder1Point),
          subtitle: Text(context.l10n.decimerRecommandation),
        ),
        if (_mode == _CleanupMode.decimate)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: DropdownButtonFormField<int>(
              value: _intervalMinutes,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: kDecimationIntervals
                  .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _intervalMinutes = v!),
            ),
          ),
        RadioListTile<_CleanupMode>(
          contentPadding: EdgeInsets.zero,
          value: _CleanupMode.deleteAll,
          groupValue: _mode,
          onChanged: (v) => setState(() => _mode = v!),
          title: Text(context.l10n.supprimerToutIntervalle),
          subtitle: Text(context.l10n.effaceCompletementPeriode),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _confirmAndRun,
            style: FilledButton.styleFrom(
              backgroundColor: _mode == _CleanupMode.deleteAll ? AppColors.error : AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.delete_sweep_rounded),
            label: Text(_mode == _CleanupMode.deleteAll 
              ? context.l10n.btnSupprimer 
              : context.l10n.lancerDecimation
            ),
          ),
        ),
      ],
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            context.l10n.gpsAccessDenied,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}