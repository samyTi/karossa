import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart';

/// Structure de données pour l'historique annuel des revenus et dépenses
class AnnualChartData {
  final List<double> revenus;
  final List<double> depenses;
  AnnualChartData({required this.revenus, required this.depenses});
}

/// Provider des indicateurs financiers du mois en cours avec isolation stricte par Showroom
final revenusKpiProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null) return {'locations': 0, 'ventes': 0, 'depenses': 0, 'net': 0};

  final now = DateTime.now();
  final debut = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
  final fin = DateTime(now.year, now.month + 1, 0).toIso8601String().substring(0, 10);

  final supabase = ref.read(supabaseClientProvider);

  // 1. Revenus Locations
  final locs = await supabase
      .from('locations')
      .select('montant_brut')
      .eq('showroom_id', showroomId)
      .gte('date_debut', debut)
      .lte('date_debut', fin)
      .eq('statut', 'termine');
  final double locRevenu = locs.fold(0.0, (s, l) => s + ((l['montant_brut'] as num?)?.toDouble() ?? 0));

  // 2. Revenus Ventes
  final ventes = await supabase
      .from('ventes')
      .select('prix_vente')
      .eq('showroom_id', showroomId)
      .gte('date_vente', debut)
      .lte('date_vente', fin);
  final double venteRevenu = ventes.fold(0.0, (s, v) => s + ((v['prix_vente'] as num?)?.toDouble() ?? 0));

  // 3. Dépenses Réparations
  final reps = await supabase
      .from('reparations')
      .select('cout')
      .eq('showroom_id', showroomId)
      .gte('date_rep', debut)
      .lte('date_rep', fin);
  final double depenses = reps.fold(0.0, (s, r) => s + ((r['cout'] as num?)?.toDouble() ?? 0));

  return {
    'locations': locRevenu,
    'ventes': venteRevenu,
    'depenses': depenses,
    'net': locRevenu + venteRevenu - depenses,
  };
});

/// Provider pour alimenter le graphique annuel (Revenus vs Dépenses sur les 12 mois de l'année en cours)
final annualChartProvider = FutureProvider.autoDispose<AnnualChartData>((ref) async {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null) return AnnualChartData(revenus: List.filled(12, 0.0), depenses: List.filled(12, 0.0));

  final currentYear = DateTime.now().year;
  final supabase = ref.read(supabaseClientProvider);

  List<double> mensualRevenus = List.filled(12, 0.0);
  List<double> mensualDepenses = List.filled(12, 0.0);

  // Récupération globale des données de l'année pour optimiser les performances (1 seule requête par table)
  final locationsData = await supabase
      .from('locations')
      .select('date_debut, montant_brut')
      .eq('showroom_id', showroomId)
      .eq('statut', 'termine')
      .gte('date_debut', '$currentYear-01-01')
      .lte('date_debut', '$currentYear-12-31');

  final reparationsData = await supabase
      .from('reparations')
      .select('date_rep, cout')
      .eq('showroom_id', showroomId)
      .gte('date_rep', '$currentYear-01-01')
      .lte('date_rep', '$currentYear-12-31');

  // Traitement Locations
  for (var row in locationsData) {
    final dateStr = row['date_debut'] as String?;
    if (dateStr != null) {
      final month = DateTime.parse(dateStr).month - 1; // 0 à 11
      mensualRevenus[month] += (row['montant_brut'] as num?)?.toDouble() ?? 0.0;
    }
  }

  // Traitement Réparations
  for (var row in reparationsData) {
    final dateStr = row['date_rep'] as String?;
    if (dateStr != null) {
      final month = DateTime.parse(dateStr).month - 1;
      mensualDepenses[month] += (row['cout'] as num?)?.toDouble() ?? 0.0;
    }
  }

  return AnnualChartData(revenus: mensualRevenus, depenses: mensualDepenses);
});