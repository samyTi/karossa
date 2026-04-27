import 'package:flutter/foundation.dart';
import '../../../main.dart';
import '../domain/achat_model.dart';

/// Repository pour la gestion des achats/reprises
class AchatsRepository {
  static final AchatsRepository _instance = AchatsRepository._internal();
  factory AchatsRepository() => _instance;
  AchatsRepository._internal();

  /// Récupérer tous les achats
  Future<List<Achat>> getAchats() async {
    try {
      final response = await supabase
          .from('achats')
          .select('''
            *,
            vehicules ( marque, modele )
          ''')
          .order('created_at', ascending: false);

      return (response as List).map((json) => Achat.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erreur getAchats: $e');
      return [];
    }
  }

  /// Récupérer les achats par statut
  Future<List<Achat>> getAchatsByStatut(AchatStatut statut) async {
    try {
      final achats = await getAchats();
      return achats.where((a) => a.statut == statut).toList();
    } catch (e) {
      debugPrint('Erreur getAchatsByStatut: $e');
      return [];
    }
  }

  /// Récupérer un achat par son ID
  Future<Achat?> getAchatById(String id) async {
    try {
      final response = await supabase
          .from('achats')
          .select('''
            *,
            vehicules ( marque, modele, prix_vente )
          ''')
          .eq('id', id)
          .single();

      return Achat.fromJson(response);
    } catch (e) {
      debugPrint('Erreur getAchatById: $e');
      return null;
    }
  }

  /// Créer un nouvel achat
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
      final response = await supabase
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

      return Achat.fromJson(response);
    } catch (e) {
      debugPrint('Erreur createAchat: $e');
      return null;
    }
  }

  /// Mettre à jour le statut d'un achat
  Future<bool> updateAchatStatut(String id, AchatStatut statut) async {
    try {
      await supabase
          .from('achats')
          .update({'statut': statut.name})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Erreur updateAchatStatut: $e');
      return false;
    }
  }

  /// Mettre à jour un achat
  Future<bool> updateAchat(Achat achat) async {
    try {
      await supabase
          .from('achats')
          .update(achat.toJson())
          .eq('id', achat.id);
      return true;
    } catch (e) {
      debugPrint('Erreur updateAchat: $e');
      return false;
    }
  }

  /// Supprimer un achat
  Future<bool> deleteAchat(String id) async {
    try {
      await supabase.from('achats').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Erreur deleteAchat: $e');
      return false;
    }
  }

  /// Statistiques des achats
  Future<Map<String, dynamic>> getStatsAchats() async {
    try {
      final achats = await getAchats();

      final totalAchats = achats.length;
      final totalDepense = achats.fold<double>(
        0,
        (sum, a) => sum + a.prixAccorde,
      );
      final enCours = achats.where((a) => a.statut == AchatStatut.en_cours).length;
      final valides = achats.where((a) => a.statut == AchatStatut.valide).length;

      return {
        'total_achats': totalAchats,
        'total_depense': totalDepense,
        'en_cours': enCours,
        'valides': valides,
        'prix_moyen': totalAchats > 0 ? totalDepense / totalAchats : 0,
      };
    } catch (e) {
      debugPrint('Erreur getStatsAchats: $e');
      return {};
    }
  }
}