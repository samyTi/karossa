import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/alerte_model.dart';

class EntretienRepository {
  EntretienRepository(this._client);

  final SupabaseClient _client;

  Future<List<AlerteEntretien>> getActives() async {
    final data = await _client
      .from('alertes_entretien')
      .select('*, vehicules(marque, modele)')
      .eq('statut', 'active')
      .order('date_echeance');
    return data.map((j) => AlerteEntretien.fromJson(j)).toList();
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _client.from('alertes_entretien').insert(data);
  }

  Future<void> marquerFait(String id) async {
    await _client.from('alertes_entretien')
      .update({'statut': 'fait'}).eq('id', id);
  }
}
