import '../../../main.dart';
import '../domain/vehicule_model.dart';

class VehiculesRepository {
  Future<List<Vehicule>> getAll({VehiculeStatut? statut}) async {
    var query = supabase
      .from('vehicules')
      .select('*, vehicule_proprietes(*, profiles(prenom, nom))');

    if (statut != null) {
      final data = await query.eq('statut', statut.name)
        .order('created_at', ascending: false);
      return data.map((j) => Vehicule.fromJson(j)).toList();
    }
    final data = await query.neq('statut', 'vendu')
      .order('created_at', ascending: false);
    return data.map((j) => Vehicule.fromJson(j)).toList();
  }

  Future<Vehicule> getById(String id) async {
    final data = await supabase
      .from('vehicules')
      .select('*, vehicule_proprietes(*, profiles(prenom, nom))')
      .eq('id', id)
      .single();
    return Vehicule.fromJson(data);
  }

  Future<Vehicule> create(
    Map<String, dynamic> vehiculeData,
    List<Map<String, dynamic>> proprietes,
  ) async {
    final result = await supabase
      .from('vehicules')
      .insert(vehiculeData)
      .select()
      .single();
    for (final prop in proprietes) {
      await supabase.from('vehicule_proprietes')
        .insert({'vehicule_id': result['id'], ...prop});
    }
    return getById(result['id']);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await supabase.from('vehicules').update(data).eq('id', id);
  }
}
