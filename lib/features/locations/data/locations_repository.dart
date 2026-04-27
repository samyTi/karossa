import '../../../main.dart';
import '../domain/location_model.dart';

class LocationsRepository {
  Future<List<Location>> getActives() async {
    final data = await supabase
      .from('locations')
      .select('''
        *, vehicules(marque, modele),
        clients(prenom, nom, telephone),
        location_repartitions(*, profiles(prenom))
      ''')
      .inFilter('statut', ['en_cours', 'retard'])
      .order('date_fin_prevue');
    return data.map((j) => Location.fromJson(j)).toList();
  }

  Future<List<Location>> getRetards() async {
    final now = DateTime.now().toIso8601String();
    final data = await supabase
      .from('locations')
      .select('*, vehicules(marque, modele), clients(prenom, nom, telephone)')
      .eq('statut', 'en_cours')
      .lt('date_fin_prevue', now);
    return data.map((j) => Location.fromJson(j)).toList();
  }

  Future<Location?> getById(String id) async {
    try {
      final data = await supabase
        .from('locations')
        .select("""
          *, vehicules(marque, modele),
          clients(prenom, nom, telephone),
          location_repartitions(*, profiles(prenom))
        """)
        .eq('id', id)
        .single();
      return Location.fromJson(data);
    } catch (_) { return null; }
  }

  Future<Location> create(Map<String, dynamic> locationData) async {
    final data = await supabase
      .from('locations')
      .insert(locationData)
      .select()
      .single();
    return Location.fromJson(data);
  }

  Future<void> cloturerLocation({
    required String locationId,
    required int kmRetour,
    required double montantBrut,
    required double retenueCaution,
    String? notesRetour,
  }) async {
    await supabase.from('locations').update({
      'statut':          'termine',
      'date_fin_reelle': DateTime.now().toIso8601String(),
      'km_retour':       kmRetour,
      'montant_brut':    montantBrut,
      'retenue_caution': retenueCaution,
      'notes_retour':    notesRetour,
    }).eq('id', locationId);
    await supabase.rpc('calculer_repartition_location',
      params: {'p_location_id': locationId});
  }
}
