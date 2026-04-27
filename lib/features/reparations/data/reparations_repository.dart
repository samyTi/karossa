import '../../../main.dart';
import '../domain/reparation_model.dart';

class ReparationsRepository {
  Future<List<Reparation>> getAll({String? vehiculeId}) async {
    if (vehiculeId != null) {
      final data = await supabase
        .from('reparations')
        .select('*, vehicules(marque, modele)')
        .eq('vehicule_id', vehiculeId)
        .order('date_rep', ascending: false);
      return data.map((j) => Reparation.fromJson(j)).toList();
    }
    final data = await supabase
      .from('reparations')
      .select('*, vehicules(marque, modele)')
      .order('date_rep', ascending: false);
    return data.map((j) => Reparation.fromJson(j)).toList();
  }

  Future<void> create(Map<String, dynamic> data) async {
    final vehiculeId = data['vehicule_id'] as String;
    final changerStatut = data.remove('statut_vehicule') as bool? ?? false;
    await supabase.from('reparations').insert(data);
    if (changerStatut) {
      await supabase.from('vehicules')
        .update({'statut': 'reparation'})
        .eq('id', vehiculeId);
    }
  }

  Future<double> getTotalByVehicule(String vehiculeId) async {
    final data = await supabase
      .from('reparations')
      .select('cout')
      .eq('vehicule_id', vehiculeId)
      .eq('deductible', true);
    double total = 0;
    for (final r in data) {
      total += (r['cout'] as num).toDouble();
    }
    return total;
  }
}
