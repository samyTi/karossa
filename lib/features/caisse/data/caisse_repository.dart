import 'package:supabase_flutter/supabase_flutter.dart';
import './caisse_operation.dart';

class CaisseRepository {
  final SupabaseClient _client;

  CaisseRepository(this._client);

  static const _table = 'caisse_operations';

  static const _select = '''
    *,
    vehicules(id, marque, modele, immatriculation),
    locations(id, date_debut, date_fin_prevue, prix_jour, nb_jours, montant_brut,
              clients(nom, prenom, telephone)),
    ventes(id, prix_vente, date_vente,
           clients(nom, prenom, telephone)),
    reparations(id, description, cout, type_rep, prestataire, date_rep,
                vehicules(marque, modele)),
    echanges(id, vehicule_reprise_marque, vehicule_reprise_modele,
             valeur_reprise, complement_client, date_echange,
             clients(nom, prenom, telephone))
  ''';

  // ─── Lecture ────────────────────────────────────────────────────────────────

  Future<List<CaisseOperation>> fetchAll(CaisseFilter filter) async {
    var query = _client.from(_table).select(_select);

    // Filtres serveur (date)
    if (filter.dateDebut != null) {
      query = query.gte(
          'date_op', filter.dateDebut!.toIso8601String().split('T').first);
    }
    if (filter.dateFin != null) {
      query = query.lte(
          'date_op', filter.dateFin!.toIso8601String().split('T').first);
    }
    if (filter.mois != null && filter.annee != null) {
      final from =
          DateTime(filter.annee!, filter.mois!, 1).toIso8601String().split('T').first;
      final to = DateTime(filter.annee!, filter.mois! + 1, 0)
          .toIso8601String()
          .split('T')
          .first;
      query = query.gte('date_op', from).lte('date_op', to);
    }
    if (filter.type != null) {
      query = query.eq('type', filter.type!);
    }
    if (filter.categorie != null) {
      query = query.eq('categorie', filter.categorie!);
    }

    final data = await query.order('date_op', ascending: false);
    return (data as List).map((e) => CaisseOperation.fromMap(e)).toList();
  }

  Future<CaisseOperation?> fetchById(String id) async {
    final data =
        await _client.from(_table).select(_select).eq('id', id).maybeSingle();
    if (data == null) return null;
    return CaisseOperation.fromMap(data);
  }

  // ─── Écriture ───────────────────────────────────────────────────────────────

  Future<CaisseOperation> insert(
      CaisseOperation op, String createdById) async {
    final payload = op.toInsertMap()..['created_by'] = createdById;
    final data = await _client
        .from(_table)
        .insert(payload)
        .select(_select)
        .single();
    return CaisseOperation.fromMap(data);
  }

  Future<CaisseOperation> update(String id, CaisseOperation op) async {
    final data = await _client
        .from(_table)
        .update(op.toInsertMap())
        .eq('id', id)
        .select(_select)
        .single();
    return CaisseOperation.fromMap(data);
  }

  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  // ─── Lookups ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchVehicules() async {
    final data = await _client
        .from('vehicules')
        .select('id, marque, modele, immatriculation')
        .neq('statut', 'vendu')
        .order('marque');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> fetchLocationsEnCours() async {
    final data = await _client
        .from('locations')
        .select('id, date_debut, date_fin_prevue, vehicules(marque, modele), clients(nom, prenom)')
        .eq('statut', 'en_cours')
        .order('date_debut', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> fetchVentesRecentes() async {
    final data = await _client
        .from('ventes')
        .select('id, prix_vente, date_vente, vehicules(marque, modele), clients(nom, prenom)')
        .order('date_vente', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> fetchReparations() async {
    final data = await _client
        .from('reparations')
        .select('id, description, cout, vehicules(marque, modele)')
        .order('date_rep', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> fetchEchanges() async {
    final data = await _client
        .from('echanges')
        .select('id, vehicule_reprise_marque, vehicule_reprise_modele, valeur_reprise, clients(nom, prenom)')
        .order('date_echange', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data as List);
  }
}