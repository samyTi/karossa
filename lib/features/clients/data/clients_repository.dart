// lib/features/clients/data/clients_repository.dart
//
// CHANGEMENT : le client Supabase est reçu en constructeur,
// plus d'import de main.dart.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/client_model.dart';

class ClientsRepository {
  ClientsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Client>> getAll() async {
    final data = await _client
        .from('clients')
        .select()
        .order('nom');
    return data.map((j) => Client.fromJson(j)).toList();
  }

  Future<Client?> getById(String id) async {
    final data = await _client
        .from('clients')
        .select()
        .eq('id', id)
        .single();
    return Client.fromJson(data);
  }

  Future<List<Client>> getByStatut(ClientStatut statut) async {
    final data = await _client
        .from('clients')
        .select()
        .eq('statut', statut.name)
        .order('nom');
    return data.map((j) => Client.fromJson(j)).toList();
  }

  Future<Client> create(Map<String, dynamic> clientData) async {
    final data = await _client
        .from('clients')
        .insert(clientData)
        .select()
        .single();
    return Client.fromJson(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('clients').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('clients').delete().eq('id', id);
  }
}
