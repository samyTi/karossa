import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/echange_model.dart';

class EchangesRepository {
  EchangesRepository(this._client);

  final SupabaseClient _client;

  /// Récupère tous les échanges/contrats
  Future<List<Echange>> getAll() async {
    final data = await _client
      .from('echanges')
      .select(
        '*, '
        'vehicules!echanges_vehicule_cede_id_fkey(marque, modele, annee), '
        'clients(prenom, nom)'
      )
      .order('created_at', ascending: false);
    return data.map((j) => Echange.fromJson(j)).toList();
  }

  /// Récupère les échanges/contrats pour un véhicule donné
  /// Utilise explicitement la foreign key `echanges_vehicule_cede_id_fkey` 
  /// pour éviter l'ambiguïté avec `vehicle_repris_id`
  Future<List<Echange>> getByVehiculeId(String vehiculeId) async {
    final data = await _client
      .from('echanges')
      .select(
        '*, '
        'vehicules!echanges_vehicule_cede_id_fkey(marque, modele, annee), '
        'clients(prenom, nom)'
      )
      .eq('vehicule_cede_id', vehiculeId)
      .order('created_at', ascending: false);
    return data.map((j) => Echange.fromJson(j)).toList();
  }

  /// Récupère un échange/contrat par son ID
  Future<Echange?> getById(String echangeId) async {
    final data = await _client
      .from('echanges')
      .select(
        '*, '
        'vehicules!echanges_vehicule_cede_id_fkey(marque, modele, annee), '
        'clients(prenom, nom)'
      )
      .eq('id', echangeId)
      .maybeSingle();
    
    if (data == null) return null;
    return Echange.fromJson(data);
  }

  /// Crée un nouvel échange/contrat
  Future<Echange> create(Map<String, dynamic> data) async {
    final result = await _client
      .from('echanges')
      .insert(data)
      .select(
        '*, '
        'vehicules!echanges_vehicule_cede_id_fkey(marque, modele, annee), '
        'clients(prenom, nom)'
      )
      .single();
    
    await _client
      .from('vehicules')
      .update({'statut': 'vendu'})
      .eq('id', data['vehicule_cede_id']);
    
    return Echange.fromJson(result);
  }
}
