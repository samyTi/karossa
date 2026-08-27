// lib/features/clients/data/clients_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/client_model.dart';

class ClientsRepository {
  // 🚀 NOUVEAU : Le constructeur exige désormais le showroomId
  ClientsRepository(this._client, {required this.showroomId});

  final SupabaseClient _client;
  final String showroomId; // 🔥 Identifiant de la concession active

  Future<List<Client>> getAll() async {
    // Grâce au RLS, Supabase filtre automatiquement par showroom_id en arrière-plan
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
    // 🚀 Injection automatique du showroom_id dans les métadonnées du client
    final fullClientData = {
      ...clientData,
      'showroom_id': showroomId,
    };

    final data = await _client
        .from('clients')
        .insert(fullClientData)
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