// lib/features/finance/data/finance_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';

class FinanceRepository {
  FinanceRepository(this._client, {required this.showroomId});

  final SupabaseClient _client;
  final String showroomId;

  // ── Relevé mensuel d'un associé/propriétaire ───────────────────────────────

  /// Retourne les répartitions de location pour un bénéficiaire sur un mois donné.
  /// Scopé au showroom via le JOIN sur locations → showroom_id.
  Future<List<Map<String, dynamic>>> getRepartitionsMensuelles({
    required String beneficiaireId,
    required int mois,
    required int annee,
  }) async {
    try {
      final debut = DateTime(annee, mois).toIso8601String();
      final fin   = DateTime(annee, mois + 1, 0, 23, 59).toIso8601String();

      final data = await _client
          .from('location_repartitions')
          .select(
            '*, locations('
            '  id, montant_brut, date_debut,'
            '  vehicules(marque, modele)'
            ')',
          )
          .eq('beneficiaire_id', beneficiaireId)
          .gte('created_at', debut)
          .lte('created_at', fin);

      return List<Map<String, dynamic>>.from(data);
    } catch (e, st) {
      AppLogger.e('FinanceRepository.getRepartitionsMensuelles', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Résumé financier global du showroom ────────────────────────────────────

  /// CA brut par catégorie sur une période donnée (depuis caisse_operations).
  Future<Map<String, double>> getResumeParCategorie({
    required DateTime debut,
    required DateTime fin,
  }) async {
    try {
      final data = await _client
          .from('caisse_operations')
          .select('type, categorie, montant')
          .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
          .gte('date_op', debut.toIso8601String().split('T').first)
          .lte('date_op', fin.toIso8601String().split('T').first);

      final Map<String, double> result = {};
      for (final row in data) {
        final key   = '${row['type']}_${row['categorie']}';
        final mnt   = (row['montant'] as num?)?.toDouble() ?? 0;
        result[key] = (result[key] ?? 0) + mnt;
      }
      return result;
    } catch (e, st) {
      AppLogger.e('FinanceRepository.getResumeParCategorie', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Solde de caisse (entrées − sorties) sur une période.
  Future<double> getSolde({
    required DateTime debut,
    required DateTime fin,
  }) async {
    try {
      final data = await _client
          .from('caisse_operations')
          .select('type, montant')
          .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
          .gte('date_op', debut.toIso8601String().split('T').first)
          .lte('date_op', fin.toIso8601String().split('T').first);

      double entrees = 0, sorties = 0;
      for (final row in data) {
        final mnt = (row['montant'] as num?)?.toDouble() ?? 0;
        if (row['type'] == 'entree') {
          entrees += mnt;
        } else {
          sorties += mnt;
        }
      }
      return entrees - sorties;
    } catch (e, st) {
      AppLogger.e('FinanceRepository.getSolde', error: e, stackTrace: st);
      rethrow;
    }
  }
}