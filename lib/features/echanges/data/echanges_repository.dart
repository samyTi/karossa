import '../../../main.dart';
import '../domain/echange_model.dart';

class EchangesRepository {
  Future<List<Echange>> getAll() async {
    final data = await supabase
      .from('echanges')
      .select(
        '*, '
        'vehicules!echanges_vehicule_cede_id_fkey(marque, modele), '
        'clients(prenom, nom)'
      )
      .order('created_at', ascending: false);
    return data.map((j) => Echange.fromJson(j)).toList();
  }

  Future<Echange> create(Map<String, dynamic> data) async {
    final result = await supabase
      .from('echanges')
      .insert(data)
      .select()
      .single();
    await supabase
      .from('vehicules')
      .update({'statut': 'vendu'})
      .eq('id', data['vehicule_cede_id']);
    return Echange.fromJson(result);
  }
}
