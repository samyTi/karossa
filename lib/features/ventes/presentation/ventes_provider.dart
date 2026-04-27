// lib/features/ventes/presentation/ventes_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';

final ventesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('ventes')
      .select('''
        *,
        vehicules(marque, modele, immatriculation),
        clients(prenom, nom, telephone)
      ''')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data);
});

final statsVentesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final ventes = await supabase
      .from('ventes')
      .select('prix_vente, created_at');

  final total  = (ventes as List<dynamic>).length;
  final revenu = ventes.fold<double>(
      0, (s, v) => s + ((v['prix_vente'] as num?)?.toDouble() ?? 0));

  return {
    'total':  total,
    'revenu': revenu,
    'moyen':  total > 0 ? revenu / total : 0.0,
  };
});
