// lib/features/vehicules/data/vehicules_repository.dart
//
// CHANGEMENT : SupabaseClient injecté en constructeur — plus d'import main.dart.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/vehicule_model.dart';

class VehiculesRepository {
  VehiculesRepository(this._client);

  final SupabaseClient _client;

  static const _proprieteSelect =
      '*, vehicule_proprietes(*, profiles(prenom, nom))';

  Future<List<Vehicule>> getAll({VehiculeStatut? statut}) async {
    final query = _client.from('vehicules').select(_proprieteSelect);

    final data = statut != null
        ? await query
            .eq('statut', statut.name)
            .order('created_at', ascending: false)
        : await query
            .neq('statut', 'vendu')
            .order('created_at', ascending: false);

    return data.map((j) => Vehicule.fromJson(j)).toList();
  }

  Future<Vehicule> getById(String id) async {
    final data = await _client
        .from('vehicules')
        .select(_proprieteSelect)
        .eq('id', id)
        .single();
    return Vehicule.fromJson(data);
  }

  Future<Vehicule> create(
    Map<String, dynamic> vehiculeData,
    List<Map<String, dynamic>> proprietes,
  ) async {
    final result = await _client
        .from('vehicules')
        .insert(vehiculeData)
        .select()
        .single();
    for (final prop in proprietes) {
      await _client.from('vehicule_proprietes').insert({
        'vehicule_id': result['id'],
        ...prop,
      });
    }
    return getById(result['id']);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('vehicules').update(data).eq('id', id);
  }

  Future<Map<String, double>> calculateAndSaveMargin({
    required String vehiculeId,
    required double prixVente,
  }) async {
    final results = await Future.wait<dynamic>([
      _client
          .from('vehicules')
          .select('prix_achat')
          .eq('id', vehiculeId)
          .single(),
      _client
          .from('reparations')
          .select('cout')
          .eq('vehicule_id', vehiculeId)
          .eq('deductible', true),
      _client
          .from('caisse_operations')
          .select('montant, categorie')
          .eq('vehicule_id', vehiculeId)
          .eq('type', 'sortie'),
    ]);

    final vehiculeData = results[0] as Map<String, dynamic>;
    final reparations = results[1] as List;
    final caisseOps = results[2] as List;

    final prixAchat =
        (vehiculeData['prix_achat'] as num?)?.toDouble() ?? 0.0;
    final totalRep = reparations.fold<double>(
        0, (s, r) => s + (r['cout'] as num).toDouble());

    const fraisCats = [
      'entretien',
      'carburant',
      'lavage',
      'assurance',
      'controle_technique',
    ];
    final totalFrais = caisseOps
        .where((op) => fraisCats.contains(op['categorie']))
        .fold<double>(
            0, (s, op) => s + (op['montant'] as num).toDouble());

    final prixRevient = prixAchat + totalRep + totalFrais;
    final marge = prixVente - prixRevient;
    final margePct =
        prixRevient > 0 ? (marge / prixRevient) * 100 : 0.0;

    return {
      'prixRevient': prixRevient,
      'marge': marge,
      'margePct': margePct,
    };
  }
}
