import '../../../main.dart';
import '../domain/alerte_model.dart';

class EntretienRepository {
  Future<List<AlerteEntretien>> getActives() async {
    final data = await supabase
      .from('alertes_entretien')
      .select('*, vehicules(marque, modele)')
      .eq('statut', 'active')
      .order('date_echeance');
    return data.map((j) => AlerteEntretien.fromJson(j)).toList();
  }

  Future<void> create(Map<String, dynamic> data) async {
    await supabase.from('alertes_entretien').insert(data);
  }

  Future<void> marquerFait(String id) async {
    await supabase.from('alertes_entretien')
      .update({'statut': 'fait'}).eq('id', id);
  }
}
