// lib/features/achats/data/achats_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/achat_model.dart';
import '../../../core/utils/app_logger.dart';

class AchatsRepository {
  AchatsRepository(this._client, {required this.showroomId});

  final SupabaseClient _client;
  final String showroomId;

  static const _achatsSelect = '*, vehicules(marque, modele)';

  // ── Lecture ────────────────────────────────────────────────────────────────

  Future<List<Achat>> getAchats() async {
    try {
      final data = await _client
          .from('achats')
          .select(_achatsSelect)
          .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
          .order('created_at', ascending: false);
      return data.map((j) => Achat.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('AchatsRepository.getAchats', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Achat>> getAchatsByStatut(AchatStatut statut) async {
    try {
      final data = await _client
          .from('achats')
          .select(_achatsSelect)
          .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
          .eq('statut', statut.name)
          .order('created_at', ascending: false);
      return data.map((j) => Achat.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('AchatsRepository.getAchatsByStatut', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Achat?> getAchatById(String id) async {
    try {
      final data = await _client
          .from('achats')
          .select('*, vehicules(marque, modele, prix_vente)')
          .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
          .eq('id', id)
          .single();
      return Achat.fromJson(data);
    } catch (e, st) {
      AppLogger.e('AchatsRepository.getAchatById', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Création ───────────────────────────────────────────────────────────────

  Future<Achat?> createAchat({
    required String vehiculeId,
    required String vendeurNom,
    required String vendeurTelephone,
    String? vendeurEmail,
    required double prixPropose,
    required double prixAccorde,
    required DateTime dateAchat,
    String? remarques,
    required String achetePar,
  }) async {
    try {
      final data = await _client
          .from('achats')
          .insert({
            'showroom_id':       showroomId,
            'vehicule_id':       vehiculeId,
            'vendeur_nom':       vendeurNom,
            'vendeur_telephone': vendeurTelephone,
            'vendeur_email':     vendeurEmail ?? '',
            'prix_propose':      prixPropose,
            'prix_accorde':      prixAccorde,
            'date_achat':        dateAchat.toIso8601String().substring(0, 10),
            'statut':            AchatStatut.en_cours.name,
            'remarques':         remarques,
            'achete_par':        achetePar,
          })
          .select()
          .single();
      return Achat.fromJson(data);
    } catch (e, st) {
      AppLogger.e('AchatsRepository.createAchat', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Mise à jour ────────────────────────────────────────────────────────────

  Future<void> updateAchatStatut(String id, AchatStatut statut) async {
    try {
      await _client
          .from('achats')
          .update({'statut': statut.name})
          .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
          .eq('id', id);
    } catch (e, st) {
      AppLogger.e('AchatsRepository.updateAchatStatut', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateAchat(Achat achat) async {
    try {
      // On retire 'id' et 'created_at' du payload pour ne pas les écraser
      final payload = achat.toJson()
        ..remove('id')
        ..remove('created_at')
        ..['showroom_id'] = showroomId;

      await _client
          .from('achats')
          .update(payload)
          .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
          .eq('id', achat.id);
    } catch (e, st) {
      AppLogger.e('AchatsRepository.updateAchat', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Suppression ────────────────────────────────────────────────────────────

  Future<void> deleteAchat(String id) async {
    try {
      await _client
          .from('achats')
          .delete()
          .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
          .eq('id', id);
    } catch (e, st) {
      AppLogger.e('AchatsRepository.deleteAchat', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStatsAchats() async {
    try {
      final all = await _client
          .from('achats')
          .select('statut, prix_accorde')
          .eq('showroom_id', showroomId); // ✅ filtre multi-tenant

      final total        = all.length;
      final totalDepense = all.fold<double>(
          0, (s, a) => s + ((a['prix_accorde'] as num?)?.toDouble() ?? 0));
      final enCours = all.where((a) => a['statut'] == AchatStatut.en_cours.name).length;
      final valides = all.where((a) => a['statut'] == AchatStatut.valide.name).length;

      return {
        'total_achats':  total,
        'total_depense': totalDepense,
        'en_cours':      enCours,
        'valides':       valides,
        'prix_moyen':    total > 0 ? totalDepense / total : 0.0,
      };
    } catch (e, st) {
      AppLogger.e('AchatsRepository.getStatsAchats', error: e, stackTrace: st);
      rethrow;
    }
  }
}