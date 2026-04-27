// lib/features/clients/data/clients_repository.dart

import '../../../main.dart';
import '../domain/client_model.dart';

class ClientsRepository {
  Future<List<Client>> getAll() async {
    final data = await supabase
        .from('clients')
        .select()
        .order('nom');
    return (data as List).map((j) => Client.fromJson(j)).toList();
  }

  Future<Client?> getById(String id) async {
    try {
      final data = await supabase.from('clients').select().eq('id', id).single();
      return Client.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<List<Client>> getByStatut(ClientStatut statut) async {
    final data = await supabase
        .from('clients')
        .select()
        .eq('statut', statut.name)
        .order('nom');
    return (data as List).map((j) => Client.fromJson(j)).toList();
  }

  Future<Client> create(Map<String, dynamic> clientData) async {
    final data = await supabase
        .from('clients')
        .insert(clientData)
        .select()
        .single();
    return Client.fromJson(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await supabase.from('clients').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await supabase.from('clients').delete().eq('id', id);
  }
}
