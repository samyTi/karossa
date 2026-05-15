// lib/features/vehicules/data/vehicule_financials_repository.dart
// Calcul des marges :
//   - Si BACKEND_URL est défini → appel au backend Next.js
//   - Sinon → calcul direct via Supabase (mode standalone Flutter)

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/backend_api_service.dart';
import '../domain/vehicule_financials.dart';
import '../../../core/utils/app_logger.dart';

class VehiculeFinancialsRepository {
  VehiculeFinancialsRepository(this._client);

  final SupabaseClient _client;


  static const _backendUrl = String.fromEnvironment('BACKEND_URL');
  bool get _useBackend => _backendUrl.isNotEmpty;

  Future<VehiculeFinancials> getFinancials(String vehiculeId) async {
    if (_useBackend) {
      return _getFromBackend(vehiculeId);
    }
    return _getFromSupabase(vehiculeId);
  }

  // ── Via backend Next.js ───────────────────────────────────────────────────
  Future<VehiculeFinancials> _getFromBackend(String vehiculeId) async {
    final data = await BackendApiService(_client).getVehiculeFinancials(vehiculeId);
    if (data == null) {
      throw Exception('Impossible de récupérer les données financières du backend');
    }
    return VehiculeFinancials.fromJson(data);
  }

  // ── Direct Supabase (offline / sans backend) ──────────────────────────────
  Future<VehiculeFinancials> _getFromSupabase(String vehiculeId) async {
    try {
      // Exécution parallèle des requêtes Supabase
      final futureVehicule = _client
          .from('vehicules')
          .select('prix_achat, date_entree, km_alerte_seuil')
          .eq('id', vehiculeId)
          .single();
      final futureReparations = _client
          .from('reparations')
          .select('cout, deductible')
          .eq('vehicule_id', vehiculeId);
      final futureCaisseOps = _client
          .from('caisse_operations')
          .select('montant, categorie')
          .eq('vehicule_id', vehiculeId)
          .eq('type', 'sortie');
      final futureLocations = _client
          .from('locations')
          .select('montant_brut, retenue_caution, date_debut, date_fin_reelle, date_fin_prevue')
          .eq('vehicule_id', vehiculeId)
          .eq('statut', 'termine');
      final futureVentes = _client
          .from('ventes')
          .select('prix_vente')
          .eq('vehicule_id', vehiculeId)
          .limit(1);

      final List<dynamic> results = await Future.wait<dynamic>([
        futureVehicule,
        futureReparations,
        futureCaisseOps,
        futureLocations,
        futureVentes,
      ]);

      final vehiculeData = results[0] as Map<String, dynamic>;
      final reparations  = results[1] as List;
      final caisseOps    = results[2] as List;
      final locations    = results[3] as List;
      final ventes       = results[4] as List;

      final prixAchat = (vehiculeData['prix_achat'] as num?)?.toDouble() ?? 0.0;

      final totalReparations = reparations
          .where((r) => r['deductible'] == true)
          .fold(0.0, (s, r) => s + (r['cout'] as num).toDouble());

      const fraisCats = ['entretien', 'carburant', 'lavage', 'assurance', 'controle_technique'];
      final totalEntretiens = caisseOps
          .where((op) => fraisCats.contains(op['categorie']))
          .fold(0.0, (s, op) => s + (op['montant'] as num).toDouble());

      final totalDepenses = prixAchat + totalReparations + totalEntretiens;

      final revenusLocations = locations.fold(0.0, (s, loc) {
        final brut    = (loc['montant_brut'] as num?)?.toDouble() ?? 0.0;
        final retenue = (loc['retenue_caution'] as num?)?.toDouble() ?? 0.0;
        return s + brut - retenue;
      });

      final revenusVente = ventes.isNotEmpty
          ? (ventes.first['prix_vente'] as num).toDouble() : null;
      final revenusTotal = revenusLocations + (revenusVente ?? 0);

      final margeBrute = revenusTotal - totalDepenses;
      final margePct   = totalDepenses > 0 ? (margeBrute / totalDepenses * 100) : 0.0;

      int joursLoues = 0;
      for (final loc in locations) {
        final debut = DateTime.tryParse(loc['date_debut'] ?? '');
        final fin   = DateTime.tryParse(loc['date_fin_reelle'] ?? loc['date_fin_prevue'] ?? '');
        if (debut != null && fin != null) {
          joursLoues += fin.difference(debut).inDays.abs();
        }
      }

      int joursDepuisEntree = 365;
      final dateEntreeStr = vehiculeData['date_entree'] as String?;
      if (dateEntreeStr != null) {
        final dateEntree = DateTime.tryParse(dateEntreeStr);
        if (dateEntree != null) {
          joursDepuisEntree =
              DateTime.now().difference(dateEntree).inDays.clamp(1, 9999);
        }
      }

      final tauxOccupation =
          ((joursLoues / joursDepuisEntree) * 100).clamp(0, 100).round();
      final revenusParJour = joursLoues > 0 ? revenusLocations / joursLoues : 0.0;

      return VehiculeFinancials(
        vehiculeId:        vehiculeId,
        prixAchat:         prixAchat,
        totalReparations:  totalReparations,
        totalEntretiens:   totalEntretiens,
        totalDepenses:     totalDepenses,
        revenusLocations:  revenusLocations,
        revenusVente:      revenusVente,
        revenusTotal:      revenusTotal,
        margeBrute:        margeBrute,
        margePct:          margePct,
        nbLocations:       locations.length,
        joursLoues:        joursLoues,
        tauxOccupationPct: tauxOccupation,
        revenusParJour:    revenusParJour,
      );
    } catch (e) {
      AppLogger.d('VehiculeFinancialsRepository._getFromSupabase: $e');
      rethrow;
    }
  }
}
