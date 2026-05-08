// lib/features/dashboard/presentation/kpi_cards.dart

// Cartes KPI animées et interactives pour le dashboard

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';




// Provider revenus du mois en cours

final revenusKpiProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {

  final now      = DateTime.now();

  final debut    = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);

  final fin      = DateTime(now.year, now.month + 1, 0).toIso8601String().substring(0, 10);



  // Revenus locations

  final locs = await ref.read(supabaseClientProvider)

    .from('locations')

    .select('montant_brut')

    .gte('date_debut', debut)

    .lte('date_debut', fin)

    .eq('statut', 'termine');

  double locRevenu = locs.fold(0.0, (s, l) => s + ((l['montant_brut'] as num?)?.toDouble() ?? 0));



  // Revenus ventes

  final ventes = await ref.read(supabaseClientProvider)

    .from('ventes')

    .select('prix_vente')

    .gte('date_vente', debut)

    .lte('date_vente', fin);

  double venteRevenu = ventes.fold(0.0, (s, v) => s + ((v['prix_vente'] as num?)?.toDouble() ?? 0));



  // Dépenses réparations

  final reps = await ref.read(supabaseClientProvider)

    .from('reparations')

    .select('cout')

    .gte('date_rep', debut)

    .lte('date_rep', fin);

  double depenses = reps.fold(0.0, (s, r) => s + ((r['cout'] as num?)?.toDouble() ?? 0));



  return {

    'locations': locRevenu,

    'ventes': venteRevenu,

    'depenses': depenses,

    'net': locRevenu + venteRevenu - depenses,

  };

});



class KpiRevenusRow extends ConsumerWidget {

  const KpiRevenusRow({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final kpiAsync = ref.watch(revenusKpiProvider);



    return kpiAsync.when(

      loading: () => const _KpiSkeleton(),

      error: (e, _) => const SizedBox.shrink(),

      data: (kpi) => Padding(

        padding: const EdgeInsets.symmetric(horizontal: 16),

        child: Column(children: [

          // Titre section

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              const Text('Ce mois', style: TextStyle(

                fontWeight: FontWeight.bold, fontSize: 15)),

              TextButton.icon(

                onPressed: () => context.push('/releve'),

                icon: const Icon(Icons.analytics_outlined, size: 14),

                label: const Text('Voir tout', style: TextStyle(fontSize: 12)),

                style: TextButton.styleFrom(foregroundColor: AppColors.primary),

              ),

            ],

          ),

          const SizedBox(height: 8),

          Row(children: [

            Expanded(child: _KpiCard(

              label: 'Locations',

              value: "${(kpi['locations']! / 1000).toStringAsFixed(0)}k DA",

              icon: Icons.car_rental,

              color: AppColors.secondary,

              trend: null,

            )),

            const SizedBox(width: 10),

            Expanded(child: _KpiCard(

              label: 'Ventes',

              value: "${(kpi['ventes']! / 1000).toStringAsFixed(0)}k DA",

              icon: Icons.sell_outlined,

              color: AppColors.primary,

              trend: null,

            )),

          ]),

          const SizedBox(height: 10),

          Row(children: [

            Expanded(child: _KpiCard(

              label: 'Dépenses',

              value: "${(kpi['depenses']! / 1000).toStringAsFixed(0)}k DA",

              icon: Icons.construction_outlined,

              color: AppColors.retard,

              trend: null,

            )),

            const SizedBox(width: 10),

            Expanded(child: _KpiCard(

              label: 'Net',

              value: "${(kpi['net']! / 1000).toStringAsFixed(0)}k DA",

              icon: Icons.account_balance_wallet_outlined,

              color: (kpi['net']! >= 0) ? AppColors.secondary : AppColors.retard,

              trend: null,

              highlighted: true,

            )),

          ]),

        ]),

      ),

    );

  }

}



class _KpiCard extends StatelessWidget {

  final String label, value;

  final IconData icon;

  final Color color;

  final String? trend;

  final bool highlighted;



  const _KpiCard({

    required this.label, required this.value,

    required this.icon, required this.color,

    this.trend, this.highlighted = false,

  });



  @override

  Widget build(BuildContext context) => Container(

    padding: const EdgeInsets.all(14),

    decoration: BoxDecoration(

      color: highlighted

        ? color.withValues(alpha: 0.1) : Colors.white,

      borderRadius: BorderRadius.circular(14),

      border: Border.all(

        color: highlighted ? color.withValues(alpha: 0.3) : AppColors.border,

        width: highlighted ? 1.5 : 1,

      ),

      boxShadow: [

        BoxShadow(

          color: Colors.black.withValues(alpha: 0.04),

          blurRadius: 8, offset: const Offset(0, 2)),

      ],

    ),

    child: Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Row(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            Container(

              width: 32, height: 32,

              decoration: BoxDecoration(

                color: color.withValues(alpha: 0.12),

                borderRadius: BorderRadius.circular(8),

              ),

              child: Icon(icon, color: color, size: 18),

            ),

            if (trend != null)

              Text(trend!,

                style: TextStyle(

                  fontSize: 10, fontWeight: FontWeight.w600,

                  color: trend!.startsWith('+') ? AppColors.secondary : AppColors.retard,

                )),

          ],

        ),

        const SizedBox(height: 10),

        Text(value,

          style: TextStyle(

            fontSize: 17, fontWeight: FontWeight.bold,

            color: highlighted ? color : AppColors.textPrimary)),

        const SizedBox(height: 2),

        Text(label,

          style: const TextStyle(

            fontSize: 11, color: AppColors.textSecondary)),

      ],

    ),

  );

}



class _KpiSkeleton extends StatelessWidget {

  const _KpiSkeleton();



  @override

  Widget build(BuildContext context) => Padding(

    padding: const EdgeInsets.symmetric(horizontal: 16),

    child: Row(children: List.generate(2, (i) => Expanded(

      child: Container(

        margin: EdgeInsets.only(left: i == 0 ? 0 : 10),

        height: 90,

        decoration: BoxDecoration(

          color: AppColors.border,

          borderRadius: BorderRadius.circular(14),

        ),

      ),

    ))),

  );

}

