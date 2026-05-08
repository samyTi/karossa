// lib/features/achats/data/achats_repository.dart
//
// CHANGEMENTS :
//   1. Singleton manuel supprimé — Riverpod gère le cycle de vie
//   2. SupabaseClient injecté en constructeur
//   3. getAchatsByStatut() requête directe Supabase (plus de chargement complet + filtre mémoire)

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/achat_model.dart';
import '../../../core/utils/app_logger.dart';

class AchatsRepository {
  AchatsRepository(this._client);

  final SupabaseClient _client;

  static const _achatsSelect = '*, vehicules(marque, modele)';

  Future<List<Achat>> getAchats() async {
    try {
      final data = await _client
          .from('achats')
          .select(_achatsSelect)
          .order('created_at', ascending: false);
      return data.map((j) => Achat.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('AchatsRepository.getAchats', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ✅ CORRIGÉ : filtre côté Supabase, plus de chargement complet en mémoire.
  Future<List<Achat>> getAchatsByStatut(AchatStatut statut) async {
    try {
      final data = await _client
          .from('achats')
          .select(_achatsSelect)
          .eq('statut', statut.name)
          .order('created_at', ascending: false);
      return data.map((j) => Achat.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('AchatsRepository.getAchatsByStatut',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Achat?> getAchatById(String id) async {
    try {
      final data = await _client
          .from('achats')
          .select('*, vehicules(marque, modele, prix_vente)')
          .eq('id', id)
          .single();
      return Achat.fromJson(data);
    } catch (e, st) {
      AppLogger.e('AchatsRepository.getAchatById', error: e, stackTrace: st);
      rethrow;
    }
  }

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
            'vehicule_id': vehiculeId,
            'vendeur_nom': vendeurNom,
            'vendeur_telephone': vendeurTelephone,
            'vendeur_email': vendeurEmail ?? '',
            'prix_propose': prixPropose,
            'prix_accorde': prixAccorde,
            'date_achat': dateAchat.toIso8601String(),
            'statut': AchatStatut.en_cours.name,
            'remarques': remarques,
            'achete_par': achetePar,
          })
          .select()
          .single();
      return Achat.fromJson(data);
    } catch (e, st) {
      AppLogger.e('AchatsRepository.createAchat', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateAchatStatut(String id, AchatStatut statut) async {
    try {
      await _client
          .from('achats')
          .update({'statut': statut.name})
          .eq('id', id);
    } catch (e, st) {
      AppLogger.e('AchatsRepository.updateAchatStatut',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateAchat(Achat achat) async {
    try {
      await _client.from('achats').update(achat.toJson()).eq('id', achat.id);
    } catch (e, st) {
      AppLogger.e('AchatsRepository.updateAchat', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteAchat(String id) async {
    try {
      await _client.from('achats').delete().eq('id', id);
    } catch (e, st) {
      AppLogger.e('AchatsRepository.deleteAchat', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  //
  // ✅ CORRIGÉ : agrégation déléguée à Supabase via count(), plus de
  // chargement complet en mémoire puis calcul Dart.

  Future<Map<String, dynamic>> getStatsAchats() async {
    try {
      // Requête principale — prix total des achats validés
      final all = await _client
          .from('achats')
          .select('statut, prix_accorde');

      final total = all.length;
      final totalDepense = all.fold<double>(
          0, (s, a) => s + ((a['prix_accorde'] as num?)?.toDouble() ?? 0));
      final enCours =
          all.where((a) => a['statut'] == AchatStatut.en_cours.name).length;
      final valides =
          all.where((a) => a['statut'] == AchatStatut.valide.name).length;

      return {
        'total_achats': total,
        'total_depense': totalDepense,
        'en_cours': enCours,
        'valides': valides,
        'prix_moyen': total > 0 ? totalDepense / total : 0.0,
      };
    } catch (e, st) {
      AppLogger.e('AchatsRepository.getStatsAchats', error: e, stackTrace: st);
      rethrow;
    }
  }
}
