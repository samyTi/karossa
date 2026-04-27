// lib/features/ventes/data/ventes_repository.dart

import 'package:flutter/foundation.dart';
import '../../../main.dart';
import '../domain/vente_model.dart';

class VentesRepository {
  static final VentesRepository _i = VentesRepository._internal();
  factory VentesRepository() => _i;
  VentesRepository._internal();

  Future<List<Vente>> getAll() async {
    try {
      final data = await supabase
          .from('ventes')
          .select('''
            *,
            vehicules(marque, modele, annee, immatriculation),
            clients(prenom, nom, telephone)
          ''')
          .order('created_at', ascending: false);
      return (data as List).map((j) => Vente.fromJson(j)).toList();
    } catch (e) {
      debugPrint('VentesRepository.getAll: $e');
      return [];
    }
  }

  Future<Vente?> getById(String id) async {
    try {
      final data = await supabase
          .from('ventes')
          .select('*, vehicules(marque, modele, annee), clients(prenom, nom)')
          .eq('id', id)
          .single();
      return Vente.fromJson(data);
    } catch (e) {
      debugPrint('VentesRepository.getById: $e');
      return null;
    }
  }

  Future<Vente?> create(Map<String, dynamic> payload) async {
    try {
      final data = await supabase
          .from('ventes')
          .insert(payload)
          .select()
          .single();
      return Vente.fromJson(data);
    } catch (e) {
      debugPrint('VentesRepository.create: $e');
      return null;
    }
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    try {
      await supabase.from('ventes').update(payload).eq('id', id);
    } catch (e) {
      debugPrint('VentesRepository.update: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final ventes = await supabase
          .from('ventes')
          .select('prix_vente, acompte, statut_paiement, created_at');
      final list = ventes as List;
      final total   = list.length;
      final revenu  = list.fold<double>(
          0, (s, v) => s + ((v['prix_vente'] as num?)?.toDouble() ?? 0));
      final encaisse = list.fold<double>(
          0, (s, v) => s + ((v['acompte'] as num?)?.toDouble() ?? 0));
      return {
        'total':    total,
        'revenu':   revenu,
        'encaisse': encaisse,
        'moyen':    total > 0 ? revenu / total : 0.0,
      };
    } catch (e) {
      debugPrint('VentesRepository.getStats: $e');
      return {'total': 0, 'revenu': 0.0, 'encaisse': 0.0, 'moyen': 0.0};
    }
  }
}
